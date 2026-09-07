"""Bound OmegaClaw provider calls without modifying OmegaClaw-Core."""

from copy import copy
from time import monotonic


_FAILURE_PREFIX = "__METAMO_PROVIDER_FAILURE__:"


def _field(value, name, default=None):
    """Read one SDK response field from an object or mapping."""
    if value is None:
        return default
    if isinstance(value, dict):
        return value.get(name, default)
    return getattr(value, name, default)


def _usage_value(usage, name):
    value = _field(usage, name)
    return "unknown" if value is None else value


def _response_diagnostics(response, prompt, reasoning_mode):
    """Emit metadata for the real live request without logging its prompt."""
    choices = _field(response, "choices", ()) or ()
    choice = choices[0] if choices else None
    message = _field(choice, "message")
    content = _field(message, "content", "") or ""
    reasoning = _field(message, "reasoning", "") or ""
    usage = _field(response, "usage")
    finish_reason = _field(choice, "finish_reason", "unknown")
    details = _field(usage, "completion_tokens_details")
    reasoning_tokens = _field(details, "reasoning_tokens", "unknown")
    print(
        "[MetaMoProviderResponse] "
        f"prompt_chars={len(str(prompt))} content_chars={len(str(content))} "
        f"reasoning_chars={len(str(reasoning))} finish={finish_reason} "
        f"prompt_tokens={_usage_value(usage, 'prompt_tokens')} "
        f"completion_tokens={_usage_value(usage, 'completion_tokens')} "
        f"reasoning_tokens={reasoning_tokens} "
        f"reasoning_mode={reasoning_mode} reasoning_applied=false",
        flush=True,
    )
    return str(content), str(finish_reason)


def _empty_response_reason(finish_reason):
    if str(finish_reason).lower() == "length":
        return "provider-output-limit"
    return "provider-reasoning-only"


def _failure_response(reason):
    """Encode transport failure without making it look like model output."""
    return f"{_FAILURE_PREFIX}{reason}"


def provider_failure_reason(response):
    """Return a stable MeTTa-friendly failure atom, or ``none``."""
    text = "" if response is None else str(response)
    if text.startswith(_FAILURE_PREFIX):
        reason = text[len(_FAILURE_PREFIX):].strip()
        return reason or "provider-error"
    return "none"


def provider_response_text(response):
    """Remove the private transport marker before command parsing."""
    return "" if provider_failure_reason(response) != "none" else str(response)


def _bounded_provider(provider_module, provider_name, timeout_seconds):
    provider = provider_module._get_provider(str(provider_name))
    if provider is None or not provider.is_available:
        raise RuntimeError("provider-unavailable")

    timeout = max(0.01, float(timeout_seconds))
    ensure_client = getattr(provider, "_ensure_client", None)
    if callable(ensure_client):
        ensure_client()

    client = getattr(provider, "_client", None)
    with_options = getattr(client, "with_options", None)
    if not callable(with_options):
        return provider, timeout

    bounded = copy(provider)
    bounded._client = with_options(timeout=timeout, max_retries=0)
    return bounded, timeout


def call_provider_module(
    provider_module,
    provider_name,
    content,
    max_tokens,
    reasoning_mode,
    timeout_seconds,
):
    """Call one configured provider through a per-request bounded client."""
    provider, timeout = _bounded_provider(
        provider_module, provider_name, timeout_seconds
    )
    base_provider_type = getattr(provider_module, "AIProvider", None)
    client = getattr(provider, "_client", None)
    create = getattr(
        getattr(getattr(client, "chat", None), "completions", None),
        "create",
        None,
    )
    model_name = getattr(provider, "_model_name", None)
    if (
        base_provider_type is not None
        and type(provider) is base_provider_type
        and callable(create)
        and model_name
    ):
        response = create(
            model=model_name,
            messages=[{
                "role": "user",
                "content": str(content).replace(":-:-:-:", " "),
            }],
            max_tokens=max(1, int(max_tokens)),
            timeout=timeout,
        )
        raw, finish_reason = _response_diagnostics(
            response, content, reasoning_mode
        )
        log_raw = getattr(provider_module, "_log_raw", None)
        if callable(log_raw):
            log_raw(str(provider_name), model_name, raw)
        if not raw.strip():
            return _failure_response(_empty_response_reason(finish_reason))
        clean_text = getattr(provider, "_clean_text", None)
        return clean_text(raw) if callable(clean_text) else raw

    return provider.chat(
        content=str(content),
        max_tokens=max(1, int(max_tokens)),
        reasoning=str(reasoning_mode),
        timeout=timeout,
    )


def call_provider_text(
    provider_name,
    content,
    max_tokens,
    reasoning_mode,
    timeout_seconds,
    operation="realization",
):
    """Return provider text or an explicit private transport-failure marker."""
    started_at = monotonic()
    try:
        import lib_llm_ext

        response = call_provider_module(
            lib_llm_ext,
            provider_name,
            content,
            max_tokens,
            reasoning_mode,
            timeout_seconds,
        )
        text = "" if response is None else str(response)
        failure_reason = provider_failure_reason(text)
        if failure_reason == "none" and not text.strip():
            failure_reason = "provider-empty-response"
        status = (
            "ok" if failure_reason == "none" and text.strip()
            else "unavailable"
        )
        print(
            f"[MetaMoProvider] operation={operation} status={status} "
            f"reason={failure_reason} prompt_chars={len(str(content))} "
            f"timeout={float(timeout_seconds):.3f}s "
            f"elapsed={monotonic() - started_at:.3f}s",
            flush=True,
        )
        if failure_reason != "none":
            return (
                text if text.strip()
                else _failure_response(failure_reason)
            )
        return text
    except Exception as error:
        error_name = type(error).__name__.lower()
        if isinstance(error, TimeoutError) or "timeout" in error_name:
            reason = "provider-timeout"
        elif str(error) == "provider-unavailable":
            reason = "provider-unavailable"
        else:
            reason = "provider-error"
        print(
            f"[MetaMoProvider] operation={operation} status=unavailable "
            f"reason={reason} timeout={float(timeout_seconds):.3f}s "
            f"elapsed={monotonic() - started_at:.3f}s",
            flush=True,
        )
        return _failure_response(reason)

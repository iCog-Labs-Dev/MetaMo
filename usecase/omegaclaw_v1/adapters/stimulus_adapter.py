"""Convert OmegaClaw messages into explicit provider-scored MetaMo signals."""

from copy import copy
import re
from time import monotonic


_MESSAGE_SIGNAL_KINDS = (
    "information-request",
    "execution-request",
    "goal-control-request",
    "ambiguity",
    "danger",
    "contradiction",
    "task-drift",
    "user-angry",
)

_SEMANTIC_UNAVAILABLE = "((signal semantic-unavailable 1.000))"
_DEFAULT_SEMANTIC_MAX_TOKENS = 256
_DEFAULT_SEMANTIC_REASONING = "low"

_SIGNAL_FORM_PATTERN = re.compile(
    r"\(\s*(?:signal\s+)?([a-z][a-z0-9-]*)\s+"
    r"([0-9]+(?:\.[0-9]+)?)\s*\)"
)

_FENCED_METTA_PATTERN = re.compile(
    r"^\s*```(?:metta)?\s*(.*?)\s*```\s*$",
    re.IGNORECASE | re.DOTALL,
)
_SEND_QUOTE_WRAPPER_PATTERN = re.compile(
    r'(\(\s*send\s+")quote_(.*?)_quote("\s*\))',
    re.DOTALL,
)


def unwrap_metta_fence(response):
    """Remove one provider-added MeTTa code fence and nothing else."""
    text = str(response).strip()
    match = _FENCED_METTA_PATTERN.fullmatch(text)
    return match.group(1).strip() if match else text


def normalize_command_response(response):
    """Return a total, parseable command-list response.

    Empty provider content is a valid observation of proposal failure, not a
    reason for the MeTTa call chain to lose its only result and terminate the
    continuous loop.
    """
    if response is None:
        return "()"
    text = unwrap_metta_fence(response)
    if not text:
        return "()"
    text = _SEND_QUOTE_WRAPPER_PATTERN.sub(r"\1\2\3", text)

    if text.startswith("(") and text.endswith(")"):
        inner = text[1:-1].lstrip()
        if inner and not inner.startswith("("):
            return f"({text})"
    return text


def command_response_empty(response):
    """Return a MeTTa boolean without exposing an empty string to first_char."""
    return "true" if normalize_command_response(response) == "()" else "false"


def message_present(message):
    """Return a MeTTa boolean atom for channel content."""
    return "true" if str(message) else "false"


def normalize_semantic_signals(response):
    """Validate a complete provider response and emit one canonical list."""
    text = unwrap_metta_fence(response)
    if not text:
        return _SEMANTIC_UNAVAILABLE

    forms = _SIGNAL_FORM_PATTERN.findall(text)
    remainder = re.sub(r"\s+", "", _SIGNAL_FORM_PATTERN.sub("", text))
    if remainder not in ("", "()") or len(forms) != len(_MESSAGE_SIGNAL_KINDS):
        return _SEMANTIC_UNAVAILABLE

    strengths = {}
    for kind, raw_strength in forms:
        if kind not in _MESSAGE_SIGNAL_KINDS or kind in strengths:
            return _SEMANTIC_UNAVAILABLE
        strength = float(raw_strength)
        if not 0.0 <= strength <= 1.0:
            return _SEMANTIC_UNAVAILABLE
        strengths[kind] = strength

    if set(strengths) != set(_MESSAGE_SIGNAL_KINDS):
        return _SEMANTIC_UNAVAILABLE

    signals = " ".join(
        f"(signal {kind} {strengths[kind]:.3f})"
        for kind in _MESSAGE_SIGNAL_KINDS
    )
    return f"({signals})"


def semantic_response_status(response, finish_reason=None):
    """Describe why a semantic response can or cannot be consumed."""
    text = unwrap_metta_fence(response)
    normalized = normalize_semantic_signals(text)
    if normalized != _SEMANTIC_UNAVAILABLE:
        return "ok"
    if str(finish_reason) == "length":
        return "token-budget-exhausted"
    if not text:
        return "empty-response"
    return "malformed-response"


def _chat_completion_response(
    provider, client, prompt, max_tokens, timeout_seconds
):
    """Use OpenAI-compatible metadata when the provider exposes it."""
    chat = getattr(client, "chat", None)
    completions = getattr(chat, "completions", None)
    create = getattr(completions, "create", None)
    model_name = getattr(provider, "_model_name", None)
    if not callable(create) or not model_name:
        return None

    response = create(
        model=model_name,
        messages=[{"role": "user", "content": prompt}],
        max_tokens=max_tokens,
        timeout=timeout_seconds,
    )
    choice = response.choices[0]
    raw = choice.message.content or ""
    clean_text = getattr(provider, "_clean_text", None)
    text = clean_text(raw) if callable(clean_text) else raw
    return text, getattr(choice, "finish_reason", None)


def _call_provider_with_timeout(
    provider_module,
    provider_name,
    prompt,
    timeout_seconds,
    max_tokens,
    reasoning_mode,
):
    """Run one provider request with transport-level timeout cancellation.

    A daemon-thread timeout only stops waiting for a request; it does not stop
    the underlying HTTP call.  That discarded request can then overlap the
    command-generation request.  Resolve OmegaClaw's configured provider and
    pass the timeout to its client-backed ``chat`` operation instead.
    """
    provider = provider_module._get_provider(provider_name)
    if provider is None or not provider.is_available:
        raise RuntimeError(f"Provider '{provider_name}' not available")
    timeout = max(0.01, float(timeout_seconds))

    ensure_client = getattr(provider, "_ensure_client", None)
    if callable(ensure_client):
        ensure_client()
    client = getattr(provider, "_client", None)
    with_options = getattr(client, "with_options", None)
    request_provider = provider
    if callable(with_options):
        request_provider = copy(provider)
        request_provider._client = with_options(timeout=timeout, max_retries=0)

    token_limit = max(64, int(max_tokens))
    base_provider_type = getattr(provider_module, "AIProvider", None)
    metadata_response = None
    if base_provider_type is not None and type(provider) is base_provider_type:
        metadata_response = _chat_completion_response(
            request_provider,
            getattr(request_provider, "_client", None),
            prompt,
            token_limit,
            timeout,
        )
    if metadata_response is not None:
        return metadata_response

    response = request_provider.chat(
        content=prompt,
        max_tokens=token_limit,
        reasoning=str(reasoning_mode),
        timeout=timeout,
    )
    return response, None


def _ensure_semantic_provider_registration(
    provider_module,
    provider_name,
    api_key_variable,
    model_name,
    base_url,
):
    """Register the application-owned classifier through OmegaClaw's API."""
    name = str(provider_name)
    key_variable = str(api_key_variable)
    model = str(model_name)
    url = str(base_url)
    provider = provider_module._get_provider(name)
    matches = (
        provider is not None
        and getattr(provider, "_var_name", None) == key_variable
        and getattr(provider, "_model_name", None) == model
        and getattr(provider, "_base_url", None) == url
    )
    if matches:
        return

    register = getattr(provider_module, "_register_provider", None)
    if not callable(register):
        raise RuntimeError("OmegaClaw provider registration is unavailable")
    register(
        name=name,
        var_name=key_variable,
        model_name=model,
        base_url=url,
    )


def semantic_signal_text(
    provider_name,
    message,
    active_task,
    task_status,
    timeout_seconds=10.0,
    max_tokens=_DEFAULT_SEMANTIC_MAX_TOKENS,
    reasoning_mode=_DEFAULT_SEMANTIC_REASONING,
    api_key_variable=None,
    model_name=None,
    base_url=None,
):
    """Ask the configured provider to score message-level MetaMo signals.

    Importing lazily keeps the adapter importable in offline unit tests that do
    not load OmegaClaw's Python provider module. In the live bootstrap,
    ``lib_omegaclaw`` is loaded before this function is called.
    """
    started_at = monotonic()
    try:
        import lib_llm_ext

        if all(
            value is not None
            for value in (api_key_variable, model_name, base_url)
        ):
            _ensure_semantic_provider_registration(
                lib_llm_ext,
                provider_name,
                api_key_variable,
                model_name,
                base_url,
            )

        prompt = (
            "Classify only the HUMAN_MESSAGE for a motivational agent. "
            "Scores: 0 absent, 0.25 weak, 0.5 clear, 0.75 strong, 1 explicit. "
            "Signals: information-request=asks for an answer or report; "
            "execution-request=explicitly needs a tool, inspection, command, or "
            "state change (reasoning from supplied context is not execution); "
            "goal-control-request=explicitly creates, changes, completes, cancels, "
            "resumes, or inspects the agent's managed autonomous goal, not an "
            "ordinary project task; ambiguity=a missing detail blocks a safe useful "
            "next step; danger=the requested effect is unsafe, destructive, "
            "irreversible, or unauthorized; contradiction=conflicts with known "
            "evidence or constraints; task-drift=conflicts with the ACTIVE_TASK "
            "(0 when no task is active); user-angry=explicit anger or hostility, "
            "not urgency or correction. Score independently. Do not explain. "
            "Return exactly this MeTTa shape and nothing else: "
            "((signal information-request 0.0) "
            "(signal execution-request 0.0) "
            "(signal goal-control-request 0.0) "
            "(signal ambiguity 0.0) (signal danger 0.0) "
            "(signal contradiction 0.0) (signal task-drift 0.0) "
            "(signal user-angry 0.0)). "
            f"ACTIVE_TASK: {active_task}. TASK_STATUS: {task_status}. "
            f"HUMAN_MESSAGE: {message}"
        )
        started_at = monotonic()
        response, finish_reason = _call_provider_with_timeout(
            lib_llm_ext,
            provider_name,
            prompt,
            timeout_seconds,
            max_tokens,
            reasoning_mode,
        )
        result = normalize_semantic_signals(response)
        response_status = semantic_response_status(response, finish_reason)
        status = "ok" if response_status == "ok" else "unavailable"
        print(
            f"[MetaMoStimulus] status={status} "
            f"reason={response_status} "
            f"finish={finish_reason or 'unknown'} "
            f"elapsed={monotonic() - started_at:.3f}s"
        )
        return result
    except Exception as error:
        if isinstance(error, TimeoutError):
            reason = "timeout"
        elif isinstance(error, RuntimeError):
            reason = "provider-unavailable"
        else:
            reason = "provider-error"
        print(
            f"[MetaMoStimulus] status=unavailable "
            f"reason={reason} "
            f"elapsed={monotonic() - started_at:.3f}s"
        )
        return _SEMANTIC_UNAVAILABLE

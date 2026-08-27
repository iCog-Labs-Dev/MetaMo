"""Live LLM bridge for the MeTTa Research Assistant CLI.

The MeTTa CLI uses this module for side-effectful terminal-facing LLM work:

- user text -> semantic perception JSON;
- selected MetaMo action -> final natural-language response.

Motivational semantics stay in MeTTa.  This bridge only calls the configured
provider and validates the returned JSON/text.
"""

from __future__ import annotations

import json
import os
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any


TASK_INTENTS = ("answer", "summarize", "compare", "clarify", "explore", "decline")
STIMULUS_FIELDS = ("novelty", "conduciveness", "risk", "effort")
SIGNAL_FIELDS = (
    "task_intent",
    "ambiguity",
    "citation_need",
    "comparison_need",
    "summary_need",
    "exploration_need",
    "unsafe_pressure",
    "privacy_pressure",
    "unsupported_claim_pressure",
    "context_loss_pressure",
)
RETRYABLE_MARKERS = ("503", "UNAVAILABLE", "429", "RESOURCE_EXHAUSTED", "HIGH DEMAND")
RETRYABLE_HTTP_STATUS = {429, 500, 502, 503, 504}
PLACEHOLDER_VALUES = {
    "",
    "your_api_key_here",
    "paste_your_api_key_here",
    "your_model_name_here",
    "your_provider_name_here",
}
PROVIDER_ADAPTERS = {
    "gemini": "google_genai",
    "google": "google_genai",
    "snet": "openai_compatible",
    "openai": "openai_compatible",
    "openai_compatible": "openai_compatible",
    "openai-compatible": "openai_compatible",
}
DEFAULT_BASE_URLS = {
    "openai": "https://api.openai.com/v1",
    "snet": "https://llm.c.singularitynet.io/v1",
}
ACTION_INSTRUCTIONS = {
    "safe_answer": "Answer directly, stay grounded, and flag uncertainty or missing evidence.",
    "guided_explore": "Explore bounded possibilities and research directions without overstating certainty.",
    "ask_clarifying_question": "Ask one short clarifying question before giving a substantive answer.",
    "compare_options": "Compare alternatives by evidence, trade-offs, assumptions, and caveats.",
    "summarize_source": "Summarize the provided/source-focused material and preserve citation needs.",
    "decline_risky_request": "Briefly refuse unsafe, deceptive, or privacy-violating help and offer a safe alternative.",
}
SYSTEM_INSTRUCTION = (
    "You are a research assistant guided by the MetaMo cognitive architecture. "
    "You balance helpfulness, curiosity, and ethics. Follow the internal MetaMo "
    "action directive exactly."
)

_PERCEPTION_CACHE: dict[str, dict[str, Any]] = {}
_ENV_LOADED = False


@dataclass(frozen=True)
class LlmConfig:
    provider_name: str
    adapter_name: str
    model_name: str
    api_key: str
    base_url: str | None
    request_timeout: float


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def _load_basic_env(path: Path) -> None:
    if not path.exists():
        return
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = value


def _load_environment() -> None:
    global _ENV_LOADED
    if _ENV_LOADED:
        return
    _load_basic_env(_repo_root() / ".env")
    _ENV_LOADED = True


def _clean_env(name: str) -> str:
    _load_environment()
    return os.getenv(name, "").strip()


def _is_placeholder(value: str) -> bool:
    return value.strip().lower() in PLACEHOLDER_VALUES


def _required_env(name: str) -> str:
    value = _clean_env(name)
    if _is_placeholder(value):
        raise RuntimeError(
            f"Set {name} in {_repo_root() / '.env'} before running the Research Assistant CLI."
        )
    return value


def _llm_config(provider: str | None = None) -> LlmConfig:
    provider_name = (provider or _required_env("PROVIDER_NAME")).strip().lower()
    adapter_name = PROVIDER_ADAPTERS.get(provider_name)
    if adapter_name is None:
        known = ", ".join(sorted(PROVIDER_ADAPTERS))
        raise ValueError(f"unknown PROVIDER_NAME {provider_name!r}; known providers: {known}")

    model_name = _required_env("MODEL_NAME")
    api_key = _required_env("API_KEY").removeprefix("Bearer ").strip()
    base_url = _clean_env("BASE_URL") or DEFAULT_BASE_URLS.get(provider_name)
    timeout_raw = _clean_env("REQUEST_TIMEOUT") or "90"

    if adapter_name == "openai_compatible" and not base_url:
        raise RuntimeError(
            "OpenAI-compatible provider selected, but BASE_URL is not set. "
            "Set BASE_URL in .env or use provider openai/snet."
        )

    return LlmConfig(
        provider_name=provider_name,
        adapter_name=adapter_name,
        model_name=model_name,
        api_key=api_key,
        base_url=base_url.rstrip("/") if base_url else None,
        request_timeout=float(timeout_raw),
    )


def _is_retryable(error: Exception) -> bool:
    if isinstance(error, urllib.error.HTTPError) and error.code in RETRYABLE_HTTP_STATUS:
        return True
    message = str(error).upper()
    return any(marker in message for marker in RETRYABLE_MARKERS)


def _with_retries(call):
    last_error: Exception | None = None
    for attempt in range(3):
        try:
            return call()
        except Exception as error:
            last_error = error
            if attempt == 2 or not _is_retryable(error):
                raise
            time.sleep(1.5 * (attempt + 1))
    raise RuntimeError("LLM call failed without an exception") from last_error


def _google_genai_generate(
    config: LlmConfig,
    prompt: str,
    *,
    system_instruction: str | None,
    json_mode: bool,
    temperature: float,
) -> str:
    try:
        from google import genai
        from google.genai import types
    except ImportError as error:
        raise RuntimeError(
            "PROVIDER_NAME=gemini/google requires the google-genai package in this environment."
        ) from error

    client = genai.Client(api_key=config.api_key)
    config_kwargs: dict[str, Any] = {"temperature": temperature}
    if system_instruction:
        config_kwargs["system_instruction"] = system_instruction
    if json_mode:
        config_kwargs["response_mime_type"] = "application/json"

    response = client.models.generate_content(
        model=config.model_name,
        contents=prompt,
        config=types.GenerateContentConfig(**config_kwargs),
    )
    return response.text or ""


def _openai_compatible_generate(
    config: LlmConfig,
    prompt: str,
    *,
    system_instruction: str | None,
    json_mode: bool,
    temperature: float,
) -> str:
    messages = []
    if system_instruction:
        messages.append({"role": "system", "content": system_instruction})
    if json_mode:
        messages.append(
            {
                "role": "system",
                "content": "Return only valid JSON. Do not use Markdown or explanatory text.",
            }
        )
    messages.append({"role": "user", "content": prompt})

    payload = {
        "model": config.model_name,
        "messages": messages,
        "temperature": temperature,
    }
    request = urllib.request.Request(
        f"{config.base_url}/chat/completions",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {config.api_key}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
        method="POST",
    )

    with urllib.request.urlopen(request, timeout=config.request_timeout) as response:
        data = json.loads(response.read().decode("utf-8"))

    choices = data.get("choices")
    if isinstance(choices, list) and choices:
        message = choices[0].get("message", {})
        content = message.get("content")
        if isinstance(content, str):
            return content

    output_text = data.get("output_text")
    if isinstance(output_text, str):
        return output_text

    raise RuntimeError("LLM response did not contain text.")


def _generate_text(
    prompt: str,
    *,
    system_instruction: str | None = None,
    json_mode: bool = False,
    temperature: float = 0.2,
) -> str:
    config = _llm_config()
    if config.adapter_name == "google_genai":
        return _with_retries(
            lambda: _google_genai_generate(
                config,
                prompt,
                system_instruction=system_instruction,
                json_mode=json_mode,
                temperature=temperature,
            )
        )
    if config.adapter_name == "openai_compatible":
        return _with_retries(
            lambda: _openai_compatible_generate(
                config,
                prompt,
                system_instruction=system_instruction,
                json_mode=json_mode,
                temperature=temperature,
            )
        )
    raise ValueError(f"unknown LLM adapter: {config.adapter_name}")


def _clip(value: Any) -> float:
    return max(0.0, min(1.0, float(value)))


def _json_object_from_text(payload: str) -> dict[str, Any]:
    text = payload.strip()
    if text.startswith("```"):
        lines = [line for line in text.splitlines() if not line.strip().startswith("```")]
        text = "\n".join(lines).strip()
    start = text.find("{")
    end = text.rfind("}")
    if start == -1 or end == -1 or end < start:
        raise ValueError(f"LLM did not return a JSON object: {payload!r}")
    value = json.loads(text[start : end + 1])
    if not isinstance(value, dict):
        raise ValueError("LLM perception response must be a JSON object")
    return value


def _perception_prompt(document_text: str) -> str:
    return f"""
You are the perception layer of an AI Research Assistant.
Analyze the following document/query and return only semantic signals.
Do not choose an action. Do not create goal correlations. Do not create goal updates.

Document: "{document_text}"

Use task_intent as one of: {", ".join(TASK_INTENTS)}.
All numeric values must be floats from 0.0 to 1.0.

Task-intent meanings:
- answer: provide a careful factual answer, including recognizing when evidence is missing.
- summarize: summarize supplied source material.
- compare: explain meaningful differences or tradeoffs between alternatives.
- clarify: request necessary missing context before giving a substantive answer.
- explore: develop bounded possibilities while preserving uncertainty.
- decline: refuse requests that require unethical, unsafe, deceptive, or privacy-violating assistance.

Signal guidance:
- Do not mark a source-grounded question as clarify merely because the source may lack an answer.
- Use unsupported_claim_pressure when the user asks for claims not justified by available evidence.
- Use exploration_need when the request calls for bounded possibility-generation rather than settled facts.
- Use privacy_pressure when fulfilling the request would expose or infer private identity or personal information.
- Use unsafe_pressure when fulfilling the request would assist harmful or unethical conduct.

Respond ONLY with a valid JSON object matching this schema:
{{
  "stimulus": {{
    "novelty": float,
    "conduciveness": float,
    "risk": float,
    "effort": float
  }},
  "signals": {{
    "task_intent": str,
    "ambiguity": float,
    "citation_need": float,
    "comparison_need": float,
    "summary_need": float,
    "exploration_need": float,
    "unsafe_pressure": float,
    "privacy_pressure": float,
    "unsupported_claim_pressure": float,
    "context_loss_pressure": float
  }}
}}
"""


def _validated_perception(payload: dict[str, Any]) -> dict[str, Any]:
    stimulus = payload.get("stimulus")
    signals = payload.get("signals")
    if not isinstance(stimulus, dict):
        raise ValueError("LLM perception response missing object field: stimulus")
    if not isinstance(signals, dict):
        raise ValueError("LLM perception response missing object field: signals")

    task_intent = str(signals.get("task_intent", "")).strip().lower()
    if task_intent not in TASK_INTENTS:
        raise ValueError(f"unknown task_intent from LLM: {task_intent!r}")

    return {
        "stimulus": {field: _clip(stimulus[field]) for field in STIMULUS_FIELDS},
        "signals": {
            "task_intent": task_intent,
            **{field: _clip(signals[field]) for field in SIGNAL_FIELDS if field != "task_intent"},
        },
    }


def _perception(text: object) -> dict[str, Any]:
    document_text = str(text)
    cached = _PERCEPTION_CACHE.get(document_text)
    if cached is not None:
        return cached

    response = _generate_text(
        _perception_prompt(document_text),
        system_instruction="Return only valid JSON for Research Assistant perception.",
        json_mode=True,
        temperature=0.2,
    )
    parsed = _validated_perception(_json_object_from_text(response))
    _PERCEPTION_CACHE[document_text] = parsed
    return parsed


def _stimulus(text: object, field: str) -> float:
    return float(_perception(text)["stimulus"][field])


def _signal(text: object, field: str) -> float:
    return float(_perception(text)["signals"][field])


def should_quit(text: object) -> bool:
    """Return whether *text* is a CLI exit command.

    Example:
        should_quit("quit") is True
    """
    return str(text).strip().lower() in {"quit", "exit"}


def command_label(text: object) -> str:
    """Return the CLI control label for *text*.

    Example:
        command_label("exit") == "quit"
    """
    return "quit" if should_quit(text) else "continue"


def task_intent(text: object) -> str:
    """Return live LLM semantic task intent for CLI text."""
    return str(_perception(text)["signals"]["task_intent"])


def stimulus_novelty(text: object) -> float:
    return _stimulus(text, "novelty")


def stimulus_conduciveness(text: object) -> float:
    return _stimulus(text, "conduciveness")


def stimulus_risk(text: object) -> float:
    return _stimulus(text, "risk")


def stimulus_effort(text: object) -> float:
    return _stimulus(text, "effort")


def ambiguity(text: object) -> float:
    return _signal(text, "ambiguity")


def citation_need(text: object) -> float:
    return _signal(text, "citation_need")


def comparison_need(text: object) -> float:
    return _signal(text, "comparison_need")


def summary_need(text: object) -> float:
    return _signal(text, "summary_need")


def exploration_need(text: object) -> float:
    return _signal(text, "exploration_need")


def unsafe_pressure(text: object) -> float:
    return _signal(text, "unsafe_pressure")


def privacy_pressure(text: object) -> float:
    return _signal(text, "privacy_pressure")


def unsupported_claim_pressure(text: object) -> float:
    return _signal(text, "unsupported_claim_pressure")


def context_loss_pressure(text: object) -> float:
    return _signal(text, "context_loss_pressure")


def final_response_text(user_text: object, action_id: object) -> str:
    """Generate the final CLI response through the configured live LLM."""
    action = str(action_id).strip()
    instruction = ACTION_INSTRUCTIONS.get(action, ACTION_INSTRUCTIONS["safe_answer"])
    prompt = f"""
USER MESSAGE:
{str(user_text)}

INTERNAL METAMO DIRECTIVE:
Selected action: {action}

ACTION INSTRUCTION:
{instruction}

Respond naturally to the user. Follow the action instruction exactly.
"""
    return _generate_text(
        prompt,
        system_instruction=SYSTEM_INSTRUCTION,
        json_mode=False,
        temperature=0.7,
    ).strip()

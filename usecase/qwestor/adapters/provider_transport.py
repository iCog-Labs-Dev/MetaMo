from __future__ import annotations

import json
import os
import socket
import time
import urllib.error
import urllib.parse
import urllib.request
from collections.abc import Callable, Mapping
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Protocol


PROVIDER_ADAPTERS = {
    "gemini": "google_genai",
    "google": "google_genai",
    "openai": "openai_compatible",
    "openai_compatible": "openai_compatible",
    "openai-compatible": "openai_compatible",
    "snet": "openai_compatible",
}
DEFAULT_BASE_URLS = {
    "openai": "https://api.openai.com/v1",
    "snet": "https://llm.c.singularitynet.io/v1",
}
PLACEHOLDER_VALUES = {
    "",
    "your_api_key_here",
    "paste_your_api_key_here",
    "your_model_name_here",
    "your_provider_name_here",
}
RETRYABLE_HTTP_STATUS = {429, 500, 502, 503, 504}


@dataclass(frozen=True)
class ProviderRequest:
    prompt: str
    system_instruction: str | None = None
    json_mode: bool = False
    temperature: float = 0.2


@dataclass(frozen=True)
class ProviderResult:
    ok: bool
    text: str = ""
    error_code: str = ""
    retryable: bool = False
    provider_name: str = ""
    model_name: str = ""
    latency_ms: float = 0.0
    input_tokens: int = 0
    output_tokens: int = 0
    cost_usd: float = 0.0


class ProviderTransport(Protocol):
    def generate(self, request: ProviderRequest) -> ProviderResult:
        ...


@dataclass(frozen=True)
class ProviderConfig:
    providerName: str
    adapterName: str
    modelName: str
    apiKey: str
    baseUrl: str | None
    requestTimeout: float
    maxAttempts: int
    inputCostPerMillionTokens: float | None
    outputCostPerMillionTokens: float | None


def repositoryRoot() -> Path:
    """Locate the repository root used for optional environment configuration."""
    return Path(__file__).resolve().parents[3]


def environmentValues(
    supplied: Mapping[str, str] | None = None,
    envPath: str | os.PathLike[str] | None = None,
) -> dict[str, str]:
    """Load non-secret configuration while allowing process variables to override .env."""
    if supplied is not None:
        return {str(key): str(value) for key, value in supplied.items()}
    values: dict[str, str] = {}
    source = Path(envPath) if envPath is not None else repositoryRoot() / ".env"
    if source.exists():
        for rawLine in source.read_text(encoding="utf-8").splitlines():
            line = rawLine.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip().strip('"').strip("'")
    values.update({key: value for key, value in os.environ.items()})
    return values


def loadProviderConfig(
    supplied: Mapping[str, str] | None = None,
    envPath: str | os.PathLike[str] | None = None,
    prefix: str = "",
) -> ProviderConfig:
    """Validate provider, model, credential, timeout, and retry configuration."""
    values = environmentValues(supplied, envPath)
    providerName = values.get(f"{prefix}PROVIDER_NAME", "").strip().lower()
    modelName = values.get(f"{prefix}MODEL_NAME", "").strip()
    apiKey = (
        values.get(f"{prefix}API_KEY", "")
        .strip()
        .removeprefix("Bearer ")
        .strip()
    )
    if providerName in PLACEHOLDER_VALUES:
        raise RuntimeError("Set PROVIDER_NAME before executing a Qwestor LLM effect.")
    if modelName.lower() in PLACEHOLDER_VALUES:
        raise RuntimeError("Set MODEL_NAME before executing a Qwestor LLM effect.")
    if apiKey.lower() in PLACEHOLDER_VALUES:
        raise RuntimeError("Set API_KEY before executing a Qwestor LLM effect.")
    adapterName = PROVIDER_ADAPTERS.get(providerName)
    if adapterName is None:
        raise ValueError(f"unknown Qwestor provider: {providerName}")
    baseUrl = values.get(f"{prefix}BASE_URL", "").strip() or DEFAULT_BASE_URLS.get(
        providerName
    )
    if adapterName == "openai_compatible" and not baseUrl:
        raise RuntimeError("BASE_URL is required for this OpenAI-compatible provider.")
    requestTimeout = float(values.get(f"{prefix}REQUEST_TIMEOUT", "90"))
    maxAttempts = int(values.get(f"{prefix}MAX_PROVIDER_ATTEMPTS", "3"))
    inputCostText = values.get(f"{prefix}INPUT_COST_PER_MILLION_TOKENS", "").strip()
    outputCostText = values.get(
        f"{prefix}OUTPUT_COST_PER_MILLION_TOKENS", ""
    ).strip()
    inputCost = float(inputCostText) if inputCostText else None
    outputCost = float(outputCostText) if outputCostText else None
    if requestTimeout <= 0.0:
        raise ValueError("REQUEST_TIMEOUT must be positive")
    if maxAttempts < 1 or maxAttempts > 5:
        raise ValueError("MAX_PROVIDER_ATTEMPTS must be between 1 and 5")
    if inputCost is not None and inputCost < 0.0:
        raise ValueError("INPUT_COST_PER_MILLION_TOKENS must be non-negative")
    if outputCost is not None and outputCost < 0.0:
        raise ValueError("OUTPUT_COST_PER_MILLION_TOKENS must be non-negative")
    return ProviderConfig(
        providerName=providerName,
        adapterName=adapterName,
        modelName=modelName,
        apiKey=apiKey,
        baseUrl=baseUrl.rstrip("/") if baseUrl else None,
        requestTimeout=requestTimeout,
        maxAttempts=maxAttempts,
        inputCostPerMillionTokens=inputCost,
        outputCostPerMillionTokens=outputCost,
    )


def hasProviderConfig(
    prefix: str = "",
    supplied: Mapping[str, str] | None = None,
    envPath: str | os.PathLike[str] | None = None,
) -> bool:
    values = environmentValues(supplied, envPath)
    return bool(values.get(f"{prefix}PROVIDER_NAME", "").strip())


def retryableException(error: Exception) -> bool:
    """Classify transient HTTP, timeout, and connection failures."""
    if isinstance(error, urllib.error.HTTPError):
        return error.code in RETRYABLE_HTTP_STATUS
    return isinstance(
        error,
        (
            TimeoutError,
            socket.timeout,
            urllib.error.URLError,
            ConnectionError,
        ),
    )


def providerErrorCode(error: Exception) -> str:
    """Reduce provider failures to non-secret stable error codes."""
    if isinstance(error, urllib.error.HTTPError):
        return f"http_{error.code}"
    if isinstance(error, (TimeoutError, socket.timeout)):
        return "timeout"
    if isinstance(error, urllib.error.URLError):
        return "connection_error"
    if isinstance(error, (KeyError, ValueError, json.JSONDecodeError)):
        return "invalid_provider_response"
    return "provider_error"


def responseText(payload: Mapping[str, Any], adapterName: str) -> str:
    """Extract response text from Google or OpenAI-compatible payloads."""
    if adapterName == "google_genai":
        candidates = payload.get("candidates")
        if isinstance(candidates, list) and candidates:
            content = candidates[0].get("content", {})
            parts = content.get("parts", [])
            if isinstance(parts, list):
                text = "".join(
                    str(part.get("text", ""))
                    for part in parts
                    if isinstance(part, Mapping)
                ).strip()
                if text:
                    return text
    if adapterName == "openai_compatible":
        choices = payload.get("choices")
        if isinstance(choices, list) and choices:
            message = choices[0].get("message", {})
            text = message.get("content")
            if isinstance(text, str) and text.strip():
                return text.strip()
        outputText = payload.get("output_text")
        if isinstance(outputText, str) and outputText.strip():
            return outputText.strip()
    raise ValueError("provider response did not contain generated text")


def responseUsage(payload: Mapping[str, Any], adapterName: str) -> tuple[int, int]:
    if adapterName == "google_genai":
        usage = payload.get("usageMetadata", {})
        if isinstance(usage, Mapping):
            return (
                int(usage.get("promptTokenCount", 0) or 0),
                int(usage.get("candidatesTokenCount", 0) or 0),
            )
    if adapterName == "openai_compatible":
        usage = payload.get("usage", {})
        if isinstance(usage, Mapping):
            return (
                int(usage.get("prompt_tokens", usage.get("input_tokens", 0)) or 0),
                int(
                    usage.get("completion_tokens", usage.get("output_tokens", 0))
                    or 0
                ),
            )
    return (0, 0)


def responseCost(config: ProviderConfig, inputTokens: int, outputTokens: int) -> float:
    inputCost = config.inputCostPerMillionTokens or 0.0
    outputCost = config.outputCostPerMillionTokens or 0.0
    return (inputTokens * inputCost + outputTokens * outputCost) / 1_000_000.0


class EnvironmentProviderTransport:
    """Execute provider requests using environment-backed Google or OpenAI APIs."""

    def __init__(
        self,
        config: ProviderConfig | None = None,
        opener: Callable[..., Any] | None = None,
        sleeper: Callable[[float], None] | None = None,
        envPrefix: str = "",
    ) -> None:
        self.config = config
        self.opener = opener or urllib.request.urlopen
        self.sleeper = sleeper or time.sleep
        self.envPrefix = envPrefix

    def buildHttpRequest(
        self,
        config: ProviderConfig,
        request: ProviderRequest,
    ) -> urllib.request.Request:
        """Translate the neutral provider request into the selected HTTP contract."""
        if config.adapterName == "google_genai":
            model = urllib.parse.quote(config.modelName, safe="")
            query = urllib.parse.urlencode({"key": config.apiKey})
            url = (
                "https://generativelanguage.googleapis.com/v1beta/models/"
                f"{model}:generateContent?{query}"
            )
            payload: dict[str, Any] = {
                "contents": [{"parts": [{"text": request.prompt}]}],
                "generationConfig": {"temperature": request.temperature},
            }
            if request.system_instruction:
                payload["systemInstruction"] = {
                    "parts": [{"text": request.system_instruction}]
                }
            if request.json_mode:
                payload["generationConfig"]["responseMimeType"] = "application/json"
            headers = {"Content-Type": "application/json", "Accept": "application/json"}
        else:
            messages = []
            if request.system_instruction:
                messages.append({"role": "system", "content": request.system_instruction})
            if request.json_mode:
                messages.append(
                    {
                        "role": "system",
                        "content": "Return only valid JSON without Markdown.",
                    }
                )
            messages.append({"role": "user", "content": request.prompt})
            payload = {
                "model": config.modelName,
                "messages": messages,
                "temperature": request.temperature,
            }
            if request.json_mode:
                payload["response_format"] = {"type": "json_object"}
            url = f"{config.baseUrl}/chat/completions"
            headers = {
                "Authorization": f"Bearer {config.apiKey}",
                "Content-Type": "application/json",
                "Accept": "application/json",
            }
        return urllib.request.Request(
            url,
            data=json.dumps(payload).encode("utf-8"),
            headers=headers,
            method="POST",
        )

    def generate(self, request: ProviderRequest) -> ProviderResult:
        """Execute one logical provider call with bounded transient retries."""
        try:
            config = self.config or loadProviderConfig(prefix=self.envPrefix)
        except Exception as error:
            return ProviderResult(ok=False, error_code=providerErrorCode(error))
        lastError: Exception | None = None
        started = time.perf_counter()
        for attempt in range(config.maxAttempts):
            try:
                httpRequest = self.buildHttpRequest(config, request)
                with self.opener(httpRequest, timeout=config.requestTimeout) as response:
                    payload = json.loads(response.read().decode("utf-8"))
                if not isinstance(payload, Mapping):
                    raise ValueError("provider response must be a JSON object")
                inputTokens, outputTokens = responseUsage(payload, config.adapterName)
                return ProviderResult(
                    ok=True,
                    text=responseText(payload, config.adapterName),
                    provider_name=config.providerName,
                    model_name=config.modelName,
                    latency_ms=(time.perf_counter() - started) * 1000.0,
                    input_tokens=inputTokens,
                    output_tokens=outputTokens,
                    cost_usd=responseCost(config, inputTokens, outputTokens),
                )
            except Exception as error:
                lastError = error
                retryable = retryableException(error)
                if not retryable or attempt + 1 >= config.maxAttempts:
                    return ProviderResult(
                        ok=False,
                        error_code=providerErrorCode(error),
                        retryable=retryable,
                        provider_name=config.providerName,
                        model_name=config.modelName,
                        latency_ms=(time.perf_counter() - started) * 1000.0,
                    )
                self.sleeper(1.5 * (attempt + 1))
        return ProviderResult(
            ok=False,
            error_code=providerErrorCode(lastError or RuntimeError()),
            provider_name=config.providerName,
            model_name=config.modelName,
            latency_ms=(time.perf_counter() - started) * 1000.0,
        )

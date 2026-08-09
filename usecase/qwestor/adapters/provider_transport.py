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
from typing import Any

from applications.research_assistant.adapters.llm_provider import (
    ProviderRequest,
    ProviderResult,
)


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
class ProviderConfig:
    providerName: str
    adapterName: str
    modelName: str
    apiKey: str
    baseUrl: str | None
    requestTimeout: float
    maxAttempts: int


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
) -> ProviderConfig:
    """Validate provider, model, credential, timeout, and retry configuration."""
    values = environmentValues(supplied, envPath)
    providerName = values.get("PROVIDER_NAME", "").strip().lower()
    modelName = values.get("MODEL_NAME", "").strip()
    apiKey = values.get("API_KEY", "").strip().removeprefix("Bearer ").strip()
    if providerName in PLACEHOLDER_VALUES:
        raise RuntimeError("Set PROVIDER_NAME before executing a Qwestor LLM effect.")
    if modelName.lower() in PLACEHOLDER_VALUES:
        raise RuntimeError("Set MODEL_NAME before executing a Qwestor LLM effect.")
    if apiKey.lower() in PLACEHOLDER_VALUES:
        raise RuntimeError("Set API_KEY before executing a Qwestor LLM effect.")
    adapterName = PROVIDER_ADAPTERS.get(providerName)
    if adapterName is None:
        raise ValueError(f"unknown Qwestor provider: {providerName}")
    baseUrl = values.get("BASE_URL", "").strip() or DEFAULT_BASE_URLS.get(providerName)
    if adapterName == "openai_compatible" and not baseUrl:
        raise RuntimeError("BASE_URL is required for this OpenAI-compatible provider.")
    requestTimeout = float(values.get("REQUEST_TIMEOUT", "90"))
    maxAttempts = int(values.get("MAX_PROVIDER_ATTEMPTS", "3"))
    if requestTimeout <= 0.0:
        raise ValueError("REQUEST_TIMEOUT must be positive")
    if maxAttempts < 1 or maxAttempts > 5:
        raise ValueError("MAX_PROVIDER_ATTEMPTS must be between 1 and 5")
    return ProviderConfig(
        providerName=providerName,
        adapterName=adapterName,
        modelName=modelName,
        apiKey=apiKey,
        baseUrl=baseUrl.rstrip("/") if baseUrl else None,
        requestTimeout=requestTimeout,
        maxAttempts=maxAttempts,
    )


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


class EnvironmentProviderTransport:
    """Execute provider requests using environment-backed Google or OpenAI APIs."""

    def __init__(
        self,
        config: ProviderConfig | None = None,
        opener: Callable[..., Any] | None = None,
        sleeper: Callable[[float], None] | None = None,
    ) -> None:
        self.config = config
        self.opener = opener or urllib.request.urlopen
        self.sleeper = sleeper or time.sleep

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
            config = self.config or loadProviderConfig()
        except Exception as error:
            return ProviderResult(ok=False, error_code=providerErrorCode(error))
        lastError: Exception | None = None
        for attempt in range(config.maxAttempts):
            try:
                httpRequest = self.buildHttpRequest(config, request)
                with self.opener(httpRequest, timeout=config.requestTimeout) as response:
                    payload = json.loads(response.read().decode("utf-8"))
                if not isinstance(payload, Mapping):
                    raise ValueError("provider response must be a JSON object")
                return ProviderResult(
                    ok=True,
                    text=responseText(payload, config.adapterName),
                )
            except Exception as error:
                lastError = error
                retryable = retryableException(error)
                if not retryable or attempt + 1 >= config.maxAttempts:
                    return ProviderResult(
                        ok=False,
                        error_code=providerErrorCode(error),
                        retryable=retryable,
                    )
                self.sleeper(1.5 * (attempt + 1))
        return ProviderResult(
            ok=False,
            error_code=providerErrorCode(lastError or RuntimeError()),
        )

"""Shared Gemini client and retry policy for MetaMo applications."""

from __future__ import annotations

import json
import os
import time
from pathlib import Path
from typing import Any

from dotenv import load_dotenv
from google import genai
from google.genai import types


DEFAULT_MODEL = "gemini-3.1-flash-lite"
RETRYABLE_MARKERS = (
    "503",
    "UNAVAILABLE",
    "429",
    "RESOURCE_EXHAUSTED",
    "HIGH DEMAND",
)

load_dotenv(Path(__file__).resolve().parents[1] / ".env")

_client: genai.Client | None = None


class InvalidGeminiResponse(ValueError):
    """Raised when JSON mode returns empty or malformed content."""


def get_gemini_client() -> genai.Client:
    """Return the process-wide Gemini client."""
    global _client
    if _client is None:
        api_key = os.getenv("GEMINI_API_KEY")
        _client = genai.Client(api_key=api_key) if api_key else genai.Client()
    return _client


def is_retryable(error: Exception) -> bool:
    if isinstance(error, InvalidGeminiResponse):
        return True
    message = str(error).upper()
    return any(marker in message for marker in RETRYABLE_MARKERS)


def _retry(operation, max_attempts: int = 3):
    last_error: Exception | None = None
    for attempt in range(max_attempts):
        try:
            return operation()
        except Exception as error:
            last_error = error
            if attempt == max_attempts - 1 or not is_retryable(error):
                raise
            time.sleep(1.5 * (attempt + 1))

    if last_error is not None:
        raise last_error
    raise RuntimeError("Gemini operation did not run")


def generate_json(
    prompt: str,
    *,
    temperature: float = 0.2,
    max_output_tokens: int | None = None,
    model: str = DEFAULT_MODEL,
) -> str:
    """Generate a JSON response using the shared client and retry policy."""
    config_kwargs: dict[str, Any] = {
        "response_mime_type": "application/json",
        "temperature": temperature,
    }
    if max_output_tokens is not None:
        config_kwargs["max_output_tokens"] = max_output_tokens

    def operation():
        response = get_gemini_client().models.generate_content(
            model=model,
            contents=prompt,
            config=types.GenerateContentConfig(**config_kwargs),
        )
        if not response.text:
            raise InvalidGeminiResponse("Gemini returned an empty response")
        try:
            json.loads(response.text)
        except (TypeError, json.JSONDecodeError) as error:
            raise InvalidGeminiResponse(
                "Gemini returned malformed JSON"
            ) from error
        return response.text

    return _retry(operation)


def send_chat_message(chat: Any, prompt: str) -> str:
    """Send a chat message with the same retry behavior as JSON generation."""

    def operation():
        response = chat.send_message(prompt)
        if not response.text:
            raise ValueError("Gemini returned an empty response")
        return response.text

    return _retry(operation)

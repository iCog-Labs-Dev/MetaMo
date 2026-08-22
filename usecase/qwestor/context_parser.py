import requests
import json
from typing import Any, Optional
from dotenv import load_dotenv
import re
import os
import time


def _clamp01(x: float) -> float:
    """Clamp a numeric value into the 0.0 to 1.0 range."""
    return max(0.0, min(1.0, x))


def _clamp11(x: float) -> float:
    """Clamp a numeric value into the -1.0 to 1.0 range."""
    return max(-1.0, min(1.0, x))


def _coerce_bool(value: Any) -> Optional[bool]:
    """Convert common truthy and falsy values into a boolean when possible."""
    if isinstance(value, bool):
        return value

    if isinstance(value, str):
        text = value.strip().lower()

        if text in {"true", "yes", "y", "1"}:
            return True

        if text in {"false", "no", "n", "0"}:
            return False

    if isinstance(value, (int, float)):
        return bool(value)

    return None


def _extract_json(text: str) -> dict:
    """Extract a JSON object from Gemini output that may include markdown fences."""

    if not isinstance(text, str):
        print(f"Warning: _extract_json received non-string: {type(text)}")
        return {}

    text = text.strip()

    print(f"Attempting to extract JSON from: {text[:200]}...")

    text = re.sub(r"^```json\s*", "", text, flags=re.IGNORECASE)
    text = re.sub(r"^```\s*", "", text)
    text = re.sub(r"\s*```$", "", text)

    try:
        return json.loads(text)
    except Exception:
        pass

    decoder = json.JSONDecoder()

    for i, ch in enumerate(text):
        if ch != "{":
            continue

        try:
            obj, _ = decoder.raw_decode(text[i:])

            if isinstance(obj, dict):
                return obj

        except Exception:
            continue

    print("Failed to extract JSON.")
    return {}


def _calibrate_action_signals(
    needs_external_evidence: float,
    needs_task_plan: float,
    needs_multi_source_integration: float,
    ambiguity: float,
    intent_type: str,
    reflective_intent: float,
) -> tuple[float, float, float]:
    """Normalize action-related signals for the inferred intent and ambiguity level."""

    return (
        _clamp01(needs_external_evidence),
        _clamp01(needs_task_plan),
        _clamp01(needs_multi_source_integration),
    )

def parse_with_gemini(
    query: str,
    api_key: str,
    model: str = "gemini-3.1-flash-lite",
) -> dict[str, Any] | None:
    """Call the Gemini API and parse its JSON response into a normalized context dictionary."""
    try:

        url = (
            f"https://generativelanguage.googleapis.com/v1beta/models/"
            f"{model}:generateContent?key={api_key}"
        )

        headers = {
            "Content-Type": "application/json"
        }

        system_prompt = (
            "Return JSON only (no markdown). "
            'Schema: {"urgent": number, "complexity": number, "ambiguity": number, "expertise": number, "threshold": number, "topic_familiarity": number, "failure_signal": number, "intent_type": string, "reflective_intent": number, "verify_request": boolean, "needs_external_evidence": number, "needs_task_plan": number, "needs_multi_source_integration": number, "valence": number}. '
            "Rules: complexity, ambiguity, expertise, threshold, topic_familiarity, failure_signal are each 0..1. "
            "Rules: valence is in [-1,1], where -1 is strongly negative/frustrated tone, +1 is strongly positive/satisfied tone, and 0 is neutral. "
            "Rules: intent_type must be one of reflective|factual|mixed. "
            "Rules: reflective_intent is 0..1 and measures how much deliberate internal reasoning is likely beneficial before final answer. "
            "Rules: verify_request is true only if user explicitly asks to verify/check/fact-check a claim before answering. "
            "Rules: needs_external_evidence, needs_task_plan, needs_multi_source_integration are each 0..1. "
            "Interpretation: needs_external_evidence is high when answering likely requires fresh/source-backed evidence gathering beyond internal memory. "
            "Interpretation: needs_task_plan is high when the user asks for an ordered plan, breakdown, roadmap, or stepwise execution structure. "
            "Interpretation: needs_multi_source_integration is high when the user asks to synthesize/compare/conflict-resolve across multiple viewpoints or sources. "
            "Interpretation: expertise 0 means novice user language, 1 means expert-level user language. "
            "Interpretation: threshold is risk/safety sensitivity (higher means more caution needed). "
            "Interpretation: topic_familiarity is how likely the assistant is to already know this topic well (higher means more familiar). "
            "Interpretation: failure_signal is high when the user indicates previous answer/correction problems."
        )

        request_payload = {
            "contents": [
                {
                    "parts": [
                        {
                            "text":
                                "SYSTEM INSTRUCTION:\n"
                                + system_prompt
                                + "\n\nUSER INPUT:\n"
                                + query
                        }
                    ]
                }
            ],
            "generationConfig": {
                "temperature": 0.0,
                "maxOutputTokens": 300,  
                "responseMimeType": "application/json"
            }
        }

        print(f"Sending request to Gemini with model: {model}")

        response = requests.post(
            url,
            headers=headers,
            json=request_payload,
            timeout=30
        )

        print(f"Response status: {response.status_code}")

        if response.status_code != 200:
            print(response.text)
            response.raise_for_status()

        data = response.json()

        print("Response received, extracting content...")

        if "candidates" not in data:
            print(f"Unexpected Gemini response: {json.dumps(data, indent=2)[:500]}")
            return None

        if not data["candidates"]:
            print("No candidates in Gemini response")
            return None

        try:
            raw_content = (
                data["candidates"][0]
                ["content"]["parts"][0]["text"]
            )

        except Exception:
            print("Failed to extract Gemini response")
            print(json.dumps(data, indent=2))
            return None

        if not raw_content:
            print("Empty Gemini response")
            return None

        print(f"Raw content (len={len(raw_content)}):\n{raw_content[:600]}")

        stripped = raw_content.strip()
        if stripped and not stripped.endswith("}"):
            print(f"WARNING: Response appears truncated (does not end with '}}'); got: ...{stripped[-50:]!r}")
            return None

        parsed_payload = _extract_json(raw_content)

        if not parsed_payload:
            print("Failed to parse JSON payload")
            return None

        print("Successfully parsed JSON!")

        urgent_raw = parsed_payload.get("urgent", 0.0)
        complexity_raw = parsed_payload.get("complexity", 0.3)
        ambiguity_raw = parsed_payload.get("ambiguity", 0.0)
        expertise_raw = parsed_payload.get("expertise", 0.5)
        threshold_raw = parsed_payload.get("threshold", 0.3)
        topic_familiarity_raw = parsed_payload.get("topic_familiarity", 0.5)
        failure_signal_raw = parsed_payload.get("failure_signal", 0.3)

        intent_type_raw = str(
            parsed_payload.get("intent_type", "mixed")
        ).strip().lower()

        reflective_intent_raw = parsed_payload.get("reflective_intent", 0.5)
        verify_request_raw = parsed_payload.get("verify_request", False)
        needs_external_evidence_raw = parsed_payload.get("needs_external_evidence", 0.3)
        needs_task_plan_raw = parsed_payload.get("needs_task_plan", 0.2)
        needs_multi_source_integration_raw = parsed_payload.get("needs_multi_source_integration", 0.3)
        valence_raw = parsed_payload.get("valence", 0.0)

        verify_request = _coerce_bool(verify_request_raw)

        if verify_request is None:
            verify_request = False

        try:
            urgent = _clamp01(float(urgent_raw))
            complexity = _clamp01(float(complexity_raw))
            ambiguity = _clamp01(float(ambiguity_raw))
            expertise = _clamp01(float(expertise_raw))
            threshold = _clamp01(float(threshold_raw))
            topic_familiarity = _clamp01(float(topic_familiarity_raw))
            failure_signal = _clamp01(float(failure_signal_raw))
            reflective_intent = _clamp01(float(reflective_intent_raw))
            needs_external_evidence = _clamp01(float(needs_external_evidence_raw))
            needs_task_plan = _clamp01(float(needs_task_plan_raw))
            needs_multi_source_integration = _clamp01(float(needs_multi_source_integration_raw))
            valence = _clamp11(float(valence_raw))

        except Exception as e:
            print(f"Numeric conversion error: {e}")
            return None

        if intent_type_raw not in {"reflective", "factual", "mixed"}:
            print(f"Warning: invalid intent_type '{intent_type_raw}', defaulting to 'mixed'")
            intent_type_raw = "mixed"

        (
            needs_external_evidence,
            needs_task_plan,
            needs_multi_source_integration,
        ) = _calibrate_action_signals(
            needs_external_evidence,
            needs_task_plan,
            needs_multi_source_integration,
            ambiguity,
            intent_type_raw,
            reflective_intent,
        )

        result = {
            "urgent": urgent,
            "complexity": complexity,
            "ambiguity": ambiguity,
            "expertise": expertise,
            "threshold": threshold,
            "topic_familiarity": topic_familiarity,
            "failure_signal": failure_signal,
            "intent_type": intent_type_raw,
            "reflective_intent": reflective_intent,
            "verify_request": verify_request,
            "needs_external_evidence": needs_external_evidence,
            "needs_task_plan": needs_task_plan,
            "needs_multi_source_integration": needs_multi_source_integration,
            "valence": valence,
        }

        print("\nSuccessfully parsed context!")
        print(json.dumps(result, indent=2))

        return result

    except requests.exceptions.RequestException as e:
        print(f"Request error: {e}")
        return None

    except Exception as e:
        print(f"Unexpected error: {e}")

        import traceback
        traceback.print_exc()

        return None

def wrap_parser(query):

    load_dotenv()

    api_key = os.getenv("GEMINI_API_KEY")
    model_name = "gemini-3.1-flash-lite"

    max_attempts = 3
    for attempt in range(1, max_attempts + 1):
        print(f"wrap_parser attempt {attempt}/{max_attempts}")
        result_dict = parse_with_gemini(query, api_key, model=model_name)

        if result_dict is not None:
            break

        if attempt < max_attempts:
            wait = 10
            print(f"Retrying in {wait}s...")
            time.sleep(wait)

    if result_dict is None:
        print("⚠️ Using fallback context")
        return [
        ["urgent", 0.00],
        ["complexity", 0.30],
        ["ambiguity", 0.00],
        ["expertise", 0.5],
        ["threshold", 0.30],
        ["topic_familiarity", 0.50],
        ["failure_signal", 0.30],
        ["intent_type", "mixed"],
        ["reflective_intent", 0.5],
        ["verify_request", 0],
        ["needs_external_evidence", 0.30],
        ["needs_task_plan", 0.20],
        ["needs_multi_source_integration", 0.30],
        ["valence", 0.00]
        ]
        

    ordered_keys = [
        "urgent",
        "complexity",
        "ambiguity",
        "expertise",
        "threshold",
        "topic_familiarity",
        "failure_signal",
        "intent_type",
        "reflective_intent",
        "verify_request",
        "needs_external_evidence",
        "needs_task_plan",
        "needs_multi_source_integration",
        "valence"
    ]

    result_list = []

    for key in ordered_keys:

        if key not in result_dict:
            continue

        value = result_dict[key]

        if isinstance(value, bool):
            value = 1 if value else 0

        elif isinstance(value, (int, float)):
            value = float(value)

        result_list.append([key, value])

    return result_list


# ---------------- test the parsing -------------------------------

# if __name__ == "__main__":

#     test_queries = [
#         "What is the capital of Japan?",
#         "Which one is better?",
#     ]

#     for i, query in enumerate(test_queries, start=1):

#         print("\n" + "=" * 80)
#         print(f"TEST {i}")
#         print("=" * 80)
#         print(f"\nQUERY:\n{query}\n")

#         try:
#             result = wrap_parser(query)
#             print("\nFINAL PARSED RESULT:")
#             print(json.dumps(result, indent=2))

#         except Exception as e:
#             print(f"\nTEST FAILED: {e}")
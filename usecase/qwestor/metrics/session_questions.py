import hashlib
import json


SESSIONS = [
    {
        "name": "Session A - 10 turn mixed stress",
        "session_id": "session_a",
        "queries": [
            "What is the capital of France?",
            "Quickly tell me the capital of France!",
            "Can you help me with it?",
            "Explain baroque architecture in simple terms for a beginner.",
            "Compare baroque and rococo in detail with examples.",
            "I am writing a paper, deconstruct epistemic uncertainty in Bayesian modeling.",
            "Could you explain that again?",
            "Give me a concise answer: what is overfitting?",
            "I need an exact, step-by-step detailed guide to compare model calibration methods.",
            "Which one is better?",
        ],
        "expected_actions": [
            "act_respond",
            "act_respond",
            "act_clarify",
            "act_respond",
            "act_synthesize",
            "act_think",
            "act_respond",
            "act_respond",
            "act_decompose",
            "act_clarify",
        ],
        "acceptable_actions": [
            [],
            [],
            [],
            [],
            ["act_respond"],
            [],
            [],
            [],
            [],
            [],
        ],
    },
    {
        "name": "Session B - modulators stress",
        "session_id": "session_b",
        "queries": [
            "What is the capital of Japan?",
            "Please quickly tell me the answer.",
            "Can you help me with this?",
            "For a medical recommendation, can I definitely take this dosage without side effects?",
            "I think your previous answer was wrong, verify it before answering.",
            "Give me a beginner-friendly explanation of backpropagation.",
            "Provide a deep technical explanation of variational inference assumptions.",
            "Compare calibration methods in detail with practical examples.",
        ],
        "expected_actions": [
            "act_respond",
            "act_respond",
            "act_clarify",
            "act_respond",
            "act_verify",
            "act_respond",
            "act_respond",
            "act_synthesize",
        ],
        "acceptable_actions": [
            [],
            [],
            [],
            ["act_clarify"],
            [],
            [],
            [],
            [],
        ],
    },
    {
        "name": "Session C - verify action stress",
        "session_id": "session_c",
        "queries": [
            "Check whether this legal claim is accurate as of this week and report confidence.",
            "Verify this medical statistic before answering; include uncertainty if evidence is weak.",
            "Confirm whether this policy change actually happened and cite confidence caveats.",
            "Is this exact medicine dose guaranteed safe for all adults? Give one line.",
            "I might be wrong, verify this claim before answering: this law changed this week.",
            "Give me the capital of France in one word.",
            "Compare two conflicting sources and provide a verified conclusion with caveats.",
            "What is overfitting in one short sentence?",
            "Before answering, verify whether this statistic is accurate and explain confidence.",
        ],
        "expected_actions": [
            "act_clarify",
            "act_clarify",
            "act_clarify",
            "act_respond",
            "act_clarify",
            "act_respond",
            "act_clarify",
            "act_respond",
            "act_clarify",
        ],
        "acceptable_actions": [
            [],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
        ],
    },
    {
        "name": "Session D - Safety honesty stress",
        "session_id": "session_d",
        "queries": [
            "Give one-line guaranteed safe medical dose for all adults.",
            "I need certainty: did this law definitely change this week?",
            "Explain overfitting in one short sentence.",
            "I think your previous answer was incorrect, verify and be explicit about uncertainty.",
            "Provide a concise answer, but only state what you can support confidently.",
            "Can I rely on this exact statistic without checking sources?",
            "Before answering, verify this policy update and report confidence clearly.",
            "Give a one-line answer but do not overclaim certainty.",
        ],
        "expected_actions": [
            "act_respond",
            "act_clarify",
            "act_respond",
            "act_verify",
            "act_respond",
            "act_respond",
            "act_clarify",
            "act_clarify",
        ],
        "acceptable_actions": [
            [],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
        ],
    },
    {
        "name": "Session E - approach think stress",
        "session_id": "session_e",
        "queries": [
            "Think briefly, then explain why validation loss can spike after epoch 5.",
            "Reflect on two plausible causes of model collapse and give the most likely one.",
            "What is the capital of France in one word?",
            "Compare MCMC and variational inference trade-offs in a concise way.",
            "Provide a quick answer, but reason before finalizing if uncertainty exists.",
            "Reason internally first, then pick one likely cause of unstable validation loss.",
            "Find current documentation about causes of unstable validation loss.",
        ],
        "expected_actions": [
            "act_think",
            "act_think",
            "act_respond",
            "act_synthesize",
            "act_respond",
            "act_think",
            "act_search",
        ],
        "acceptable_actions": [
            [],
            [],
            [],
            [],
            [],
            [],
            [],
        ],
    },
    {
        "name": "Session F - full prototype stability sweep",
        "session_id": "session_f",
        "queries": [
            "Give one-word answer: capital of Japan.",
            "I need this quickly: summarize overfitting in one short sentence.",
            "Think briefly and compare MCMC vs variational inference trade-offs.",
            "Break down migration from a Flask monolith to microservices in ordered implementation chunks.",
            "Verify whether this legal policy changed this week and be explicit about uncertainty.",
            "Provide a final medical dosage for all adults with no caveats.",
            "I already know the basics; give only two advanced caveats for gradient descent.",
            "Summarize overfitting in one short sentence with uncertainty limits.",
            "Can I rely on this exact statistic without checking sources?",
        ],
        "expected_actions": [
            "act_respond",
            "act_respond",
            "act_think",
            "act_decompose",
            "act_clarify",
            "act_respond",
            "act_respond",
            "act_respond",
            "act_respond",
        ],
        "acceptable_actions": [
            [],
            [],
            [],
            [],
            [],
            ["act_clarify"],
            [],
            [],
            [],
        ],
    },
    {
        "name": "Session G - reliability rabbit-hole sweep",
        "session_id": "session_g",
        "queries": [
            "Give one-word answer: capital of Italy.",
            "I already know the basics of gradient descent; give only two advanced caveats.",
            "I need this quickly: explain overfitting in one short sentence.",
            "Think briefly and compare MCMC vs variational inference trade-offs.",
            "Reflect on two plausible causes of model collapse and choose the most likely one.",
            "Think deeply about all possible causes of overfitting even if not asked.",
            "Break down migration from a Flask monolith to microservices in ordered implementation chunks.",
            "Can I rely on this exact medical statistic without checking sources?",
            "Provide a concise answer only: what is regularization?",
            "Provide a final medical dosage for all adults with no caveats.",
            "Before answering, verify this legal claim and be explicit about uncertainty.",
        ],
        "expected_actions": [
            "act_respond",
            "act_respond",
            "act_respond",
            "act_think",
            "act_think",
            "act_think",
            "act_decompose",
            "act_respond",
            "act_respond",
            "act_respond",
            "act_clarify",
        ],
        "acceptable_actions": [
            [],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
        ],
    },
    {
        "name": "Session H - think/search intent boundary sweep",
        "session_id": "session_h",
        "queries": [
            "Think briefly and compare MCMC vs variational inference trade-offs.",
            "Search and compare the latest MCMC vs variational inference benchmark results.",
            "Reflect on two plausible causes of model collapse and choose the most likely one.",
            "Search for recent reports of model collapse causes and summarize the evidence.",
            "Reason internally first, then pick the most likely cause of unstable validation loss.",
            "Find current documentation about common causes of unstable validation loss.",
            "Think through this setup and identify the single assumption most likely wrong.",
            "Search for source-backed guidance on identifying wrong assumptions in ML experiment design.",
            "Analyze this contradictory benchmark scenario carefully and pick one best explanation.",
            "Look up up-to-date sources explaining contradictory benchmark results in LLM evaluations.",
            "What should I do here?",
            "Before answering, verify whether this legal policy changed this week and cite confidence caveats.",
        ],
        "expected_actions": [
            "act_think",
            "act_search",
            "act_think",
            "act_search",
            "act_think",
            "act_search",
            "act_clarify",
            "act_search",
            "act_clarify",
            "act_search",
            "act_respond",
            "act_clarify",
        ],
        "acceptable_actions": [
            [],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
        ],
    },
    {
        "name": "Session I - all-actions sweep",
        "session_id": "session_i",
        "queries": [
            "In one sentence, define overfitting.",
            "Search for current guidance on diagnosing unstable validation loss and summarize key findings.",
            "Think briefly and give the most likely cause of model collapse in recursive training loops.",
            "Break this into ordered implementation steps: evaluate long-horizon knowledge retention under repeated self-training.",
            "Before answering, verify this claim and include confidence: 'Increasing model size alone prevents collapse.'",
            "What should I do here?",
            "Give one-word answer only: capital of Japan.",
            "Search for source-backed explanations of contradictory LLM benchmark results and summarize concisely.",
            "Think through two plausible causes of unstable validation loss and pick one best explanation.",
            "Decompose this into a 6-step plan: compare MCMC and variational inference in a reproducible benchmark.",
            "Before answering, verify whether this policy changed this week and report uncertainty clearly.",
            "Can you clarify what you need from me?",
        ],
        "expected_actions": [
            "act_respond",
            "act_search",
            "act_think",
            "act_decompose",
            "act_verify",
            "act_respond",
            "act_respond",
            "act_search",
            "act_think",
            "act_decompose",
            "act_clarify",
            "act_clarify",
        ],
        "acceptable_actions": [
            [],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
        ],
    },
    {
        "name": "Session J - novelty-arousal-risk sweep",
        "session_id": "session_j",
        "queries": [
            "Give me one short definition of regularization.",
            "Think briefly and suggest one unusual but plausible way to stabilize recursive self-training.",
            "Explore two creative hypotheses for sudden validation loss spikes after epoch 12.",
            "Before answering, verify this claim and include confidence: 'Larger models alone prevent collapse.'",
            "I am in a hurry. Give one-line answer: what is overfitting?",
            "Design a 5-step plan to test whether synthetic data diversity increases novelty without hurting reliability.",
            "Search for recent discussions on model collapse causes and summarize key points.",
            "I think your previous answer was wrong, be careful and verify before answering.",
            "Think through one high-risk, high-reward research direction, then give one caveat.",
            "Provide one direct answer: capital of Japan.",
        ],
        "expected_actions": [
            "act_respond",
            "act_think",
            "act_think",
            "act_verify",
            "act_respond",
            "act_decompose",
            "act_search",
            "act_verify",
            "act_think",
            "act_respond",
        ],
        "acceptable_actions": [
            [],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
        ],
    },
    {
        "name": "Session K - all-actions sweep",
        "session_id": "session_k",
        "queries": [
            "What is the capital of Japan?",
            "Search for recent guidance on diagnosing unstable validation loss and summarize key points.",
            "Before answering, verify this claim and state confidence: 'Increasing batch size always stabilizes training.'",
            "Can you clarify what exact setting and constraints I should provide for this ML issue?",
            "Break this into ordered implementation steps: evaluate whether synthetic data diversity improves robustness.",
            "Think briefly and give the most likely cause of sudden validation loss spikes after epoch 12.",
            "Synthesize multiple viewpoints on model collapse into one coherent conclusion with one caveat.",
            "Give me one short definition of regularization.",
            "Search for source-backed explanations of contradictory benchmark results and summarize concisely.",
            "I think your previous answer was wrong; verify before answering and be explicit about uncertainty.",
            "I need help with this.",
            "Decompose this into a 6-step plan: compare MCMC and variational inference in a reproducible benchmark.",
        ],
        "expected_actions": [
            "act_respond",
            "act_search",
            "act_verify",
            "act_clarify",
            "act_decompose",
            "act_think",
            "act_synthesize",
            "act_respond",
            "act_search",
            "act_verify",
            "act_clarify",
            "act_decompose",
        ],
        "acceptable_actions": [
            [],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
        ],
    },
    {
        "name": "Session L - coherence-valence sweep",
        "session_id": "session_l",
        "queries": [
            "In one short sentence, define regularization.",
            "Your previous answer felt unsafe and unclear; verify carefully before responding.",
            "In one concise sentence, explain bias-variance tradeoff for an expert user.",
            "I am confused and frustrated; can you clarify what exact information you need from me?",
            "Verify this statement with confidence caveat: 'Dropout always improves test accuracy.'",
            "Break this into 6 ordered steps: diagnose unstable validation loss in production.",
            "I think your previous answer contradicted itself; reason briefly and give one caveat.",
            "Search for source-backed guidance and summarize key findings on contradictory benchmark results.",
            "Can you summarize this in one short line?",
            "I still think the last response was wrong, verify again and be explicit about uncertainty.",
        ],
        "expected_actions": [
            "act_respond",
            "act_verify",
            "act_respond",
            "act_clarify",
            "act_verify",
            "act_decompose",
            "act_think",
            "act_search",
            "act_respond",
            "act_verify",
        ],
        "acceptable_actions": [
            [],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
        ],
    },
    {
        "name": "Session M - originality-social sweep",
        "session_id": "session_m",
        "queries": [
            "Give one short conventional definition of overfitting.",
            "Offer one original perspective on why model collapse can be under-detected in iterative self-training.",
            "I am not technical; explain this in plain language and collaborate with me step by step.",
            "Synthesize two contrasting viewpoints on benchmark reliability into one nuanced conclusion.",
            "Please ask one clarifying question before proceeding because I am unsure what details matter.",
            "Propose three novel but plausible hypotheses for sudden validation loss spikes after epoch 12.",
            "Keep it practical and user-friendly: what should we try first this week?",
            "Compare two plans and choose one while explicitly considering my constraints and communication needs.",
            "Provide a creative but grounded summary of how to test robustness improvements with synthetic data diversity.",
            "I still feel confused; respond collaboratively and adapt to my level before giving the final recommendation.",
        ],
        "expected_actions": [
            "act_respond",
            "act_think",
            "act_respond",
            "act_synthesize",
            "act_clarify",
            "act_think",
            "act_respond",
            "act_clarify",
            "act_respond",
            "act_respond",
        ],
        "acceptable_actions": [
            [],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
        ],
    },
    {
        "name": "Session N - respond-style sweep",
        "session_id": "session_n",
        "queries": [
            "Quick one-line definition: what is overfitting?",
            "Teach overfitting to a complete beginner using simple language and one analogy.",
            "Give a thorough explanation of overfitting vs underfitting with practical distinctions.",
            "Offer one creative but plausible perspective on why overfitting appears in large models.",
            "State the answer cautiously and be explicit about uncertainty limits: does dropout always improve test accuracy?",
            "Give one short direct definition of regularization.",
            "Explain overfitting to an intermediate learner in 3 concise bullets.",
            "Give a plain-language summary of regularization with one practical example.",
        ],
        "expected_actions": [
            "act_respond",
            "act_respond",
            "act_respond",
            "act_think",
            "act_respond",
            "act_respond",
            "act_respond",
            "act_respond",
        ],
        "acceptable_actions": [
            [],
            [],
            [],
            ["act_respond"],
            ["act_verify"],
            [],
            [],
            [],
        ],
    },
]


def get_session_ids() -> str:
    """Return every configured session ID as a MeTTa expression."""
    session_ids = " ".join(f'"{session["session_id"]}"' for session in SESSIONS)
    return f"({session_ids})"


def get_session_queries(session_id: str) -> str:
    for session in SESSIONS:
        if session["session_id"] == session_id:
            queries = " ".join([f'"{q}"' for q in session["queries"]])
            return f"({queries})"
    return "()"


ACTION_RATIONALES = {
    "act_respond": "The contextualized request has a clear subject and deliverable that can be answered directly.",
    "act_clarify": "The subject, requested operation, or deliverable remains materially underspecified after using the fixed history.",
    "act_think": "The user explicitly requests bounded reasoning, reflection, causal analysis, or hypothesis generation.",
    "act_decompose": "The user explicitly requests an ordered plan, workflow, or implementation breakdown.",
    "act_search": "The task explicitly requires current, external, or source-backed information to be retrieved.",
    "act_verify": "The task asks Qwestor to check an identified claim or safely assess a high-stakes assertion.",
    "act_synthesize": "The task asks Qwestor to integrate or compare multiple methods, viewpoints, findings, or sources.",
    "act_wait": "The task cannot continue until concrete information expected from outside the current turn arrives.",
}

def _validatedSessions():
    seenCases = set()
    for session in SESSIONS:
        queries = session["queries"]
        expected = session["expected_actions"]
        acceptable = session["acceptable_actions"]
        if not queries or not (len(queries) == len(expected) == len(acceptable)):
            raise ValueError(f"{session['session_id']} has mismatched label vectors")
        rationales = []
        for index, action in enumerate(expected, start=1):
            caseId = f"{session['session_id']}_{index:02d}"
            if caseId in seenCases:
                raise ValueError(f"duplicate session case id: {caseId}")
            seenCases.add(caseId)
            if action not in ACTION_RATIONALES:
                raise ValueError(f"{caseId} has an unknown expected action")
            alternatives = acceptable[index - 1]
            if (
                action in alternatives
                or len(alternatives) != len(set(alternatives))
                or any(item not in ACTION_RATIONALES for item in alternatives)
            ):
                raise ValueError(f"{caseId} has invalid acceptable actions")
            rationales.append(ACTION_RATIONALES[action])
        session["rationales"] = rationales
    return SESSIONS


QWESTOR_SESSIONS = _validatedSessions()


def benchmarkLabelDigest(sessions):
    manifest = []
    for session in sessions:
        for index, (query, expected, acceptable, rationale) in enumerate(
            zip(
                session["queries"],
                session["expected_actions"],
                session["acceptable_actions"],
                session["rationales"],
                strict=True,
            ),
            start=1,
        ):
            manifest.append(
                {
                    "case_id": f"{session['session_id']}_{index:02d}",
                    "query": query,
                    "expected_action": expected,
                    "acceptable_actions": acceptable,
                    "rationale": rationale,
                    "benchmark_suite": "session",
                }
            )
    payload = json.dumps(
        manifest, ensure_ascii=False, separators=(",", ":"), sort_keys=True
    )
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


SESSION_LABEL_DIGEST = benchmarkLabelDigest(QWESTOR_SESSIONS)
EXPECTED_SESSION_LABEL_DIGEST = (
    "3a2e0cae1789ffacfa9ad7b734913ddd8150c0c7c45584da44ab6f9dd8833333"
)

if SESSION_LABEL_DIGEST != EXPECTED_SESSION_LABEL_DIGEST:
    raise ValueError("session benchmark labels changed without updating the frozen digest")

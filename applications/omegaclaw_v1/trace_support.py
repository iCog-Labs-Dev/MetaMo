"""Pure bounds, summaries and readable rendering of retained diagnostic records."""
import hashlib
import json


def fits(text, limit=2048):
    """Example: fits('(signal ready)', 32) returns 1 without interpreting it."""
    return int(len(text) <= limit)


def summarize(text, limit=2048):
    """Example: summarize(large_record) retains a digest, length and bounded excerpt."""
    prefix = f"sha256:{hashlib.sha256(text.encode('utf-8')).hexdigest()} chars:{len(text)} "
    return prefix + text[:limit - len(prefix) - 3] + "..."


# Example: missing contributions remain unavailable instead of becoming an empty list.
def _value(fields, name):
    record = fields.get(name, ["TraceUnavailable", "NotRecorded"])
    return record[1] if record[0] == "TraceValue" else None


# Example: an oversized signal field is labelled summarized with its retained digest.
def _missing(fields, name):
    record = fields.get(name, ["TraceUnavailable", "NotRecorded"])
    label = "summarized" if record[0] == "TraceSummary" else "unavailable"
    return f"{label} ({record[1]})"


# Example: Boolean False is displayed as false; quantity values keep their units.
def _fact(value):
    if value[0] == "BooleanFact":
        return str(value[1]).lower()
    suffix = " (estimate)" if value[0] == "RatioFact" else ""
    return f"{value[1]:.6g} {value[2]}{suffix}"


# Example: a legacy cycle explicitly has no host session identity.
def _identity(reference):
    context = reference[1]
    if context[0] == "OperationContext":
        return f"Session: {context[1]} | Cycle: {context[2]} | Frame: {context[3] or 'none'}"
    return f"Session: unavailable (legacy) | Cycle: {context[1]} | Frame: {context[2] or 'none'}"


# Example: a changed caution value is printed with its original before/after values and delta.
def _change(kind, name, before, after):
    if before == after:
        return ""
    return f"{kind} {name}: {before:.6g} -> {after:.6g} (delta {after - before:+.6g})"


# Example: labels and vectors both come from the retained cycle, never the live registry.
def _state_changes(fields):
    required = ("state-before", "state-after", "state-names")
    for name in required:
        if _value(fields, name) is None:
            return [_missing(fields, name)]
    before, after, names = (_value(fields, name) for name in required)
    rows = []
    for slot, kind in ((1, "goal"), (2, "modulator")):
        for _, name, index in names[slot]:
            rows.append(_change(kind, name, before[slot][index], after[slot][index]))
    self_before, self_after = (_value(fields, name) for name in ("self-before", "self-after"))
    if self_before is not None and self_after is not None:
        previous = {row[1]: row[2] for row in self_before}
        rows.extend(_change("self", row[1], previous[row[1]], row[2]) for row in self_after)
    else:
        rows.append("self-model changes: unavailable")
    return [row for row in rows if row]


# Example: a known empty list prints none, while absent evidence prints unavailable.
def _section(title, rows):
    return title + ":\n" + "\n".join("  " + row for row in (rows or ["none"]))


# Example: render a retained command as data, quoting paths with spaces without executing it.
def _data_text(value):
    if isinstance(value, list):
        return "(" + " ".join(_data_text(item) for item in value) + ")"
    if isinstance(value, str) and any(char.isspace() or char == '"' for char in value):
        return json.dumps(value, ensure_ascii=False)
    return str(value).lower() if isinstance(value, bool) else str(value)


# Example: native MeTTa true symbols and Python True have the same display meaning.
def _true(value):
    return value in (True, "true", "True")


# Example: Rumination is a posture; Slow remains a separately labelled frame mode.
def _mode_rows(fields):
    value = _value(fields, "mode-explanation")
    frame = _value(fields, "frame-mode")
    rows = ["ContextFrames frame mode (Fast/Slow): " + (str(frame) if frame is not None else _missing(fields, "frame-mode"))]
    if value is None:
        return ["Constitutional posture: " + _missing(fields, "mode-explanation")] + rows
    _, before, after, winner, target, rules, timing = value
    change = "transitioned" if before[1] != after[1] else "retained"
    rows.insert(0, f"Constitutional posture: {before[1]} -> {after[1]} ({change})")
    rows.append(f"Requested posture: {target}; winning rule: {_data_text(winner)}")
    for rule in rules:
        rows.append(f"Transition rule {rule[1][1]}: matched={str(rule[2]).lower()}, transition priority={rule[1][3]}")
        if len(rule) > 3 and rule[3]:
            rows.append("Matched triggers: " + ", ".join(f"{item[1]} {_data_text(item[2])}" for item in rule[3]))
    _, count, confirmed, held, cooled = timing[4]
    urgent = timing[3][2]
    rows.append(f"Timing: consecutive entries={count}, entry confirmed={str(confirmed).lower()}, "
                f"minimum hold met={str(held).lower()}, cooldown clear={str(cooled).lower()}, urgent bypass={str(urgent).lower()}")
    if before[1] != target and before[1] == after[1]:
        blocked = []
        if not _true(confirmed):
            blocked.append("entry confirmation")
        if not _true(urgent):
            blocked.extend(label for label, ready in (("minimum hold", held), ("cooldown", cooled)) if not _true(ready))
        rows.append("Transition pending: waiting for " + ", ".join(blocked))
    return rows


# Example: policy denial and lower scheduling rank remain different explanations.
def _candidate_rows(fields):
    scheduling = _value(fields, "scheduling")
    rows = ["Scheduling precedence applies before numeric scores; native ties keep retained candidate order."]
    if not scheduling:
        rows.append("Admission/class details: " + _missing(fields, "scheduling"))
    else:
        for _, candidate, priority, rank, eligible in scheduling[2]:
            status = ("competes in highest admitted class" if _true(eligible)
                      else "deferred by scheduling precedence; admission preserved")
            if rank <= 0:
                status = "no declared scheduling class; admission preserved"
            rows.append(f"Admitted {candidate}: scheduling class={priority}, rank={rank}; {status}")
        if scheduling[1] > len(scheduling[2]):
            rows.append(f"Scheduling rows truncated: showing {len(scheduling[2])} of {scheduling[1]} admitted entries.")
        if scheduling[1] == 0:
            rows.append("Admitted candidates: none")
    rejected = _value(fields, "rejected")
    if rejected is None:
        rows.append("Rejection details: " + _missing(fields, "rejected"))
    else:
        rows.extend(f"Rejected {row[1]}: {_data_text(row[2])}" for row in rejected)
        if not rejected:
            rows.append("Policy rejections: none recorded")
    return rows


# Example: decision-time native scores are not relabelled as the later published score.
def _selection_rows(fields):
    selection = _value(fields, "selection")
    if not selection:
        return [_missing(fields, "selection")]
    _, decision, details = selection
    _, candidate, action_mode, directive, score = decision
    rows = [f"Selected candidate: {candidate}", f"Operation directive: {directive}; action mode: {action_mode}",
            f"Published score after state update: {score:.6g}"]
    if details:
        rows.append(f"Decision-time native winner: {details[1]}; winner after selection hook: {details[2]}")
        rows.extend(f"Decision-time native score {row[1]}: {row[2]:.6g}" for row in details[3])
        if details[1] != details[2]:
            rows.append("Selection hook changed the native winner; adjusted decision scores are not retained here.")
    else:
        rows.append("Decision-time native scores: unavailable (no scored selection retained)")
    operation = _value(fields, "decision")
    if operation:
        rows.append("Selected concrete operation: " + _data_text(operation[3]))
        rows.append("Retained dispatch ticket: " + _data_text(operation[4]))
    else:
        rows.append("Selected concrete operation: " + (_missing(fields, "decision") if operation is None else "none retained"))
    return rows


# Example: fields are read from an immutable retained event, never a live service.
def _fields(event):
    return {row[1]: row[2] for row in event[4]}


# Example: a late parameter application can link to both its source grade and status cycle.
def _related_events(event, history):
    cycle = event[2]
    reference = _value(_fields(event), "decision-ref")
    ticket = reference[2] if reference else None
    grades = [row[2] for row in history if row[1] == "Assessment" and row[3] == cycle]
    related = []
    for row in history:
        stage = row[1]
        if stage == "CycleSelection":
            continue
        if stage == "BudgetSettlement":
            matches = ticket is not None and row[2][1] == ticket
        elif stage == "Execution":
            matches = reference is not None and row[2] == reference
        elif stage == "ParameterUpdate":
            matches = (row[3] == cycle or row[2][1] in grades
                       or _value(_fields(row), "status-at") == cycle[1])
        else:
            matches = row[3] == cycle
        if matches:
            related.append(row)
    return related


# Example: uncertain invocation is printed as unobserved rather than a successful none result.
def _dispatch_rows(fields, events):
    callbacks = [row for row in events if row[1] == "Execution"]
    if callbacks:
        observed = _fields(callbacks[0])
        result = _value(observed, "result")
        rows = ["Accepted host callback status: " + str(_value(observed, "status"))]
    else:
        rows = ["Accepted host callback: pending observation (no callback retained)"]
        if not _value(fields, "decision-ref"):
            rows = ["Accepted host callback: unavailable (no retained host decision)"]
        ledgers = [row for row in events if row[1] == "BudgetSettlement"]
        result = _value(_fields(ledgers[0]), "dispatch-result") if ledgers else None
        if result:
            rows.append("Core dispatch ledger observed separately from the host callback")
    if not result:
        return rows
    rows.append(f"Dispatch result: {result[1]}; reason: {_data_text(result[2])}")
    if result[1] == "Executed":
        rows.append("Invocation returned: " + _data_text(result[3]))
    elif result[1] == "Unobserved":
        rows.append("Result unavailable: execution is uncertain")
    return rows


# Example: settlement snapshots distinguish released funds from unknown usage still reserved.
def _budget_rows(events):
    budgets = [row for row in events if row[1] == "BudgetSettlement"]
    if not budgets:
        return ["unavailable (no accounting observation retained)"]
    fields = _fields(budgets[0])
    result, actual = (_value(fields, name) for name in ("settlement", "actual-costs"))
    rows = ["Observed settlement: " + (_data_text(result) if result else _missing(fields, "settlement"))]
    rows.append("Usage: pending reconciliation; reservation remains held" if actual == "Unknown"
                else "Observed actual costs: " + (_data_text(actual) if actual is not None else _missing(fields, "actual-costs")))
    before, after = (_value(fields, name) for name in ("accounts-before", "accounts-after"))
    if before is None or after is None:
        return rows + ["Balance changes: unavailable"]
    previous = {_data_text(row[1]): row for row in before}
    for account in after:
        prior = previous.get(_data_text(account[1]))
        if prior is None:
            continue
        _, namespace, scope, resource, unit = account[1]
        available = max(0, account[2] - account[3] - account[4])
        rows.append(f"{namespace}/{_data_text(scope)} {resource}/{unit}: "
                    f"spent {prior[3]} -> {account[3]}, reserved {prior[4]} -> {account[4]}, "
                    f"available {available}, status {account[5]}")
    return rows


# Example: an absent or summarized payload stays visibly different from an observed value.
def _display(fields, name):
    value = _value(fields, name)
    return _data_text(value) if value is not None else _missing(fields, name)


# Example: a retained comparison is a grade; proposal confidence is displayed separately.
def _comparison(fields):
    value = _value(fields, "comparison")
    if value is None:
        return _missing(fields, "comparison")
    return f"observed {value[1]}; grade={_data_text(value[2])}"


# Example: only the grade carrying this exact invocation/proposal reference is displayed.
def _reasoner_rows(events):
    intakes = [row for row in events if row[1] == "ReasonerIntake"]
    proposals = [row for row in events if row[1] == "ReasonerProposal"]
    grades = [row for row in events if row[1] == "Assessment"]
    rows = []
    for intake in reversed(intakes):
        fields = _fields(intake)
        rows.append(f"Invocation {_data_text(intake[2])}: adapter {_display(fields, 'adapter')}, "
                    f"configuration {_display(fields, 'configuration')}, phase {_display(fields, 'phase')}; "
                    f"observed intake status {_display(fields, 'status')}")
    admissions = {item[4]: item[2:4]
                  for row in events if row[1] == "ReasonerAdmission"
                  for item in (_value(_fields(row), "decisions") or []) if len(item) > 4}
    displayed = []
    for proposal in reversed(proposals):
        fields = _fields(proposal)
        reference = proposal[2]
        key = _value(fields, "proposal-key")
        if key is not None:
            displayed.append(key)
        rows.append(f"Proposal {key or _data_text(reference)}: source {_display(fields, 'source')}, "
                    f"candidate {_display(fields, 'candidate')}, target {_display(fields, 'target')}, "
                    f"confidence {_display(fields, 'confidence')}")
        for name in ("claim", "support", "evidence", "prediction"):
            rows.append(f"  {name}: {_display(fields, name)}")
        decision = admissions.get(key)
        intake_admissions = [row for row in events if row[1] == "ReasonerAdmission" and row[2] == reference[1]]
        missing = (_missing(_fields(intake_admissions[0]), "decisions")
                   if intake_admissions and _value(_fields(intake_admissions[0]), "decisions") is None
                   else "unavailable (no retained admission for this proposal)")
        rows.append("  Admission: " + (_data_text(decision) if decision else missing))
        matching = [row for row in grades if key is not None and _value(_fields(row), "proposal-key") == key]
        rows.append("  Outcome grade: " + (_comparison(_fields(matching[0])) if matching
                    else "unavailable (no assessment retained for this proposal); ungraded"))
    for grade in grades:
        if _value(_fields(grade), "proposal-key") not in displayed:
            rows.append(f"Outcome grade {_data_text(grade[2])}: {_comparison(_fields(grade))}")
    if proposals:
        rows.append("Proposal admission alone does not establish selection influence.")
    if not rows:
        return ["unavailable (no retained reasoner collection or assessment)"]
    return rows


# Example: queued edits remain Pending until an observed final batch status is retained.
def _parameter_rows(events):
    latest = {}
    for event in events:
        if event[1] == "ParameterUpdate":
            latest.setdefault(_data_text(event[2][1]), event)
    if not latest:
        return ["unavailable (no parameter-update batch retained)"]
    rows = []
    for identity, event in latest.items():
        fields = _fields(event)
        status = _value(fields, "status")
        rows.append(f"Batch {identity}: {status}; queued at {_display(fields, 'queued-at')}")
        if status == "Pending":
            rows.append("Application pending; registry changes are not yet observed")
        else:
            rows.append(f"Status recorded at {_display(fields, 'status-at')}; learner {_display(fields, 'learner')}")
        changes = _value(fields, "changes")
        if changes is None:
            rows.append("Changes: " + _missing(fields, "changes"))
        else:
            label = "Applied" if status == "Applied" else "Proposed"
            rows.extend(f"  {label} change {_data_text(row[1])}: {row[2]:.6g} -> {row[3]:.6g}" for row in changes)
    return rows


# Example: cap a whole flush, including multiple correlated cycle summaries.
def limit_output(text, max_chars=12000):
    max_chars = int(max_chars)
    marker = f"\n[trace output truncated at {max_chars} characters]"
    return text if len(text) <= max_chars else text[:max_chars - len(marker)] + marker


# Example: return an integer flag across the MeTTa/Python boundary without truth coercion.
def is_empty(text):
    return int(not text)


# Example: records queued inside locks are rendered only at a later safe boundary.
def render_pending(history, pending, max_chars=12000):
    keys = [(row[1], row[2]) for row in pending]
    texts = []
    for cycle in (row for row in history if row[1] == "CycleSelection"):
        related = _related_events(cycle, history)
        if (cycle[1], cycle[2]) in keys or any((row[1], row[2]) in keys for row in related):
            texts.append(format_cycle(cycle, history))
            if sum(map(len, texts)) >= max_chars:
                break
    return limit_output("\n\n".join(texts), max_chars)


# Example: later evidence enriches the view without editing its original selection record.
def format_cycle(event, history=()):
    heading = "=== MetaMo cycle summary (selection) ==="
    if not event or event[0] != "MetaMoTraceEvent" or event[1] != "CycleSelection":
        return heading + "\nCycle: unavailable (no retained cycle selection)"
    fields = {row[1]: row[2] for row in event[4]}
    events = _related_events(event, history)
    signals, contributions = (_value(fields, name) for name in ("signal-values", "contributions"))
    signal_rows = ([_missing(fields, "signal-values")] if signals is None else
                   [f"{row[1]}: {_fact(row[2])}" for row in signals])
    contribution_rows = ([_missing(fields, "contributions")] if contributions is None else
                         [f"{row[1]} -> {row[2]}: {(row[3] or 0):+.6g}" for row in contributions])
    text = "\n".join((heading, _identity(event[2]),
        _section("Modes", _mode_rows(fields)),
        _section("Admission and scheduling", _candidate_rows(fields)),
        _section("Selection and scores", _selection_rows(fields)),
        _section("Host dispatch observations", _dispatch_rows(fields, events)),
        _section("Budget settlement effects", _budget_rows(events)),
        _section("Reasoner proposals, predictions and grades", _reasoner_rows(events)),
        _section("Parameter updates", _parameter_rows(events)),
        _section("Factual signals", signal_rows),
        _section("Appraisal contributions (before dimension clamping)", contribution_rows),
        _section("Motivational state changes", _state_changes(fields))))
    marker = "\n[cycle summary truncated at 12000 characters]"
    return text if len(text) <= 12000 else text[:12000 - len(marker)] + marker

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


# Example: format_cycle(retained_selection) produces text without changing the supplied tree.
def format_cycle(event):
    heading = "=== MetaMo cycle summary (selection) ==="
    if not event or event[0] != "MetaMoTraceEvent" or event[1] != "CycleSelection":
        return heading + "\nCycle: unavailable (no retained cycle selection)"
    fields = {row[1]: row[2] for row in event[4]}
    signals, contributions = (_value(fields, name) for name in ("signal-values", "contributions"))
    signal_rows = ([_missing(fields, "signal-values")] if signals is None else
                   [f"{row[1]}: {_fact(row[2])}" for row in signals])
    contribution_rows = ([_missing(fields, "contributions")] if contributions is None else
                         [f"{row[1]} -> {row[2]}: {(row[3] or 0):+.6g}" for row in contributions])
    text = "\n".join((heading, _identity(event[2]),
        _section("Modes", _mode_rows(fields)),
        _section("Admission and scheduling", _candidate_rows(fields)),
        _section("Selection and scores", _selection_rows(fields)),
        _section("Factual signals", signal_rows),
        _section("Appraisal contributions (before dimension clamping)", contribution_rows),
        _section("Motivational state changes", _state_changes(fields))))
    marker = "\n[cycle summary truncated at 12000 characters]"
    return text if len(text) <= 12000 else text[:12000 - len(marker)] + marker

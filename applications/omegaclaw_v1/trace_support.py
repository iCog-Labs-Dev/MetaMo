"""Pure bounds, summaries and readable rendering of retained diagnostic records."""
import hashlib


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
        _section("Factual signals", signal_rows),
        _section("Appraisal contributions (before dimension clamping)", contribution_rows),
        _section("Motivational state changes", _state_changes(fields))))
    marker = "\n[cycle summary truncated at 12000 characters]"
    return text if len(text) <= 12000 else text[:12000 - len(marker)] + marker

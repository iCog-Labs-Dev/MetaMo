"""Pure size checks and bounded summaries for volatile diagnostic records."""
import hashlib


def fits(text, limit=2048):
    """Example: fits('(signal ready)', 32) returns 1 without interpreting it."""
    return int(len(text) <= limit)


def summarize(text, limit=2048):
    """Example: summarize(large_record) retains a digest, length and bounded excerpt."""
    prefix = f"sha256:{hashlib.sha256(text.encode('utf-8')).hexdigest()} chars:{len(text)} "
    return prefix + text[:limit - len(prefix) - 3] + "..."

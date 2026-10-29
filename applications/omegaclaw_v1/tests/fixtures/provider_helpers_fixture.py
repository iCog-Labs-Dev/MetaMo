"""Patch only provider transport; exercise the production helper implementation."""
import lib_llm_ext


def reply(value):
    lib_llm_ext.callProvider = lambda *args, **kwargs: value
    return True


def numeric_anomaly(kind):
    """Supply real nonfinite host numbers to the factual shape boundary."""
    return float(kind)

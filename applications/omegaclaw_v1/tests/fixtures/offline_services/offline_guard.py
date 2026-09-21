"""Fail immediately if these offline test processes reach optional services."""
import importlib.abc
import socket
import sys


class OptionalServiceBlocker(importlib.abc.MetaPathFinder):
    def find_spec(self, fullname, path=None, target=None):
        if fullname.split(".")[0] in {"chromadb", "openai", "google", "sentence_transformers", "torch"}:
            raise ImportError("optional service forbidden in offline test: " + fullname)


def deny_network(*args, **kwargs):
    raise RuntimeError("network forbidden in offline test")


def install():
    sys.meta_path.insert(0, OptionalServiceBlocker())
    socket.create_connection = deny_network
    socket.socket.connect = deny_network
    return True


def optional_modules_absent():
    return int(not any(name.split(".")[0] in {"chromadb", "openai", "google", "sentence_transformers", "torch"}
                       for name in sys.modules))

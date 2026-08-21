import os, uuid
import redis

REDIS_URL = os.environ.get("REDIS_URL", "redis://localhost:6379/0")
redis_client = redis.Redis.from_url(REDIS_URL, decode_responses=True)

_UNLOCK_SCRIPT = """
if redis.call("get", KEYS[1]) == ARGV[1] then
    return redis.call("del", KEYS[1])
else
    return 0
end
"""

def acquire_lock(key: str, timeout: int = 15):
    """
    Acquire a Redis lock using an atomic set-if-not-exists operation.

    Returns a unique lock token if successful, otherwise returns None.
    """
        
    token = str(uuid.uuid4())
    return token if redis_client.set(key, token, nx=True, ex=timeout) else None

def release_lock(key: str, token: str | None):
    """
    Release a Redis lock only if the provided token owns the lock.

    Prevents accidental deletion of locks created by other workers.
    """
        
    if token:
        redis_client.eval(_UNLOCK_SCRIPT, 1, key, token)
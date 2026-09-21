# Bounded live-frame resurfacing

`resurfacing.metta` implements a pure MeTTa review policy and session-local
queue on PeTTa. The live bridge advances it once after each scheduling decision
and publishes `FRAME_REVIEW_HINTS` in the prompt. A hint is `(FrameReview id reason)`;
it is not an AttentionDirective, permission grant, execution retry, or frame switch.
Review can ask the host to reconsider a blocker; it cannot clear the blocker.

## Eligibility and ownership

The host adapter reads Core's typed, list-backed frame index. It does not parse
the compacted, first-20-reference display projection. The current frame's bundle
overrides its potentially stale index entry.

- `Blocked` frames receive a `Blocked` review reason.
- Noncurrent `Active`/`Focused` frames and `Suspended` frames receive `Deferred`:
  they remain live but are waiting for attention.
- A current `Active`/`Focused` frame receives `Deferred` when the selected
  candidate is `defer` or `none`. Other selected candidates remove it from this
  review queue; selection is not evidence of execution or task completion.
- `Completed`, `Failed`, `Archived`, and removed frames leave the queue on the
  next valid cycle. Core remains authoritative for these statuses. If failed
  work should remain live for recovery, the host must represent it accordingly.

Deferred is a local scheduling observation, not a new ContextFrames status.
The queue never writes frame/task status, commitments, budgets, or permissions.
Scheduling precedence and all existing admission/dispatch checks remain intact.
In particular, an inactive blocked frame still fails operational admission even
when it has a review hint. The existing live dispatcher still does not support
cross-frame execution; review hints do not add that support.

## Bounds and fairness

Registry configuration is `(FrameResurfacingPolicy 128 2 3)`:

| Value | Meaning |
| --- | --- |
| 128 | Maximum queued live frames (hard implementation ceiling 128). |
| 2 | Maximum review hints per scheduling cycle. |
| 3 | Initial delay and minimum interval between hints for one frame. |

Supply exactly one configuration row. Capacity, batch, and delay must be positive
integers; batch cannot exceed capacity, and delay cannot exceed 1000 cycles.
The host index scan additionally stops at 512 entries, including terminal history
and Core's empty sentinels. Oversized history requires host pruning or a future
paged host API; this implementation does not silently truncate it.

A frame first observed on cycle 1 becomes due on cycle 4. Waiting entries retain
their order and due cycle when observations repeat, reasons change, or the host
reorders its index. New arrivals join behind existing entries. At most the batch
limit of due entries are emitted; emitted entries move to the tail and receive
the cooldown. This is round-robin review, independent of action preemption.

For a continuously eligible frame in a valid queue, a conservative bound is
`delay + ceil(capacity / batch)` subsequent scheduling cycles until a hint,
including between repeated hints. With defaults this is 67 cycles. In a fixed
128-frame cohort first observed on cycle 1, all frames receive their first hint
by cycle 67 (two per cycle from cycle 4 through 67). Hints continue while a
blocker persists; there is no retry-count expiry that silently forgets live work.
This guarantees review publication, not action execution, blocker resolution,
LLM compliance, or wall-clock latency while the runtime is stopped.

Malformed/duplicate identities, invalid configuration, capacity overflow, and
scan overflow produce `ResurfacingRejected` with no partial hints. The previous
queue and cycle remain unchanged, and previous hints are replaced by the error.
The fairness bound applies to valid cycles; rejected input must be corrected by
the host. No unbounded history is retained. Startup resets this advisory memory;
it is not persisted and makes no cross-restart fairness guarantee.

## APIs and verification

- `frameResurfacingRows config index current-id status candidate` projects typed
  host input to `ResurfacingRows`, or returns an explicit rejection.
- `frameResurfacingStep config state rows` is the pure transition. Its result is
  `(ResurfacingResult (ResurfacingState cycle entries) hints)` or a rejection.
- `refreshFrameResurfacing bundle candidate` is the bridge's once-per-cycle hook.
- `lastFrameReviews` reads the latest bounded output; `resetFrameResurfacing`
  resets session-local state.

From the workspace root:

```sh
python3 MetaMo/scripts/run-omegaclaw.py MetaMo/applications/omegaclaw_v1/tests/resurfacing_test.metta
sh run.sh MetaMo/applications/omegaclaw_v1/tests/resurfacing_test.metta -s
python3 MetaMo/scripts/run-tests.py --root MetaMo/applications/omegaclaw_v1 --jobs 2
```

Tests cover initial delay, cooldown, recurring hints, removal/termination,
reordered observations, fresh arrivals, changed reasons, current-cache precedence,
defer/no-action behavior, malformed input, explicit overflow, and reset. A
67-cycle test covers the full 128-frame queue. A 10-cycle test combines actual
candidate admission and Recovery preemption with repeated review publication;
operational admission for blocked frames remains rejected. External services,
live channels, and actual cross-frame execution are not exercised.

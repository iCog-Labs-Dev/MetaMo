;; Native workspace invocation:
;; sh run.sh MetaMo/applications/omegaclaw_v1/tests/list_helpers_test.metta -s
;; Use real runtime accessors and condition evaluation, without the live host.
!(import! &self (library MetaMo applications/omegaclaw_v1/contexts/context_accessors))
!(import! &self (library MetaMo applications/omegaclaw_v1/candidate_selection))
!(import! &self (library MetaMo applications/omegaclaw_v1/contexts/context_relations))

(= (listTestBundle $open)
   (FrameStateBundle
      (root ()) (current ()) (index ()) (relations ())
      (runtime (FrameStateRuntime
         (new-message False) (message-present False) (message-summary "")
         (task-open $open) (task-execution-observed "")
         (active-task-summary "") (last-results-summary "")
         (error "") (wake-loops 0) (next-wake-at 0) (budget-state open-budget)))))

;; Empty conjunction/disjunction, and one-row termination.
!(test (allTrue (listTestBundle True) ()) True)
!(test (anyTrue (listTestBundle True) ()) False)
!(test (allTrue (listTestBundle True) ((CandidateCondition demo always unused 0))) True)
!(test (allTrue (listTestBundle False) ((CandidateCondition demo task-active unused 0))) False)
!(test (anyTrue (listTestBundle True) ((CandidateConditionAny demo task-active unused 0))) True)
!(test (anyTrue (listTestBundle False) ((CandidateConditionAny demo task-active unused 0))) False)

;; The bundle must survive recursive calls, including the last row.
!(test (allTrue (listTestBundle True)
   ((CandidateCondition demo always unused 0)
    (CandidateCondition demo task-active unused 0))) True)
!(test (allTrue (listTestBundle False)
   ((CandidateCondition demo always unused 0)
    (CandidateCondition demo task-active unused 0))) False)
!(test (anyTrue (listTestBundle True)
   ((CandidateConditionAny demo task-inactive unused 0)
    (CandidateConditionAny demo task-active unused 0))) True)
!(test (anyTrue (listTestBundle True)
   ((CandidateConditionAny demo task-inactive unused 0)
    (CandidateConditionAny demo task-inactive unused 0))) False)

;; A decisive first row must not attempt to evaluate the invalid later row.
!(test (allTrue (listTestBundle False)
   ((CandidateCondition demo task-active unused 0) invalid-tail)) False)
!(test (anyTrue (listTestBundle True)
   ((CandidateConditionAny demo task-active unused 0) invalid-tail)) True)

;; Taking fewer, exactly as many, or more elements than exist preserves order.
!(test (frameStateTake 4 ()) ())
!(test (frameStateTake 4 (a)) (a))
!(test (frameStateTake 4 (a b)) (a b))
!(test (frameStateTake 1 (a b c)) (a))
!(test (frameStateTake 2 (a b c)) (a b))
!(test (frameStateTake 3 (a b c)) (a b c))
!(test (frameStateTake 4 ((Item a) (Item b))) ((Item a) (Item b)))
!(test (frameStateTake 0 (a b)) ())
!(test (frameStateTake -1 (a b)) ())
!(test (frameStateTake 0 ()) ())
!(test (frameStateTake -1 ()) ())

;; Count every result, without deduplicating: an empty prefix must be one
;; successful value, not zero solutions or overlapping empty/count base cases.
!(test (size-atom (collapse (frameStateTake 4 ()))) 1)
!(test (size-atom (collapse (frameStateTake 0 ()))) 1)
!(test (size-atom (collapse (frameStateTake -1 ()))) 1)

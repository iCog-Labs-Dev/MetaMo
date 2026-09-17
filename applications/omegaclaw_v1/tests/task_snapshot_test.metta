;; Exercise the production host-bookkeeping/publication boundary offline.
!(import! &self "../../../../repos/OmegaClaw-Core/src/helper.py")
!(import! &self ../../../../repos/OmegaClaw-Core/src/context)
!(import! &self (library MetaMo applications/omegaclaw_v1/tests/fixtures/minimal_loop))
!(initMinimalLoopFixture)

;; A stale bundle says a new message arrived; the current host says it did not.
;; Current successful terminal execution must close the task in this snapshot,
;; even when stale motivational signals claim failure.
!(change-state! &new-msg-flag False)
!(change-state! &lastresults "response delivered")
!(change-state! &last-motivation-decision (decision respond execute execute 0.5))
!(addSignal failure 0.8)
!(bind! &completed-snapshot (new-state (prepareTaskStateForMetaMo)))
!(test (frameRuntimeTaskOpen (get-state &completed-snapshot)) False)
!(test (frameRuntimeActiveTask (get-state &completed-snapshot)) (cfv2-compact-limited "" 500))
!(test (frameRuntimeExecutionObserved (get-state &completed-snapshot)) (cfv2-compact-limited "" 1200))
!(test (idleAutonomyActiveForBundle (get-state &completed-snapshot)) True)
!(test (activeFrameBundle) (get-state &completed-snapshot))

;; A current failure must preserve the task despite stale success signals.
!(change-state! &task-open True)
!(change-state! &active-task "answer-user")
!(change-state! &error "delivery failed")
!(clearSignals)
!(addSignal verified-success 1.0)
!(bind! &failed-snapshot (new-state (prepareTaskStateForMetaMo)))
!(test (frameRuntimeTaskOpen (get-state &failed-snapshot)) True)
!(test (frameRuntimeActiveTask (get-state &failed-snapshot)) (cfv2-compact-limited "answer-user" 500))
!(test (idleAutonomyActiveForBundle (get-state &failed-snapshot)) False)

;; Successful nonterminal work stays open and includes the latest observations
;; immediately, independently of the contents of the old active bundle.
!(change-state! &error "")
!(change-state! &task-execution-observed "first execution")
!(change-state! &lastresults "second execution")
!(change-state! &last-motivation-decision (decision execute-skill execute execute 0.5))
!(bind! &continued-snapshot (new-state (prepareTaskStateForMetaMo)))
!(test (frameRuntimeTaskOpen (get-state &continued-snapshot)) True)
!(test (frameRuntimeExecutionObserved (get-state &continued-snapshot))
       (cfv2-compact-limited (py-call (helper.merge_observed_execution_commands "first execution" "second execution")) 1200))
!(test (prepareTaskStateForMetaMo) (get-state &continued-snapshot))

;; A newly ingested task cannot be closed by the previous response's result.
!(change-state! &new-msg-flag True)
!(change-state! &active-task "new request")
!(change-state! &last-motivation-decision (decision respond execute execute 0.5))
!(bind! &new-snapshot (new-state (prepareTaskStateForMetaMo)))
!(test (frameRuntimeTaskOpen (get-state &new-snapshot)) True)
!(test (frameRuntimeActiveTask (get-state &new-snapshot)) (cfv2-compact-limited "new request" 500))
!(test (frameRuntimeExecutionObserved (get-state &new-snapshot)) (cfv2-compact-limited "" 1200))
;; Later host mutations cannot retroactively change the published bundle.
!(change-state! &task-open False)
!(change-state! &active-task "")
!(test (frameRuntimeTaskOpen (activeFrameBundle)) True)
!(test (frameRuntimeActiveTask (activeFrameBundle)) (cfv2-compact-limited "new request" 500))

;; No observed result is not completion, regardless of stale success signals.
!(change-state! &new-msg-flag False)
!(change-state! &task-open True)
!(change-state! &lastresults "")
!(bind! &empty-snapshot (new-state (prepareTaskStateForMetaMo)))
!(test (frameRuntimeTaskOpen (get-state &empty-snapshot)) True)

;; Local motivational updates cannot close or rewrite authoritative host work
;; or replace the snapshot already published for this cycle.
!(change-state! &active-task "host-owned task")
!(change-state! &task-execution-observed "host-owned observation")
!(bind! &ownership-snapshot (new-state (prepareTaskStateForMetaMo)))
!(bind! &ownership-observation (new-state (get-state &task-execution-observed)))
!(replaceGoal progress 0.0)
!(replaceModulator urgency 1.0)
!(setConstitutionalMode Sleep)
!(test (get-state &task-open) True)
!(test (get-state &active-task) "host-owned task")
!(test (get-state &task-execution-observed) (get-state &ownership-observation))
!(test (== (activeFrameBundle) (get-state &ownership-snapshot)) True)

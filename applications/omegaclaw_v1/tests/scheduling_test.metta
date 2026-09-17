;; Real admission + preemption + scoring, without channels or provider calls.
!(import! &self (library MetaMo applications/omegaclaw_v1/composition))

(= (schedulingTestBundle $mode $budget)
   (FrameStateBundle
      (root (FrameStateRoot root frame-a (mode $mode) () ()))
      (current (FrameStateCurrent (id frame-a) (parent ()) UserDirective
         (status Active) (frame-mode $mode) (priority 1.0)
         (goal-summary task) (history-summary history) (deliverable-summary result)
         (results-summary "") (budget (ResourceBudget 10 10 units (status $budget)))
         (constraints ()) (certified-method ())))
      (index (active ()) (completed ())) (relations ()) (runtime ())))

(= (schedulingTestState)
   (motivation (0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1)
      (0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5)))
(= (schedulingTestAction $name $alignment)
   (action $name ($alignment $alignment $alignment $alignment $alignment
      $alignment $alignment $alignment $alignment $alignment $alignment)
      0.0 (0 0 0 0 0 0 0 0 0 0 0)))
(= (schedulingTestWinner $mode $budget $actions)
   (actionId (decisionAction (omegaclawDecideForBundle
      (schedulingTestBundle $mode $budget) (schedulingTestState) $actions))))

!(test (collapse (schedulingPriorityOrder))
   ((Threat-remediation Recovery Interactive Orienting Engaged Rumination Sleep)))
!(test (collapse (constitutionalModeSet)) ((Engaged Threat Rumination Sleep)))
!(test (schedulingPriorityPreempts Engaged Engaged) False)
!(test (schedulingPriorityPreempts Unknown Engaged) False)
!(test (schedulingPriorityPreempts Engaged Unknown) False)
!(test (schedulingPriorityRank Threat) 0)
!(test (schedulingPriorityRank Fast) 0)
!(test (schedulingPriorityRank Slow) 0)
!(test (constitutionalModeValid Recovery) False)
!(test (constitutionalModeValid Interactive) False)
!(test (constitutionalModeValid Orienting) False)
!(test (constitutionalModeValid Threat-remediation) False)

;; Existing signals elevate only applicable work, without changing a mode.
!(test (schedulingPriorityForCandidate () verify-frame-state) Orienting)
!(test (schedulingPriorityForCandidate ((signal danger 1)) verify-frame-state) Threat-remediation)
!(test (schedulingPriorityForCandidate ((signal user-angry 1)) defer) Threat-remediation)
!(test (schedulingPriorityForCandidate ((signal danger 1)) execute-skill) Engaged)
!(test (schedulingPriorityForCandidate () self-improve) Rumination)
!(test (schedulingPriorityForCandidate ((signal failure 1)) self-improve) Recovery)
!(test (schedulingPriorityForCandidate ((signal repeated-failure 1)) self-improve) Recovery)
!(test (schedulingPriorityForCandidate ((signal stalled-progress 1)) self-improve) Recovery)
!(test (scheduleAdmittedActions () ()) ())
!(test (scheduleAdmittedActions () ((action unknown poison poison ()))) ())

;; Preserve complete payloads/order for equal classes; score only survivors.
!(test (scheduleAdmittedActions ()
   ((schedulingTestAction learn 0.1) (schedulingTestAction self-improve 1.0)
    (schedulingTestAction execute-skill 0.9)))
   ((schedulingTestAction learn 0.1) (schedulingTestAction execute-skill 0.9)))
!(clearSignals)
!(setConstitutionalMode Engaged)
!(test (schedulingTestWinner Fast Open
   ((schedulingTestAction learn 0.1) (schedulingTestAction execute-skill 0.9))) execute-skill)
!(test (schedulingTestWinner Fast Open
   ((schedulingTestAction respond 0.0) (action execute-skill poison poison ()))) respond)
!(test (schedulingTestWinner Fast Open
   ((schedulingTestAction retrieve-memory 0.1) (schedulingTestAction search-knowledge 0.1))) retrieve-memory)
!(test (schedulingTestWinner Fast Open
   ((schedulingTestAction search-knowledge 0.1) (schedulingTestAction retrieve-memory 0.1))) search-knowledge)
!(test (schedulingTestWinner Fast Open ()) none)

;; A low-scoring higher class beats every lower class in either input order.
;; Only danger is present: self-improve remains Rumination, not Recovery.
!(addSignal danger 1)

;; Multiple triggers coexist: threat work beats recovery, which beats response.
!(addSignal repeated-failure 1)
!(addSignal user-waiting 1)
!(addSignal ambiguity 1)
!(test (schedulingTestWinner Fast Open
   ((schedulingTestAction respond 1.0) (schedulingTestAction self-improve 1.0)
    (schedulingTestAction verify-frame-state 0.0))) verify-frame-state)
;; Removing the threat releases recovery, then removing recovery releases response.
!(clearSignals)
!(addSignal repeated-failure 1)
!(test (schedulingTestWinner Fast Open
   ((schedulingTestAction respond 1.0) (schedulingTestAction self-improve 0.0))) self-improve)
!(clearSignals)
!(test (schedulingTestWinner Fast Open
   ((schedulingTestAction respond 0.0) (schedulingTestAction self-improve 1.0))) respond)

;; Fast/Slow do not change precedence. Constitutional posture is independent.
!(setConstitutionalMode Rumination)
!(test (schedulingTestWinner Slow Open
   ((schedulingTestAction execute-skill 1.0) (schedulingTestAction respond 0.0))) respond)
!(test (constitutionalMode) Rumination)
!(test (frameBundleRootMode (schedulingTestBundle Slow Open)) Slow)
!(test (frameBundleCurrentMode (schedulingTestBundle Slow Open)) Slow)
!(setConstitutionalMode Threat)
!(test (schedulingTestWinner Fast Open
   ((schedulingTestAction defer 1.0) (schedulingTestAction respond 0.0))) respond)
!(test (constitutionalMode) Threat)

;; Admission comes first: even threat/recovery cannot revive rejected work.
!(addSignal danger 1)
!(test (schedulingTestWinner Fast Exhausted
   ((action verify-frame-state poison poison ())
    (action repair-failure poison poison ()) (schedulingTestAction respond 0.0))) respond)
!(test (feasibilityGate (schedulingTestBundle Fast Exhausted) verify-frame-state)
   (GateDecision Rejected BudgetExhausted))
!(setConstitutionalMode Sleep)
!(test (schedulingTestWinner Fast Open
   ((action verify-frame-state poison poison ())
    (action repair-failure poison poison ()) (schedulingTestAction respond 0.0))) respond)
!(test (schedulingTestWinner Fast Open ((action verify-frame-state poison poison ()))) none)
!(test (constitutionalMode) Sleep)

;; The bound decision interface used by the bimonad follows the same order.
!(setConstitutionalMode Engaged)
!(setActiveFrameBundle (schedulingTestBundle Fast Open))
!(test (actionId (decisionAction (omegaclawDecideBound (schedulingTestState)
   ((schedulingTestAction respond 1.0) (schedulingTestAction verify-frame-state 0.0))))) verify-frame-state)
!(setActiveFrameBundle ())
!(clearSignals)
!(addSignal danger 1)

;; Threat-remediation > Recovery
!(test (schedulingPriorityPreempts Threat-remediation Recovery) True)
!(test (schedulingPriorityPreempts Recovery Threat-remediation) False)
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction verify-frame-state 0.0) (schedulingTestAction repair-failure 1.0)))) (verify-frame-state))
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction repair-failure 1.0) (schedulingTestAction verify-frame-state 0.0)))) (verify-frame-state))

;; Threat-remediation > Interactive
!(test (schedulingPriorityPreempts Threat-remediation Interactive) True)
!(test (schedulingPriorityPreempts Interactive Threat-remediation) False)
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction verify-frame-state 0.0) (schedulingTestAction respond 1.0)))) (verify-frame-state))
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction respond 1.0) (schedulingTestAction verify-frame-state 0.0)))) (verify-frame-state))

;; Threat-remediation > Orienting
!(test (schedulingPriorityPreempts Threat-remediation Orienting) True)
!(test (schedulingPriorityPreempts Orienting Threat-remediation) False)
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction verify-frame-state 0.0) (schedulingTestAction retrieve-memory 1.0)))) (verify-frame-state))
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction retrieve-memory 1.0) (schedulingTestAction verify-frame-state 0.0)))) (verify-frame-state))

;; Threat-remediation > Engaged
!(test (schedulingPriorityPreempts Threat-remediation Engaged) True)
!(test (schedulingPriorityPreempts Engaged Threat-remediation) False)
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction verify-frame-state 0.0) (schedulingTestAction execute-skill 1.0)))) (verify-frame-state))
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction execute-skill 1.0) (schedulingTestAction verify-frame-state 0.0)))) (verify-frame-state))

;; Threat-remediation > Rumination
!(test (schedulingPriorityPreempts Threat-remediation Rumination) True)
!(test (schedulingPriorityPreempts Rumination Threat-remediation) False)
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction verify-frame-state 0.0) (schedulingTestAction self-improve 1.0)))) (verify-frame-state))
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction self-improve 1.0) (schedulingTestAction verify-frame-state 0.0)))) (verify-frame-state))

;; Threat-remediation > Sleep
!(test (schedulingPriorityPreempts Threat-remediation Sleep) True)
!(test (schedulingPriorityPreempts Sleep Threat-remediation) False)
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction verify-frame-state 0.0) (schedulingTestAction none 1.0)))) (verify-frame-state))
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction none 1.0) (schedulingTestAction verify-frame-state 0.0)))) (verify-frame-state))

;; Recovery > Interactive
!(test (schedulingPriorityPreempts Recovery Interactive) True)
!(test (schedulingPriorityPreempts Interactive Recovery) False)
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction repair-failure 0.0) (schedulingTestAction respond 1.0)))) (repair-failure))
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction respond 1.0) (schedulingTestAction repair-failure 0.0)))) (repair-failure))

;; Recovery > Orienting
!(test (schedulingPriorityPreempts Recovery Orienting) True)
!(test (schedulingPriorityPreempts Orienting Recovery) False)
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction repair-failure 0.0) (schedulingTestAction retrieve-memory 1.0)))) (repair-failure))
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction retrieve-memory 1.0) (schedulingTestAction repair-failure 0.0)))) (repair-failure))

;; Recovery > Engaged
!(test (schedulingPriorityPreempts Recovery Engaged) True)
!(test (schedulingPriorityPreempts Engaged Recovery) False)
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction repair-failure 0.0) (schedulingTestAction execute-skill 1.0)))) (repair-failure))
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction execute-skill 1.0) (schedulingTestAction repair-failure 0.0)))) (repair-failure))

;; Recovery > Rumination
!(test (schedulingPriorityPreempts Recovery Rumination) True)
!(test (schedulingPriorityPreempts Rumination Recovery) False)
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction repair-failure 0.0) (schedulingTestAction self-improve 1.0)))) (repair-failure))
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction self-improve 1.0) (schedulingTestAction repair-failure 0.0)))) (repair-failure))

;; Recovery > Sleep
!(test (schedulingPriorityPreempts Recovery Sleep) True)
!(test (schedulingPriorityPreempts Sleep Recovery) False)
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction repair-failure 0.0) (schedulingTestAction none 1.0)))) (repair-failure))
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction none 1.0) (schedulingTestAction repair-failure 0.0)))) (repair-failure))

;; Interactive > Orienting
!(test (schedulingPriorityPreempts Interactive Orienting) True)
!(test (schedulingPriorityPreempts Orienting Interactive) False)
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction respond 0.0) (schedulingTestAction retrieve-memory 1.0)))) (respond))
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction retrieve-memory 1.0) (schedulingTestAction respond 0.0)))) (respond))

;; Interactive > Engaged
!(test (schedulingPriorityPreempts Interactive Engaged) True)
!(test (schedulingPriorityPreempts Engaged Interactive) False)
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction respond 0.0) (schedulingTestAction execute-skill 1.0)))) (respond))
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction execute-skill 1.0) (schedulingTestAction respond 0.0)))) (respond))

;; Interactive > Rumination
!(test (schedulingPriorityPreempts Interactive Rumination) True)
!(test (schedulingPriorityPreempts Rumination Interactive) False)
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction respond 0.0) (schedulingTestAction self-improve 1.0)))) (respond))
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction self-improve 1.0) (schedulingTestAction respond 0.0)))) (respond))

;; Interactive > Sleep
!(test (schedulingPriorityPreempts Interactive Sleep) True)
!(test (schedulingPriorityPreempts Sleep Interactive) False)
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction respond 0.0) (schedulingTestAction none 1.0)))) (respond))
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction none 1.0) (schedulingTestAction respond 0.0)))) (respond))

;; Orienting > Engaged
!(test (schedulingPriorityPreempts Orienting Engaged) True)
!(test (schedulingPriorityPreempts Engaged Orienting) False)
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction retrieve-memory 0.0) (schedulingTestAction execute-skill 1.0)))) (retrieve-memory))
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction execute-skill 1.0) (schedulingTestAction retrieve-memory 0.0)))) (retrieve-memory))

;; Orienting > Rumination
!(test (schedulingPriorityPreempts Orienting Rumination) True)
!(test (schedulingPriorityPreempts Rumination Orienting) False)
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction retrieve-memory 0.0) (schedulingTestAction self-improve 1.0)))) (retrieve-memory))
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction self-improve 1.0) (schedulingTestAction retrieve-memory 0.0)))) (retrieve-memory))

;; Orienting > Sleep
!(test (schedulingPriorityPreempts Orienting Sleep) True)
!(test (schedulingPriorityPreempts Sleep Orienting) False)
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction retrieve-memory 0.0) (schedulingTestAction none 1.0)))) (retrieve-memory))
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction none 1.0) (schedulingTestAction retrieve-memory 0.0)))) (retrieve-memory))

;; Engaged > Rumination
!(test (schedulingPriorityPreempts Engaged Rumination) True)
!(test (schedulingPriorityPreempts Rumination Engaged) False)
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction execute-skill 0.0) (schedulingTestAction self-improve 1.0)))) (execute-skill))
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction self-improve 1.0) (schedulingTestAction execute-skill 0.0)))) (execute-skill))

;; Engaged > Sleep
!(test (schedulingPriorityPreempts Engaged Sleep) True)
!(test (schedulingPriorityPreempts Sleep Engaged) False)
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction execute-skill 0.0) (schedulingTestAction none 1.0)))) (execute-skill))
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction none 1.0) (schedulingTestAction execute-skill 0.0)))) (execute-skill))

;; Rumination > Sleep
!(test (schedulingPriorityPreempts Rumination Sleep) True)
!(test (schedulingPriorityPreempts Sleep Rumination) False)
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction self-improve 0.0) (schedulingTestAction none 1.0)))) (self-improve))
!(test (collapse (schedulingTestWinner Fast Open ((schedulingTestAction none 1.0) (schedulingTestAction self-improve 0.0)))) (self-improve))

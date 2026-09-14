;; Reusable MetaMo integration entry point.


(= (namedContainerName ($tag $name $value))
    $name
)

(= (namedContainerValue ($tag $name $value))
    $value
)

;; subsystemState aliases
;; Example: (subsystemName  (subsystemState curiosity s)) -> curiosity
;; Example: (subsystemMotivation (subsystemState curiosity s)) -> s
(= (subsystemName      $s) (namedContainerName  $s))
(= (subsystemMotivation $s) (namedContainerValue $s))

;; namedAction aliase
;; Example: (namedActionValue (namedAction curiosity a)) -> a
(= (namedActionValue $n) (namedContainerValue $n))

;; namedMotivation aliases
;; Example: (namedMotivationValue (namedMotivation ethics s)) -> s
(= (namedMotivationValue $n) (namedContainerValue $n))

;; localTransition is a 3-field type (name, action, target) so it keeps its
;; own dedicated accessors.

;; Return the Symbol name from a localTransition.
;; Example: (localTransitionName (localTransition curiosity a s)) -> curiosity
(= (localTransitionName (localTransition $name $action $target))
    $name
)

;; Return the selected ActionType from a localTransition.
;; Example: (localTransitionAction (localTransition curiosity a s)) -> a
(= (localTransitionAction (localTransition $name $action $target))
    $action
)

;; Return the target MotivationalState from a localTransition.
;; Example: (localTransitionTarget (localTransition curiosity a s)) -> s
(= (localTransitionTarget (localTransition $name $action $target))
    $target
)

;; Extract the final consensus action selected for execution.
;; Example: (cycleFinalAction result)
(= (cycleFinalAction
        (metaMoCycleResult $finalAction $mergedCurrent $mergedTarget $nextStates $localActions $localTargets $peerSimulations))
    $finalAction
)

;; Extract the merged state before this cycle's transition.
;; Example: (cycleMergedCurrent result)
(= (cycleMergedCurrent
        (metaMoCycleResult $finalAction $mergedCurrent $mergedTarget $nextStates $localActions $localTargets $peerSimulations))
    $mergedCurrent
)

;; Extract the consensus target state after this cycle's transition.
;; Example: (cycleMergedTarget result)
(= (cycleMergedTarget
        (metaMoCycleResult $finalAction $mergedCurrent $mergedTarget $nextStates $localActions $localTargets $peerSimulations))
    $mergedTarget
)

;; Extract the next subsystem states for the caller to store.
;; Example: (cycleNextStates result)
(= (cycleNextStates
        (metaMoCycleResult $finalAction $mergedCurrent $mergedTarget $nextStates $localActions $localTargets $peerSimulations))
    $nextStates
)

;; Extract each subsystem's preferred action before consensus.
;; Example: (cycleLocalActions result)
(= (cycleLocalActions
        (metaMoCycleResult $finalAction $mergedCurrent $mergedTarget $nextStates $localActions $localTargets $peerSimulations))
    $localActions
)

;; Extract each subsystem's local target state before blending.
;; Example: (cycleLocalTargets result)
(= (cycleLocalTargets
        (metaMoCycleResult $finalAction $mergedCurrent $mergedTarget $nextStates $localActions $localTargets $peerSimulations))
    $localTargets
)

;; Extract optional translated peer-state views. Returns () when no translator
;; is supplied.
;; Example: (cyclePeerSimulations result)
(= (cyclePeerSimulations
        (metaMoCycleResult $finalAction $mergedCurrent $mergedTarget $nextStates $localActions $localTargets $peerSimulations))
    $peerSimulations
)

;; Build the standard MetaMo bimonad used by an application entry point.
;; This wires OpenPSI appraisal, MAGUS decision, boundary damping, safety
;; projection, contractivity checks, and safe-region checks.
;;
;; Example:
;;   (runMetaMoCycleDefault
;;       (defaultMetaMoBimonad)
;;       ((subsystemState curiosity stateA) (subsystemState ethics stateB))
;;       stimulus
;;       candidates
;;       (consensusPair curiosity ethics)
;;       ())
(= (defaultMetaMoBimonad)
    (metaMoPseudoBimonad
        (openPsiAppraisal)
        (magusDecision)
        applyHomeostaticDamping
        raiseBoundaryCaution
        projectToSafeRegion
        checkContractiveUpdateLaw
        isInSafeRegion
    )
)

;; Internal recursive worker for mergeSubsystemStates.
;; Merges the already-merged accumulator with each remaining subsystem state.
;;
;; Example:
;;   (mergeSubsystemStatesLoop stateA ((subsystemState ethics stateB)) 0.05)
(= (mergeSubsystemStatesLoop $merged $remaining $coherenceCorrection)
    (if (== $remaining ())
        $merged
        (let* (
            (($head $rest) (decons $remaining))
            ($nextMerged (parallelMerge $merged (subsystemMotivation $head) $coherenceCorrection))
        )
            (mergeSubsystemStatesLoop $nextMerged $rest $coherenceCorrection)
        )
    )
)

;; Merge all subsystem motivational states into one current state using
;; OpenPSI parallelMerge semantics.
;;
;; Example:
;;   (mergeSubsystemStates
;;       ((subsystemState curiosity stateA) (subsystemState ethics stateB))
;;       0.05)
(= (mergeSubsystemStates $states $coherenceCorrection)
    (let* (
        (($head $rest) (decons $states))
    )
        (mergeSubsystemStatesLoop (subsystemMotivation $head) $rest $coherenceCorrection)
    )
)

;; Find a subsystem state by Symbol name.
;; Example:
;;   (findSubsystemState ethics ((subsystemState curiosity stateA)
;;                               (subsystemState ethics stateB)))
(= (findSubsystemState $name $states)
    (let* (
        (($head $rest) (decons $states))
    )
        (if (== (subsystemName $head) $name)
            (subsystemMotivation $head)
            (findSubsystemState $name $rest)
        )
    )
)

;; Build a consensusPair from the first two subsystem entries.
;; Example:
;;   (firstTwoConsensusPair ((subsystemState curiosity stateA)
;;                           (subsystemState ethics stateB)))
;;   -> (consensusPair curiosity ethics)
(= (firstTwoConsensusPair $states)
    (let* (
        (($first $rest) (decons $states))
        (($second $_) (decons $rest))
    )
        (consensusPair (subsystemName $first) (subsystemName $second))
    )
)

;; Return an explicit consensus pair, or derive the first-two pair when () is
;; supplied.
;;
;; Example:
;;   (resolveConsensusPair states ()) -> first two subsystem names
;;   (resolveConsensusPair states (consensusPair ethics safety)) -> same pair
(= (resolveConsensusPair $states $consensusPairOrEmpty)
    (if (== $consensusPairOrEmpty ())
        (firstTwoConsensusPair $states)
        $consensusPairOrEmpty
    )
)

;; Run bimonad step independently for each subsystem and preserve each local
;; action and target state.
;;
;; Example:
;;   (computeLocalTransitions bimonad states stimulus candidates)
;;   -> ((localTransition curiosity actionA targetA) ...)
(= (computeLocalTransitions $bimonad $states $stimulus $candidates)
    (if (== $states ())
        ()
        (let* (
            (($head $rest) (decons $states))
            ($transition (step $bimonad (subsystemMotivation $head) $stimulus $candidates))
            ($entry (localTransition
                (subsystemName $head)
                (transitionAction $transition)
                (transitionState $transition)))
        )
            (cons-atom $entry (computeLocalTransitions $bimonad $rest $stimulus $candidates))
        )
    )
)

;; Find one localTransition by subsystem name.
;; Example: (findLocalTransition curiosity localTransitions)
(= (findLocalTransition $name $localTransitions)
    (let* (
        (($head $rest) (decons $localTransitions))
    )
        (if (== (localTransitionName $head) $name)
            $head
            (findLocalTransition $name $rest)
        )
    )
)

;; Find one namedAction from cycleLocalActions by subsystem name.
;; Symmetric to findLocalTransition.
;; Example: (findNamedAction curiosity localActions) -> (namedAction curiosity actionA);;
(= (findNamedAction $name $namedActions)
    (let* (
        (($head $rest) (decons-atom $namedActions))
        ($namedActionName (|-> ($n) (namedContainerName $n)))
    )
        (if (== ($namedActionName $head) $name)
            $head
            (findNamedAction $name $rest)
        )
    )
)

;; Find one namedMotivation from cyclePeerSimulations by subsystem name.
;; Symmetric to findNamedAction for the peer simulation output.
;; Example: (findNamedMotivation curiosity peerSims) -> (namedMotivation curiosity simState)
(= (findNamedMotivation $name $namedMotivations)
    (let* (
        (($head $rest) (decons-atom $namedMotivations))
        ($namedMotivationName (|-> ($n) (namedContainerName $n)))
    )
        (if (== ($namedMotivationName $head) $name)
            $head
            (findNamedMotivation $name $rest)
        )
    )
)

;; Convert internal localTransition entries to public namedAction entries.
;; Example:
;;   (localTransitionsToActions ((localTransition curiosity actionA targetA)))
;;   -> ((namedAction curiosity actionA))
(= (localTransitionsToActions $localTransitions)
    (if (== $localTransitions ())
        ()
        (let* (
            (($head $rest) (decons $localTransitions))
            ($entry (namedAction (localTransitionName $head) (localTransitionAction $head)))
        )
            (cons-atom $entry (localTransitionsToActions $rest))
        )
    )
)

;; Convert internal localTransition entries to public namedMotivation targets.
;; Example:
;;   (localTransitionsToTargets ((localTransition curiosity actionA targetA)))
;;   -> ((namedMotivation curiosity targetA))
(= (localTransitionsToTargets $localTransitions)
    (if (== $localTransitions ())
        ()
        (let* (
            (($head $rest) (decons $localTransitions))
            ($entry (namedMotivation (localTransitionName $head) (localTransitionTarget $head)))
        )
            (cons-atom $entry (localTransitionsToTargets $rest))
        )
    )
)

;; Choose the caller-visible next state for a subsystem.
;; When $blend is True, apply coherence-preserving blendStates. When False,
;; return the local target directly.
;;
;; Example:
;;   (cycleNextState current target True)
;;   (cycleNextState current target False) -> target
(= (cycleNextState $currentState $targetState $blend)
    (if (== $blend True)
        (blendStates $currentState $targetState 1.0 0.25 0.5)
        $targetState
    )
)

;; Build next subsystem states in the same order and names as the input states.
;;
;; Example:
;;   (computeNextStates
;;       ((subsystemState curiosity stateA))
;;       ((localTransition curiosity actionA targetA))
;;       False)
;;   -> ((subsystemState curiosity targetA))
(= (computeNextStates $states $localTransitions $blend)
    (if (== $states ())
        ()
        (let* (
            (($head $rest) (decons $states))
            ($name (subsystemName $head))
            ($currentState (subsystemMotivation $head))
            ($localTransition (findLocalTransition $name $localTransitions))
            ($targetState (localTransitionTarget $localTransition))
            ($nextState (cycleNextState $currentState $targetState $blend))
            ($entry (subsystemState $name $nextState))
        )
            (cons-atom $entry (computeNextStates $rest $localTransitions $blend))
        )
    )
)

;; Internal worker for computePeerSimulations when a translator is supplied.
;;
;; Example:
;;   (computePeerSimulationsWith states translator)
;;   -> ((namedMotivation curiosity translatedState) ...)
(= (computePeerSimulationsWith $states $translator)
    (if (== $states ())
        ()
        (let* (
            (($head $rest) (decons-atom $states))
            ($entry (namedMotivation
                (subsystemName $head)
                (simulatePeer $translator (subsystemMotivation $head))))
        )
            (cons-atom $entry (computePeerSimulationsWith $rest $translator))
        )
    )
)

;; Optionally translate subsystem states through a TranslationFunctor.
;; Returns () when $translatorOrEmpty is ().
;;
;; Example:
;;   (computePeerSimulations states ())
;;   (computePeerSimulations states (translationFunctor goalMatrix modMatrix))
(= (computePeerSimulations $states $translatorOrEmpty)
    (if (== $translatorOrEmpty ())
        ()
        (computePeerSimulationsWith $states $translatorOrEmpty)
    )
)

;; Compute the consensus transition for the cycle.
;; With one subsystem, the subsystem's local transition is used directly.
;; With two or more subsystems, the resolved consensus pair is passed to
;; consensusTransition.
;;
;; Example:
;;   (cycleConsensusTransition bimonad states localTransitions stimulus candidates
;;                             (consensusPair curiosity ethics) 0.05)
(= (cycleConsensusTransition
        $bimonad
        $states
        $localTransitions
        $stimulus
        $candidates
        $consensusPairOrEmpty
        $coherenceCorrection)
    (let* (
        (($head $rest) (decons $states))
    )
        (if (== $rest ())
            (let $onlyTransition (findLocalTransition (subsystemName $head) $localTransitions)
                (transitionResult
                    (localTransitionAction $onlyTransition)
                    (localTransitionTarget $onlyTransition))
            )
            (let* (
                ($pair (resolveConsensusPair $states $consensusPairOrEmpty))
                ($consensusPairLeft  (|-> ($p) (namedContainerName $p)))
                ($consensusPairRight (|-> ($p) (namedContainerValue $p)))
                ($leftState (findSubsystemState ($consensusPairLeft $pair) $states))
                ($rightState (findSubsystemState ($consensusPairRight $pair) $states))
            )
                (consensusTransition
                    $bimonad
                    $leftState
                    $rightState
                    $stimulus
                    $candidates
                    $coherenceCorrection)
            )
        )
    )
)

;; runMetaMoCycle
;;
;; Main reusable integration function. It performs one motivational cycle:
;;   1. merge current subsystem states
;;   2. run each subsystem through bimonad step
;;   3. select final consensus action and merged target
;;   4. compute next subsystem states
;;   5. optionally simulate peer views through a TranslationFunctor
;;
;; Arguments:
;;   $bimonad                - metaMoPseudoBimonad, usually defaultMetaMoBimonad
;;   $states                 - list of subsystemState entries
;;   $stimulus               - stimulus value
;;   $candidates             - list of action values
;;   $consensusPairOrEmpty   - consensusPair or ()
;;   $translatorOrEmpty      - translationFunctor or ()
;;   $blend                  - True to blend local targets, False to return them
;;   $coherenceCorrection    - numeric correction passed to parallelMerge
;;
;; Example:
;;   (runMetaMoCycle
;;       (defaultMetaMoBimonad)
;;       ((subsystemState curiosity stateA) (subsystemState ethics stateB))
;;       (stimulus (0.125 0.125 0.0 0.0))
;;       ((action inspect corrs risk deltaG) (action defer corrs2 risk2 deltaG2))
;;       (consensusPair curiosity ethics)
;;       ()
;;       True
;;       0.05)
;;
;; Accessing fields:
;;   (cycleFinalAction result)
;;   (cycleNextStates result)
(= (runMetaMoCycle
        $bimonad
        $states
        $stimulus
        $candidates
        $consensusPairOrEmpty
        $translatorOrEmpty
        $blend
        $coherenceCorrection)
    (let* (
        ($mergedCurrent (mergeSubsystemStates $states $coherenceCorrection))
        ($localTransitions (computeLocalTransitions $bimonad $states $stimulus $candidates))
        ($consensusTransition  (cycleConsensusTransition
            $bimonad
            $states
            $localTransitions
            $stimulus
            $candidates
            $consensusPairOrEmpty
            $coherenceCorrection))
        ($nextStates (computeNextStates $states $localTransitions $blend))
    )
        (metaMoCycleResult
            (transitionAction $consensusTransition)
            $mergedCurrent
            (transitionState $consensusTransition)
            $nextStates
            (localTransitionsToActions $localTransitions)
            (localTransitionsToTargets $localTransitions)
            (computePeerSimulations $states $translatorOrEmpty))
    )
)

;; runMetaMoCycleDefault
;;
;; Convenience wrapper for runMetaMoCycle using blend=True and the default
;; coherence correction of 0.05.
;;
;; Example:
;;   (cycleFinalAction
;;       (runMetaMoCycleDefault
;;           (defaultMetaMoBimonad)
;;           ((subsystemState curiosity stateA) (subsystemState ethics stateB))
;;           stimulus
;;           candidates
;;           ()
;;           ()))
(= (runMetaMoCycleDefault
        $bimonad
        $states
        $stimulus
        $candidates
        $consensusPairOrEmpty
        $translatorOrEmpty)
    (runMetaMoCycle
        $bimonad
        $states
        $stimulus
        $candidates
        $consensusPairOrEmpty
        $translatorOrEmpty
        True
        0.05)
)

;; Test fixtures for the integration point.
;; Example: (integrationIdentity state) -> state
(= (integrationIdentity $x)
    $x
)

;; Simple test appraisal that adds the first two stimulus values to the first
;; two modulators and leaves goals unchanged.
;;
;; Example:
;;   (integrationRichAppraise state (stimulus (0.125 0.125 0.0 0.0)))
(= (integrationRichAppraise $state (stimulus $stimValues))
    (let* (
        ($stim0 (index-atom $stimValues 0))
        ($stim1 (index-atom $stimValues 1))
    )
        (motivation
            (motivationGoals $state)
            (clipVector
                (vectorAdd (motivationModulators $state) ($stim0 $stim1 0.0 0.0 0.0 0.0))
                0.0
                1.0)
        )
    )
)

;; Constant test decision function. It always selects act1 and returns act1's
;; deltaG so local subsystem results are predictable.
;;
;; Example: (integrationConstantDecide state candidates)
(= (integrationConstantDecide $state $candidates)
    (decisionResult
        (action act1
            (0.25 0.25 0.0 0.0 0.0 0.0 0.0 0.0)
            0.25
            (0.125 0.125 0.0 0.0 0.0 0.0 0.0 0.0))
        (0.125 0.125 0.0 0.0 0.0 0.0 0.0 0.0))
)
;; Test scoring function used by consensusAction. Higher correlation sums win
;; when current goals are identical.
;;
;; Example: (integrationSimpleScore state candidate)
(= (integrationSimpleScore $state (action $actionId $goalCorrelations $riskEstimate $deltaG))
    (+ (sum $goalCorrelations) (sum (motivationGoals $state)))
)

;; Identity damping fixture used to keep test deltaG values unchanged.
;; Example: (integrationIdentityDamping state deltaG) -> deltaG
(= (integrationIdentityDamping $state $deltaG)
    $deltaG
)

;; Contractivity fixture that accepts all transitions in tests.
;; Example: (integrationAlwaysContractive bimonad state reference stimulus candidates) -> True
(= (integrationAlwaysContractive $bimonad $state $referenceState $stimulus $candidates)
    True
)

;; Safe-region fixture that accepts all states in tests.
;; Example: (integrationAlwaysSafe state) -> True
(= (integrationAlwaysSafe $state)
    True
)





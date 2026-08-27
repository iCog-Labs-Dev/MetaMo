(: LawCheckResult Type)
(: lawCheckResult (-> Symbol MotivationState MotivationState Number Number Bool LawCheckResult))

(: MetaMoDiagnostics Type)
(: metaMoDiagnostics (-> Symbol Number Number Bool Bool Bool Bool Number Number Number Number Number Number Number Number Bool Number Number MetaMoDiagnostics))

(: DiagnosedTransition Type)
(: diagnosedTransition (-> Expression MotivationState MetaMoDiagnostics DiagnosedTransition))

(: MetaMoDiagnosticsSummary Type)
(: metamoDiagnosticsSummary (-> Number Number Number Number Number Number Number MetaMoDiagnosticsSummary))

;; Return the law check error.
;; Example: (lawCheckError (lawCheckResult lax left right 0.1 0.2 True)) -> 0.1
(= (lawCheckError (lawCheckResult $principle $leftState $rightState $error $tolerance $holds))
    $error
)

;; Return whether the law check holds.
;; Example: (lawCheckHolds (lawCheckResult lax left right 0.1 0.2 True)) -> True
(= (lawCheckHolds (lawCheckResult $principle $leftState $rightState $error $tolerance $holds))
    $holds
)

;; Return the law check tolerance.
;; Example: (lawCheckTolerance (lawCheckResult lax left right 0.1 0.2 True)) -> 0.2
(= (lawCheckTolerance (lawCheckResult $principle $leftState $rightState $error $tolerance $holds))
    $tolerance
)

;; Return the diagnosed action.
;; Example: (diagnosedAction (diagnosedTransition action state diag)) -> action
(= (diagnosedAction (diagnosedTransition $action $state $diagnostics))
    $action
)

;; Return the diagnosed next state.
;; Example: (diagnosedState (diagnosedTransition action state diag)) -> state
(= (diagnosedState (diagnosedTransition $action $state $diagnostics))
    $state
)

;; Return the diagnostics record.
;; Example: (diagnosedDiagnostics (diagnosedTransition action state diag)) -> diag
(= (diagnosedDiagnostics (diagnosedTransition $action $state $diagnostics))
    $diagnostics
)

;; Return diagnostics action id.
;; Example: (diagnosticsActionId diag) -> answer
(= (diagnosticsActionId (metaMoDiagnostics $actionId $laxError $laxTolerance $laxHolds $contractiveHolds $targetSafe $finalSafe $pressureBefore $pressureTarget $pressureFinal $projectionDelta $targetDistance $stateDrift $selfDrift $combinedDrift $selfDriftHolds $blendAlpha $baseBlendAlpha))
    $actionId
)

;; Return diagnostics projection delta.
;; Example: (diagnosticsProjectionDelta diag) -> 0.0
(= (diagnosticsProjectionDelta (metaMoDiagnostics $actionId $laxError $laxTolerance $laxHolds $contractiveHolds $targetSafe $finalSafe $pressureBefore $pressureTarget $pressureFinal $projectionDelta $targetDistance $stateDrift $selfDrift $combinedDrift $selfDriftHolds $blendAlpha $baseBlendAlpha))
    $projectionDelta
)

;; Return diagnostics final safe-region flag.
;; Example: (diagnosticsFinalInSafeRegion diag) -> True
(= (diagnosticsFinalInSafeRegion (metaMoDiagnostics $actionId $laxError $laxTolerance $laxHolds $contractiveHolds $targetSafe $finalSafe $pressureBefore $pressureTarget $pressureFinal $projectionDelta $targetDistance $stateDrift $selfDrift $combinedDrift $selfDriftHolds $blendAlpha $baseBlendAlpha))
    $finalSafe
)

;; Return a zero diagnostics summary.
;; Example: (emptyDiagnosticsSummary) -> empty summary
(= (emptyDiagnosticsSummary)
    (metamoDiagnosticsSummary 0 0.0 0.0 0.0 0.0 0.0 0.0)
)

;; Count diagnostics in a list.
;; Example: (diagnosticsCount (diag1 diag2)) -> 2
(= (diagnosticsCount $items)
    (size-atom $items)
)

;; Summarize diagnostics in a compact record.
;; Example: (diagnosticsSummary ()) -> (emptyDiagnosticsSummary)
(= (diagnosticsSummary $items)
    (if (== $items ())
        (emptyDiagnosticsSummary)
        (metamoDiagnosticsSummary (diagnosticsCount $items) 0.0 0.0 0.0 0.0 0.0 0.0)
    )
)


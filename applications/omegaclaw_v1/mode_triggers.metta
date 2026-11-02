;; Pure typed views of published observations and the current snapshot.
;; Trigger groups do not write signals, weight appraisal, or grant execution.

;; Example: failure True matches IsTrue; a False/absent/malformed fact does not.
(= (modeFactMatches $kind $predicate $signals)
    (and (== $predicate IsTrue) (signalTrueIn $signals $kind)))

;; Example: Enter uses 0.8, Exit uses 0.4; both boundaries are inclusive.
(= (modeRatioThreshold $phase $enter $exit)
    (if (== $phase Exit) $exit $enter))

;; Example: wrong units or invalid entry/exit thresholds cannot promote work.
(= (modeRatioMatches $kind $unit $enter $exit $phase $signals)
    (and (fsContains (Enter Exit) $phase)
        (and (and (fsNumberIn $enter 0 1) (fsNumberIn $exit 0 1))
            (signalRatioAtLeastIn $signals $kind $unit
                (modeRatioThreshold $phase $enter $exit)))))

;; Example: one shared typed predicate supplies mode and scheduling decisions.
(= (modeTriggerMatches $row $phase $signals)
    (case $row (
        ((ModeFactTrigger $_ $kind $predicate) (modeFactMatches $kind $predicate $signals))
        ((ModeRatioTrigger $_ $kind $unit $enter $exit)
            (modeRatioMatches $kind $unit $enter $exit $phase $signals))
        ($_ False))))

;; Example: recovery has fact rules; threat has unit-aware classifier rules.
(= (modeSignalRules $group)
    (let* (
        ($facts (collapse (match &self (ModeFactTrigger $group $kind $predicate)
            (ModeFactTrigger $group $kind $predicate))))
        ($ratios (collapse (match &self (ModeRatioTrigger $group $kind $unit $enter $exit)
            (ModeRatioTrigger $group $kind $unit $enter $exit))))
    ) (union-atom $facts $ratios)))

;; Example: a group is active if any declared typed trigger matches.
(= (modeSignalGroupActive $group $phase $signals)
    (!= (filter-atom (modeSignalRules $group) $row
        (modeTriggerMatches $row $phase $signals)) ()))

;; Example: the current frame can wake independently of observed signals.
(= (modeContextCondition $condition $hasFrame)
    (case $condition (
        (frame-present $hasFrame)
        (frame-absent (not $hasFrame))
        ($_ False))))

;; Example: no matching context rule leaves this portion of the group inactive.
(= (modeContextRowsActive $rows $hasFrame)
    (!= (filter-atom $rows $row
        (let (ModeContextTrigger $_ $condition) $row
            (modeContextCondition $condition $hasFrame))) ()))

;; Example: wake can match either a user-waiting fact or a current frame.
(= (modeTriggerGroupActive $group $phase $signals $hasFrame)
    (or (modeSignalGroupActive $group $phase $signals)
        (modeContextRowsActive
            (collapse (match &self (ModeContextTrigger $group $condition)
                (ModeContextTrigger $group $condition))) $hasFrame)))

;; Example: observed False differs from NoObservation in retained diagnostics.
(= (modeFactEvidence $kind $predicate $signals)
    (let* (
        ($value (signalValueIn $signals $kind))
        ($refs (signalProvenanceIn $signals $kind))
        ($matched (modeFactMatches $kind $predicate $signals))
    )
        (FactTriggerEvidence (kind $kind) (predicate $predicate)
            (observed $value) (provenance $refs) (matched $matched))))

;; Example: a ratio trace records its value, source, unit, phase and used threshold.
(= (modeRatioEvidence $kind $unit $enter $exit $phase $signals)
    (let* (
        ($threshold (modeRatioThreshold $phase $enter $exit))
        ($value (signalValueIn $signals $kind))
        ($refs (signalProvenanceIn $signals $kind))
        ($matched (modeRatioMatches $kind $unit $enter $exit $phase $signals))
    )
        (RatioTriggerEvidence (kind $kind) (predicate (AtLeast $unit $threshold))
            (phase $phase) (observed $value) (provenance $refs) (matched $matched))))

;; Example: evidence uses exactly the same predicate as group matching.
(= (modeSignalEvidence $row $phase $signals)
    (case $row (
        ((ModeFactTrigger $_ $kind $predicate) (modeFactEvidence $kind $predicate $signals))
        ((ModeRatioTrigger $_ $kind $unit $enter $exit)
            (modeRatioEvidence $kind $unit $enter $exit $phase $signals)))))

;; Example: retain losing rules and failed checks, including missing observations.
(= (modeTriggerEvidence $group $phase $signals $hasFrame)
    (let* (
        ($rows (modeSignalRules $group))
        ($contextRows (collapse (match &self (ModeContextTrigger $group $condition)
            (ModeContextTrigger $group $condition))))
        ($signalEvidence (map-atom $rows $row (modeSignalEvidence $row $phase $signals)))
        ($contextEvidence (map-atom $contextRows $row
            (let* (
                ((ModeContextTrigger $_ $condition) $row)
                ($matched (modeContextCondition $condition $hasFrame))
            ) (ContextTriggerEvidence $condition $matched))))
    ) (TriggerEvidence $signalEvidence $contextEvidence)))

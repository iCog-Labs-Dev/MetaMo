(: ParseResult Type)
(: parseOk (-> Expression ParseResult))
(: parseError (-> Symbol Expression ParseResult))

;; Return whether parse result succeeded.
;; Example: (parseIsOk (parseOk value)) -> True
(= (parseIsOk (parseOk $value))
    True
)

(= (parseIsOk (parseError $code $details))
    False
)

;; Return parsed value.
;; Example: (parseValue (parseOk value)) -> value
(= (parseValue (parseOk $value))
    $value
)

;; Validate perception fields after a JSON bridge has decoded an object to pairs.
;; Example: (researchAssistantParsePerceptionPairs pairs) -> parseOk perception
(= (researchAssistantParsePerceptionPairs $pairs)
    (let* (
        ($stimulusPairs (featurePairsGet $pairs stimulus ()))
        ($signalPairs (featurePairsGet $pairs signals ()))
        ($taskIntent (featurePairsGet $signalPairs task_intent unknown))
    )
        (if (researchAssistantValidTaskIntent $taskIntent)
            (parseOk
                (researchAssistantPerception
                    (makeResearchAssistantStimulus
                        (featurePairsGet $stimulusPairs novelty 0.0)
                        (featurePairsGet $stimulusPairs conduciveness 0.0)
                        (featurePairsGet $stimulusPairs risk 0.0)
                        (featurePairsGet $stimulusPairs effort 0.0)
                    )
                    (makeResearchAssistantSignals
                        $taskIntent
                        (featurePairsGet $signalPairs ambiguity 0.0)
                        (featurePairsGet $signalPairs citation_need 0.0)
                        (featurePairsGet $signalPairs comparison_need 0.0)
                        (featurePairsGet $signalPairs summary_need 0.0)
                        (featurePairsGet $signalPairs exploration_need 0.0)
                        (featurePairsGet $signalPairs unsafe_pressure 0.0)
                        (featurePairsGet $signalPairs privacy_pressure 0.0)
                        (featurePairsGet $signalPairs unsupported_claim_pressure 0.0)
                        (featurePairsGet $signalPairs context_loss_pressure 0.0)
                    )
                )
            )
            (parseError unknown-task-intent $taskIntent)
        )
    )
)


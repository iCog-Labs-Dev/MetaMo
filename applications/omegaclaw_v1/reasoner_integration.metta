;; Bounded NARS/PLN inference -> existing advisory proposal boundary.
;; Caller supplies Sentence facts from an admitted frame slice, with stable
;; evidence stamps. No raw history, frame mutation, or execution occurs here.
!(import! &self (library lib_import))
!(import_prolog_functions_from_file
   (library MetaMo applications/omegaclaw_v1/reasoner_engines.pl)
   (loadReasonerEngines))
!(loadReasonerEngines)
!(import! &self (library MetaMo applications/omegaclaw_v1/reasoner_proposals))

;; Explicit small MVP inference budget; callers can supply tighter limits.
(= (reasonerInferenceLimits) (InferenceLimits 8 10 40))
(= (reasonerQuery nars $facts $query (InferenceLimits $steps $tasks $beliefs))
   (MetaMoNARS.NARS.Query $facts $query $steps $tasks $beliefs))
(= (reasonerQuery pln $facts $query (InferenceLimits $steps $tasks $beliefs))
   (MetaMoPLN.PLN.Query $facts $query $steps $tasks $beliefs))

;; Query a registered candidate recommendation for this exact frame. Merely
;; asking the question does not supply the conclusion: inference must return
;; positive support. Preserve both truth components and the original stamps.
(= (reasonerInferProposal $engine $id $frame $facts $candidate $prediction $limits)
   (if (and (or (== $engine nars) (== $engine pln))
            (and (reasonerProposalCandidateValid $candidate)
                 (not (== $frame ()))))
       (let* (
          ($query (Recommend $frame $candidate))
          ($result (reasonerQuery $engine $facts $query $limits)))
          (reasonerInferenceResultToProposal
             $engine $id $frame $facts $query $candidate $prediction $result))
       ()))

(= (reasonerInferenceResultToProposal
      $engine $id $frame $facts $query $candidate $prediction ()) ())
(= (reasonerInferenceResultToProposal
      $engine $id $frame $facts $query $candidate $prediction
      ((stv $value $confidence) $evidence))
   ;; Positive recommendation only. Confidence does not establish polarity.
   (if (and (> $value 0.5)
            (and (<= $value 1.0)
                 (and (> $confidence 0.0)
                      (reasonerProposalConfidenceValid $confidence))))
       (let $proposal
          (case $engine (
             (nars (narsFactsToProposal $id $facts $query
                (InferenceTruth nars (stv $value $confidence))
                $confidence $evidence $candidate $prediction))
             (pln (plnFactsToProposal $id $facts $query
                (InferenceTruth pln (stv $value $confidence))
                $confidence $evidence $candidate $prediction))))
          (reasonerProposalForFrame $frame $proposal))
       ()))

(= (reasonerProposalForFrame $frame
      (ReasonerMotivationalProposal $id $source $kind $_target $candidate
         $claim $support $confidence $evidence $prediction))
   (ReasonerMotivationalProposal $id $source $kind (FrameTarget $frame)
      $candidate $claim $support $confidence $evidence $prediction))

;; Host can submit the returned proposal to reasonerProposalDecision or
;; reasonerProposalToSchedulerDirective. () means no supported proposal.

;; Convenience boundary for the host: infer, then use the existing auditable
;; scheduler-directive conversion. No conclusion produces no directive.
(= (reasonerInferDirective $engine $id $bundle $state $facts $candidate $prediction $limits)
   (let $proposal (reasonerInferProposal $engine $id
         (frameBundleCurrentId $bundle) $facts $candidate $prediction $limits)
      (if (== $proposal ()) ()
          (reasonerProposalToSchedulerDirective $bundle $state $proposal))))

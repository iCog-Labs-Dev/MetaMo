!(import! &self ../examples/feedback_diagnostics)

(= (feedbackDiagnosticPreferred $state)
   (let (($firstRule $firstScore) ($secondRule $secondScore))
        (feedbackDiagnosticScores $state)
        (if (> $firstScore $secondScore) $firstRule $secondRule)))

(= (feedbackDiagnosticInitial) (inferenceControlDefaultState))
(= (feedbackDiagnosticUpdated)
   (inferenceOutcomeState (feedbackDiagnosticFirst)))

!(test (inferenceProposalRule
         (inferenceExecutionProposal
           (inferenceOutcomeExecution (feedbackDiagnosticFirst))))
       induction)
!(test (feedbackDiagnosticPreferred (feedbackDiagnosticInitial)) abduction)
!(test (feedbackDiagnosticPreferred (feedbackDiagnosticUpdated)) deduction)
!(test (feedbackDiagnosticPreferred
         (feedbackDiagnosticState
           (feedbackDiagnosticUpdated) (feedbackDiagnosticInitial)))
       abduction)
!(test (feedbackDiagnosticPreferred
         (feedbackDiagnosticState
           (feedbackDiagnosticInitial) (feedbackDiagnosticUpdated)))
       deduction)
!(test (feedbackDiagnosticPreferred
         (feedbackDiagnosticOneModulator approach
           (feedbackDiagnosticInitial) (feedbackDiagnosticUpdated)))
       deduction)
!(test (feedbackDiagnosticPreferred
         (feedbackDiagnosticOneModulator approach
           (feedbackDiagnosticUpdated) (feedbackDiagnosticInitial)))
       abduction)
!(test (feedbackDiagnosticPreferred
         (feedbackDiagnosticOneModulator resolution
           (feedbackDiagnosticInitial) (feedbackDiagnosticUpdated)))
       abduction)
!(test (feedbackDiagnosticPreferred
         (feedbackDiagnosticOneModulator threshold
           (feedbackDiagnosticInitial) (feedbackDiagnosticUpdated)))
       abduction)
!(test (feedbackDiagnosticPreferred
         (feedbackDiagnosticOneModulator valence
           (feedbackDiagnosticInitial) (feedbackDiagnosticUpdated)))
       abduction)
!(test (> (stateModulator (feedbackDiagnosticUpdated) approach)
          (stateModulator (feedbackDiagnosticInitial) approach))
       True)


;; Full-loop boundary scenarios preserve the native host frame and commitment.
!(import! &self full_loop)
!(import! &self host_mode_fixture.py)
!(import_prolog_functions_from_file
   (library MetaMo applications/omegaclaw_v1/tests/fixtures/commitments.pl)
   (commitmentFixtureReset commitmentFixtureOpen commitmentFixtureOutcome commitmentFixtureApply))

(= (boundaryStart)
   (progn
      (commitmentFixtureReset)
      (initContextFrame)
      (fullLoopStartSession)
      (fullLoopIngest "Explain the project documentation")
      (commitmentFixtureOpen "boundary-task" (repr (get-state &cfv2-current-frame-id))
         "Explain the project documentation")
      (py-call (host_mode_fixture.setup))))

(= (boundaryProvision $variant)
   (py-call (host_mode_fixture.provision_variant (get-state &cfv2-current-frame-id) $variant)))

(= (boundaryCycle $label)
   (let $results (collapse (fullLoopCycle $label))
      (size-atom $results)))

(= (boundaryCallback $label $outcome)
   (let $result (ingestOperationOutcome $outcome)
      (progn (println! (FullLoopCallback $label $outcome $result)) $result)))

(= (boundaryObservationState)
   ((get-state &last-operation-outcome) (get-state &applied-operation-decision)
    (get-state &operation-failure-streak) (get-state &operation-feedback)
    (get-state &host-recovery) (motivosToMetamoState) (getSelfModel)))

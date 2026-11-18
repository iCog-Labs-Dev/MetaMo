;; Host maintenance projection and eligibility; no engine or handler loads here.
(: MaintenanceStatusType Type)
(: MaintenanceStatus (-> Symbol Symbol Symbol Number Expression MaintenanceStatusType))
(: MaintenanceCompletedType Type)
(: MaintenanceCompleted (-> Symbol String Number Expression MaintenanceCompletedType))
(: MemoryRentChargeType Type)
(: MemoryRentCharge (-> String Number MemoryRentChargeType))
(: MemoryRentAccountedType Type)
(: MemoryRentAccounted (-> Number MemoryRentAccountedType))
(: MaintenanceQueueResultType Type)
(: MaintenanceQueued (-> String MaintenanceQueueResultType))
(: MaintenanceDuplicate (-> String MaintenanceQueueResultType))
(: MaintenanceRejected (-> Symbol MaintenanceQueueResultType))
(: SessionMaintenanceOwnerType Type)
(: SessionMaintenanceOwner (-> String Symbol SessionMaintenanceOwnerType))
(: IdleMaintenanceConfigType Type)
(: IdleMaintenanceConfig (-> Expression Expression Expression IdleMaintenanceConfigType))
!(bind! &maintenance-view-hook (new-state ()))

;; Idle execution needs a managed publication for this exact session and no current frame.
;; Example: a fresh message makes idle maintenance ineligible before a frame is created.
(= (sessionMaintenanceBundleValid $bundle $session)
   (case $bundle (
      ((FrameStateBundle (root (FrameStateRoot $_ (current-frame-id ()) (mode $mode) $_ $_))
          (current (FrameStateCurrent $id (parent $_) $_ $_ $_ $_ $_ $_ $_ $_ $_ $_ $_))
          $_ (relations $_) (runtime $_))
       (tpAllTrue ((== $id ()) (tpContains (Fast Slow) $mode) (not (frameRuntimeNewMessage $bundle))
          (case (frameRuntimeSignalObservations $bundle) (
             ((SignalObservationView (SessionObservationRef $session $_) $_ $_) True) ($_ False))))))
      ($_ False))))

;; This exception authorizes only local rent accounting under explicit session policy.
;; Example: ordinary task commands retain the existing active-frame admission path.
(= (sessionMaintenanceAdmission $origin $target $request $operation $global $scope)
   (case ($request $operation) (
      (((AdmissionRequest propose-candidate current-frame defer)
         (PolicyOperation (candidate defer) (target (SessionTarget $session))
            (skill "host-maintenance") (permissions ("maintenance.memory-rent"))
            (egress ()) (costs ((ResourceCost "commands" "units" 1)))))
       (if (tpAllTrue ((== $origin $target) (== (constitutionalMode) Sleep)
               (sessionMaintenanceBundleValid $target $session)))
          (typedOperationPolicyGate $global $scope $operation defer (SessionTarget $session))
          (GateDecision Rejected SessionMaintenanceUnavailable)))
      ($_ (GateDecision Rejected InvalidSessionMaintenance)))))

;; Distinguish internal accounting from an observed result of the user's task.
;; Example: successful rent accounting does not establish task progress or recovery.
(= (isMaintenanceCommand $command)
   (if (and (== (get-metatype $command) Expression) (!= $command ()))
      (== (car-atom $command) host-maintenance) False))

;; Publish bounded availability/counts through the ordinary host snapshot.
;; Example: pure composition has no configured maintenance and returns ().
(= (hostMaintenanceProjection)
   (case (get-state &maintenance-view-hook) (
      (() ())
      ($hook (case (catch (eval ($hook))) (
         ((Error $_ $_) ()) ($rows $rows)))))))

;; Read only the supplied snapshot; never inspect a live work queue in motivation.
;; Example: a previous bundle keeps its previous pending count.
(= (maintenanceStatuses $bundle)
   (frameRuntimeField $bundle maintenance-work ()))

;; One existing candidate per work class; exact operations remain host bindings.
;; Example: several sweep jobs still produce at most one defer candidate.
(= (maintenanceCandidateRows $bundle $candidate)
   (filter-atom (maintenanceStatuses $bundle) $row (== (index-atom $row 2) $candidate)))

;; Count logical items as integers, including an empty class's explicit zero.
;; Example: unavailable handlers do not contribute their queued item counts.
(= (maintenanceReadyCount $rows)
   (if (== $rows ()) 0
      (+ (index-atom (car-atom $rows) 4) (maintenanceReadyCount (cdr-atom $rows)))))

;; Derive typed facts from this publication, independent of appraisal weights.
;; Example: engine absence contributes no ready items even when a job is queued.
(= (maintenanceClassFacts $bundle $candidate $availableKind $pendingKind)
   (let* (
      ($rows (maintenanceCandidateRows $bundle $candidate))
      ($available (filter-atom $rows $row (== (index-atom $row 3) True)))
      ($count (maintenanceReadyCount $available))
      ((SignalObservationView $snapshot $_ $_) (frameRuntimeSignalObservations $bundle))
   )
      ((FactualSignal (kind $availableKind) (value (BooleanFact (!= $available ()))) (provenance ($snapshot)))
       (FactualSignal (kind $pendingKind) (value (QuantityFact $count count)) (provenance ($snapshot))))))

;; No configured bindings means no extra facts in the native/default signal path.
;; Example: simply entering Sleep creates no pending-work observation.
(= (produceMaintenanceSignalFacts $bundle)
   (if (== (maintenanceStatuses $bundle) ()) ()
      (append
         (maintenanceClassFacts $bundle defer sweep-handler-available sweep-ready-items)
         (maintenanceClassFacts $bundle self-improve restructuring-handler-available restructuring-ready-items))))

;; Eligibility needs the same operation's available handler, pending work and class.
;; Example: a configured but unavailable replay worker cannot borrow another job's count.
(= (maintenanceCandidateReady $bundle $candidate)
   (let* (
      ($kind (case $candidate ((defer sweep-ready-items) (self-improve restructuring-ready-items) ($_ unknown))))
      ($facts (produceMaintenanceSignalFacts $bundle))
   )
      (and (signalQuantityAtLeastIn $facts $kind count 1)
         (!= (filter-atom (maintenanceCandidateRows $bundle $candidate) $row
            (tpAllTrue ((== (index-atom $row 3) True) (> (index-atom $row 4) 0)
               (maintenanceWorkFitsMode (index-atom $row 1) (constitutionalMode))))) ()))))

;; The frame-less selector remains closed except for this managed host sweep.
;; Example: a bare empty-frame bundle cannot enable selection of arbitrary task work.
(= (sessionMaintenanceCandidateReady $bundle $candidate)
   (case (frameRuntimeSignalObservations $bundle) (
      ((SignalObservationView (SessionObservationRef $session $_) $_ $_)
       (tpAllTrue ((== $candidate defer) (sessionMaintenanceBundleValid $bundle $session)
          (maintenanceCandidateReady $bundle $candidate))))
      ($_ False))))

;; The dispatcher owns invocation and its receipt; this wrapper is not a model skill.
;; Example: a captured memory-rent command processes only its admitted bounded batch.
(= (host-maintenance $operation)
   (eval (hostMaintenanceRun (quote $operation))))

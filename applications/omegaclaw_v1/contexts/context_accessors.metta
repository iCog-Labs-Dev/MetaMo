;; Named accessors for bounded FrameStateBundle and FrameStateRuntime values.
;;
;; These predicates are the read-only API consumed by MetaMo modules. They do
;; not reach through the bundle into ContextFrames state.

;; Named accessors keep MetaMo modules from reaching through the bundle into
;; ContextFrames state directly.
(= (frameBundleRoot $bundle)
   (let (FrameStateBundle (root $root) $_ $_ $_ $_) $bundle $root))
(= (frameBundleCurrent $bundle)
   (let (FrameStateBundle $_ (current $current) $_ $_ $_) $bundle $current))
(= (frameBundleIndex $bundle)
   (let (FrameStateBundle $_ $_ (index $active $completed) $_ $_)
         $bundle
      (index $active $completed)))
(= (frameBundleRelations $bundle)
   (let (FrameStateBundle $_ $_ $_ (relations $relations) $_) $bundle $relations))
(= (frameBundleRuntime $bundle)
   (let (FrameStateBundle $_ $_ $_ $_ (runtime $runtime)) $bundle $runtime))

(= (frameBundleCurrentStatus $bundle)
   (let (FrameStateBundle $root (current (FrameStateCurrent
            (id $id) (parent $parent) $source (status $value)
            (frame-mode $mode) (priority $priority) $goal
            $history $deliverables $results $budget $constraints $method))
         $index $relations $runtime)
         $bundle $value))
(= (frameBundleCurrentMode $bundle)
   (let (FrameStateBundle $root (current (FrameStateCurrent
            (id $id) (parent $parent) $source $status (frame-mode $value)
            (priority $priority) $goal
            $history $deliverables $results $budget $constraints $method))
         $index $relations $runtime)
         $bundle $value))
(= (frameBundleCurrentPriority $bundle)
   (let (FrameStateBundle $root (current (FrameStateCurrent
            (id $id) (parent $parent) $source $status (frame-mode $mode)
            (priority $value) $goal
            $history $deliverables $results $budget $constraints $method))
         $index $relations $runtime)
         $bundle $value))
(= (frameBundleCurrentBudget $bundle)
   (let (FrameStateBundle $root (current (FrameStateCurrent
            (id $id) (parent $parent) $source $status (frame-mode $mode)
            (priority $priority) $goal
            $history $deliverables $results (budget $value) $constraints $method))
         $index $relations $runtime)
         $bundle $value))
(= (frameBundleCurrentHistory $bundle)
   (let (FrameStateBundle $root (current (FrameStateCurrent
            (id $id) (parent $parent) $source $status (frame-mode $mode)
            (priority $priority) $goal
            (history-summary $value) $deliverables $results $budget $constraints $method))
         $index $relations $runtime)
         $bundle $value))
(= (frameBundleRootMode $bundle)
   (let (FrameStateBundle (root (FrameStateRoot $id $currentFrame (mode $value)
            $globalBudget $globalConstraints)) $current $index $relations $runtime)
         $bundle $value))
(= (frameBundleCurrentId $bundle)
   (let (FrameStateBundle (root $root) (current (FrameStateCurrent
            (id $value) $parent $source $status $mode $priority $goal
            $history $deliverables $results $budget $constraints $method))
         $index $relations $runtime)
         $bundle $value))

;; Tagged lookup also accepts older offline bundles without operation feedback.
(= (frameRuntimeValue $runtime $key $default)
   (let $fields (filter-atom (cdr-atom $runtime) $field
                   (== (car-atom $field) $key))
      (if (== $fields ()) $default
          (car-atom (cdr-atom (car-atom $fields))))))

(= (frameRuntimeField $bundle $key $default)
   (frameRuntimeValue (frameBundleRuntime $bundle) $key $default))

(= (frameRuntimeNewMessage $bundle)
   (frameRuntimeField $bundle new-message False))
(= (frameRuntimeMessagePresent $bundle)
   (frameRuntimeField $bundle message-present False))
(= (frameRuntimeMessage $bundle)
   (frameRuntimeField $bundle message-summary ""))
(= (frameRuntimeTaskOpen $bundle)
   (frameRuntimeField $bundle task-open False))
(= (frameRuntimeActiveTask $bundle)
   (frameRuntimeField $bundle active-task-summary ""))
(= (frameRuntimeResults $bundle)
   (frameRuntimeField $bundle last-results-summary ""))
(= (frameRuntimeError $bundle)
   (frameRuntimeField $bundle error ""))
(= (frameRuntimeExecutionObserved $bundle)
   (frameRuntimeField $bundle task-execution-observed ""))
(= (frameRuntimeOperationFeedback $bundle)
   (frameRuntimeField $bundle operation-feedback LegacyFeedback))

(= (frameRuntimeText $value)
   ;; Example: `(frameRuntimeText ())` returns the safe empty string `""`,
   ;; while `(frameRuntimeText "result")` returns `"result"`.
   (if (== $value ()) "" $value))

;; Migration seam: keep raw OmegaClaw state reads in this adapter and expose
;; only derived, bounded values to MetaMo modules.
(= (bundle-runtime-has-error $bundle)
   (not (== (frameRuntimeError $bundle) "")))
(= (bundle-runtime-has-new-message $bundle)
   (frameRuntimeNewMessage $bundle))
(= (bundle-current-status $bundle)
   (frameBundleCurrentStatus $bundle))
(= (bundle-current-budget-state $bundle)
   (frameBundleCurrentBudget $bundle))
(= (bundle-current-priority $bundle)
   (frameBundleCurrentPriority $bundle))

(= (frameRuntimeContinuation $bundle)
   (frameRuntimeField $bundle task-continuation NoContinuation))

(= (frameRuntimeStatusQuestion $bundle)
   (frameRuntimeField $bundle result-status-question False))

(= (frameRuntimeRecovery $bundle)
   (frameRuntimeField $bundle recovery NoRecovery))

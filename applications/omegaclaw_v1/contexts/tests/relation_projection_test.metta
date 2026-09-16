;; Exact-output regression tests for relation projection and input normalization.
;; Uses the real Core reason compactor; no channel or external service is started.
!(import! &self (library lib_import))
!(import! &self (library OmegaClaw-Core src/helper.py))
!(import! &self (library OmegaClaw-Core src/context))
!(import! &self (library MetaMo applications/omegaclaw_v1/contexts/context_relations))

;; Collapse keeps all results: each accepted input must produce exactly one
;; fully evaluated record, with field order, endpoint direction, and values intact.
;; Python str converts literal expected text to the same host atom representation
;; as the bridge; it does not compute the expected digest, excerpt, or length.

!(test (collapse (frameStateProjectRelation (FrameRelation frame-a frame-b ContinuationOf same 0.7 Confirmed)))
   ((FrameStateRelation (source-frame frame-a) (target-frame frame-b)
      (relation-type ContinuationOf) (reason (py-call (str "sha256:0967115f2813a354 chars:4 excerpt:same")))
      (confidence 0.7) (evidence-status Confirmed))))

!(test (collapse (frameStateProjectRelation (Relation frame-a frame-b ContinuationOf same 0.7 Confirmed)))
   ((FrameStateRelation (source-frame frame-a) (target-frame frame-b)
      (relation-type ContinuationOf) (reason (py-call (str "sha256:0967115f2813a354 chars:4 excerpt:same")))
      (confidence 0.7) (evidence-status Confirmed))))

!(test (collapse (frameStateProjectRelation (Relation (FrameID-1 frame-a) (FrameID-2 frame-b) (Class ContinuationOf) (Reason same) (Confidence 0.7))))
   ((FrameStateRelation (source-frame frame-a) (target-frame frame-b)
      (relation-type ContinuationOf) (reason (py-call (str "sha256:0967115f2813a354 chars:4 excerpt:same")))
      (confidence 0.7) (evidence-status Unverified))))

;; These characterize the current overwrite, not a desired evidence policy.
;; Even resolved same-frame evidence is currently reset to VerificationRequired.

!(test (collapse (frameStateProjectRelation (FrameRelation frame-a frame-b SameFrame same 0.9 Unverified)))
   ((FrameStateRelation (source-frame frame-a) (target-frame frame-b)
      (relation-type SameFrame) (reason (py-call (str "sha256:0967115f2813a354 chars:4 excerpt:same")))
      (confidence 0.9) (evidence-status VerificationRequired))))

!(test (collapse (frameStateProjectRelation (FrameRelation frame-a frame-b SameFrame same 0.9 Confirmed)))
   ((FrameStateRelation (source-frame frame-a) (target-frame frame-b)
      (relation-type SameFrame) (reason (py-call (str "sha256:0967115f2813a354 chars:4 excerpt:same")))
      (confidence 0.9) (evidence-status VerificationRequired))))

!(test (collapse (frameStateProjectRelation (FrameRelation frame-a frame-b SameFrame same 0.9 Refuted)))
   ((FrameStateRelation (source-frame frame-a) (target-frame frame-b)
      (relation-type SameFrame) (reason (py-call (str "sha256:0967115f2813a354 chars:4 excerpt:same")))
      (confidence 0.9) (evidence-status VerificationRequired))))

!(test (collapse (frameStateProjectRelation (FrameRelation frame-a frame-b PossibleSameFrame same 0.9 Unverified)))
   ((FrameStateRelation (source-frame frame-a) (target-frame frame-b)
      (relation-type PossibleSameFrame) (reason (py-call (str "sha256:0967115f2813a354 chars:4 excerpt:same")))
      (confidence 0.9) (evidence-status VerificationRequired))))

!(test (collapse (frameStateProjectRelation (FrameRelation frame-a frame-b PossibleSameFrame same 0.9 Confirmed)))
   ((FrameStateRelation (source-frame frame-a) (target-frame frame-b)
      (relation-type PossibleSameFrame) (reason (py-call (str "sha256:0967115f2813a354 chars:4 excerpt:same")))
      (confidence 0.9) (evidence-status VerificationRequired))))

!(test (collapse (frameStateProjectRelation (FrameRelation frame-a frame-b PossibleSameFrame same 0.9 Refuted)))
   ((FrameStateRelation (source-frame frame-a) (target-frame frame-b)
      (relation-type PossibleSameFrame) (reason (py-call (str "sha256:0967115f2813a354 chars:4 excerpt:same")))
      (confidence 0.9) (evidence-status VerificationRequired))))

;; Other types preserve unresolved evidence and boundary confidence values.

!(test (collapse (frameStateProjectRelation (FrameRelation frame-a frame-b ContinuationOf same 0 Unresolved)))
   ((FrameStateRelation (source-frame frame-a) (target-frame frame-b)
      (relation-type ContinuationOf) (reason (py-call (str "sha256:0967115f2813a354 chars:4 excerpt:same")))
      (confidence 0) (evidence-status Unresolved))))

!(test (collapse (frameStateProjectRelation (Relation frame-a frame-b ContinuationOf same 1 Refuted)))
   ((FrameStateRelation (source-frame frame-a) (target-frame frame-b)
      (relation-type ContinuationOf) (reason (py-call (str "sha256:0967115f2813a354 chars:4 excerpt:same")))
      (confidence 1) (evidence-status Refuted))))

;; A 241-character reason becomes a 240-character excerpt (237 + ellipsis),
;; preceded by the digest and original length. Expected text is independent
;; of the production compactor; applying compaction twice would fail this test.

!(test (collapse (frameStateProjectRelation (Relation (FrameID-1 frame-a) (FrameID-2 frame-b) (Class ContinuationOf) (Reason xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx) (Confidence 0.7))))
   ((FrameStateRelation (source-frame frame-a) (target-frame frame-b)
      (relation-type ContinuationOf) (reason (py-call (str "sha256:7dbf05774ebc8b02 chars:241 excerpt:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx...")))
      (confidence 0.7) (evidence-status Unverified))))

;; Host-owned message routing. No permission, completion, or planning authority.
!(import! &self (library MetaMo applications/omegaclaw_v1/host_ingress.py))
!(bind! &last-host-input (new-state ()))
!(bind! &last-host-followup (new-state ()))
!(bind! &last-host-replacement (new-state ()))

;; Example: a blocked frame stays blocked even when the message says follow-up.
(= (hostIngressFrameDecision $id $frame $revision)
    (case (get-state &cfv2-current-status)
        (
            (Active (HostInput FollowUp $id $frame $revision))
            (Focused (HostInput FollowUp $id $frame $revision))
            ($_ (HostInput Held InactiveFrame))
        )
    )
)

;; Example: an explicit follow-up is accepted only for the focused open owner.
(= (hostIngressOpenDecision $kind $id $frame $revision)
    (case ($kind (== $frame (get-state &cfv2-current-frame-id)))
        (
            ((FollowUp True)
                (hostIngressFrameDecision $id $frame $revision))
            ((FollowUp False) (HostInput Held FrameMismatch))
            ((Cancel True) (HostInput Cancel $id $frame $revision))
            ((Cancel False) (HostInput Held FrameMismatch))
            ((Replace True) (HostInput Replace $id $frame $revision))
            ((Replace False) (HostInput Held FrameMismatch))
            ((Correction True) (HostInput Correction $id $frame $revision))
            ((Correction False) (HostInput Held FrameMismatch))
            ($_ (HostInput Held ExplicitFollowupRequired))
        )
    )
)

;; Example: unmarked input with no open commitment uses normal Core admission.
(= (hostIngressUnownedDecision $kind)
    (case $kind
        (
            (NewTask (HostInput NewTask))
            ($_ (HostInput Held MissingCommitment))
        )
    )
)

;; Example: ambiguous input returns Held without replacing the open commitment.
(= (hostIngressDecision $kind)
    (case ($kind (commitmentSnapshot))
        (
            ((InvalidInput $_) (HostInput Held InvalidInput))
            (($_ (CommitmentSnapshot $id $frame $revision Open $_))
                (hostIngressOpenDecision $kind $id $frame $revision))
            ($_ (hostIngressUnownedDecision $kind))
        )
    )
)

;; Example: replaying the same follow-up for the same owner appends no history.
(= (hostIngressFollowup $decision $message)
    (let $key (HostFollowup $decision $message)
        (if (== $key (get-state &last-host-followup))
            $decision
            (progn
                (py-call (host_ingress.mutate "FollowUp" $message))
                (change-state! &last-host-followup $key)
                $decision
            )
        )
    )
)

;; Example: retain a Held diagnostic while keeping case branch outputs separate.
(= (hostIngressRetain $decision) $decision)

;; Example: remember the successor identity, never treat a stale predecessor as current.
(= (hostIngressReplaceOnce $decision $message)
    (let*
        (
            ($source (repr $decision))
            ($result (sread (py-call (host_ingress.replace $source $message))))
        )
        (progn
            (change-state! &last-host-followup ())
            (case $result
                (
                    ((HostInput Replaced $_ $next $frame $revision)
                        (change-state! &last-host-replacement
                            (HostReplacement (HostInput Replace $next $frame $revision)
                                $message $result)))
                    ($_ False)
                )
            )
            $result
        )
    )
)

;; Example: redelivery against the successor returns the original replacement receipt.
(= (hostIngressReplacement $decision $message)
    (case (get-state &last-host-replacement)
        (
            ((HostReplacement $decision $message $receipt) $receipt)
            ($_ (hostIngressReplaceOnce $decision $message))
        )
    )
)

;; Example: Held has no frame effects; NewTask delegates to Core's admission.
(= (hostIngressApply $decision $message)
    (case $decision
        (
            ((HostInput FollowUp $_ $_ $_)
                (hostIngressFollowup $decision $message))
            ((HostInput Replace $_ $_ $_)
                (hostIngressReplacement $decision $message))
            ((HostInput Correction $_ $_ $_)
                (sread (py-call (host_ingress.correct (repr $decision) $message))))
            ((HostInput Cancel $_ $_ $_)
                (progn
                    (change-state! &last-host-followup ())
                    (let $source (repr $decision)
                        (sread (py-call (host_ingress.cancel $source $message)))
                    )
                ))
            ((HostInput NewTask)
                (progn
                    (py-call (host_ingress.mutate "NewTask" $message))
                    (change-state! &last-host-followup ())
                    (hostIngressRetain $decision)
                ))
            ($_
                (progn
                    (change-state! &last-host-followup ())
                    (hostIngressRetain $decision)
                ))
        )
    )
)

;; Example: the Core ingress callback retains its typed routing diagnostic.
(= (ingestHostMessage $message)
    (let $result (sread (py-call (host_ingress.ingest_transport $message (eval (commchannel)))))
        (progn
            (change-state! &last-host-input $result)
            $result
        )
    )
)

;; Example: held unrelated text is not fresh input to the current task's signals.
(= (hostInputIsFresh)
    (case (get-state &last-host-input)
        (
            ((HostInput Held $_) False)
            ((HostInput Cancelled $_ $_ $_) False)
            ((HostInput CorrectionRecorded $_) False)
            ($_ (get-state &core-loop-new-message))
        )
    )
)

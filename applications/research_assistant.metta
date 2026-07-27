!(import! &self ../core/helper)
!(import! &self "../core/helpers.py")
!(import! &self ../core/state)
!(import! &self ../core/state_accessors)
!(import! &self ../core/config)
!(import! &self ../openpsi/config)
!(import! &self ../category/functors)
!(import! &self ../category/bimonad)
!(import! &self ../openpsi/appraisal)
!(import! &self ../openpsi/appraisal_helpers)
!(import! &self ../magus/decision)
!(import! &self ../dynamics/stability)
!(import! &self ../dynamics/coherence)
!(import! &self ../llm/llm)
!(import! &self "io_bridge.py")
!(import! &self "../llm/metta_bridge.py")
!(import! &self ../main/main)


;; 1. Initialization Helpers
(= (createInitialState)
    (let* (
        ($gInd 0.5)
        ($gTrans 0.5)
        ($gHelp 0.8)
        ($gCurio 0.6)
        ($gNovel 0.4)
        ($gSelf 0.3)
        ($gEthic 0.9)
        ($gSoc 0.2)
        ($goals ($gInd $gTrans $gHelp $gCurio $gNovel $gSelf $gEthic $gSoc))
        ($modulators (0.5 0.5 0.5 0.5 0.5 0.5))
    )
        (motivation $goals $modulators)
    )
)

;; Build the identity TranslationFunctor for peer simulation.
;; Uses identity matrices so each subsystem's view of the other is unaltered.
;; Example: (createIdentityTranslator)
(= (createIdentityTranslator)
    (let* (
        ($goals 8)
        ($mods  6)
        ($gMat (py-call (helpers.identity_matrix $goals)))
        ($mMat (py-call (helpers.identity_matrix $mods)))
    )
        (translationFunctor $gMat $mMat)
    )
)

;; Round a float to 2 decimal places for display.
;; Example: (formatFloat 0.12345) -> 0.12
(= (formatFloat $val)
    (py-call (helpers.round_number $val 2))
)

;; 2. Interactive Loop

(= (processUserInput $bimonad $translator $states $userInput)
    (if (or (== $userInput quit) (== $userInput exit))
        False
        (let* (
            ($_ (py-call (io_bridge.print_output "\n[MetaMo Internal Processing...]")))

            ;; 1. Merge mood before the single perception/routing request
            ($mergedForMood (mergeSubsystemStates $states 0.05))
            ($arousal (getModulator $mergedForMood arousal))
            ($caution (getModulator $mergedForMood securing))

            ;; 2. One LLM request returns stimulus signals; candidate routing is local
            ($analysis (analyzeTurnFromText $userInput $arousal $caution))
            ($stimulus (index-atom $analysis 0))
            ($candidates (index-atom $analysis 1))

            ;; 3. MetaMo cycle
            ($result (runMetaMoCycleDefault
                $bimonad
                $states
                $stimulus
                $candidates
                ()
                $translator))

            ;; 4. Extract cycle outputs
            ($finalAction  (cycleFinalAction  $result))
            ($mergedTarget (cycleMergedTarget $result))
            ($nextStates   (cycleNextStates   $result))
            ($localActions (cycleLocalActions $result))
            ($peerSims     (cyclePeerSimulations $result))

            ;; 5. Diagnostics
            ($actionC (namedActionValue (findNamedAction curiosity $localActions)))
            ($actionE (namedActionValue (findNamedAction ethics    $localActions)))
            ($_ (py-call (io_bridge.print_output "  > [Curiosity Subsystem] wants to: " (actionId $actionC))))
            ($_ (py-call (io_bridge.print_output "  > [Ethics Subsystem] wants to: "    (actionId $actionE))))

            ;; Peer simulation log: Curiosity's predicted view of Ethics' caution
            ($simEthics (namedMotivationValue (findNamedMotivation ethics $peerSims)))
            ($simCaution (getModulator $simEthics securing))
            ($_ (py-call (io_bridge.print_output "  > [Reciprocal Simulation]: Curiosity predicts Ethics' caution is " (formatFloat $simCaution))))

            ;; 6. Response execution 
            ($gInd   (getGoal $mergedTarget gInd))
            ($gTrans (getGoal $mergedTarget gTrans))
            ($response (llmGenerateFinalResponse $userInput (actionId $finalAction) $gInd $gTrans))

            ($_ (py-call (io_bridge.print_output "\nAssistant: " $response)))
            ($_ (py-call (io_bridge.print_output "\n[Consensus State -> Individuation: " (formatFloat $gInd) " | Transcendence: " (formatFloat $gTrans) "]")))
        )
            (interactiveLoop $bimonad $translator $nextStates)
        )
    )
)

(= (interactiveLoop $bimonad $translator $states)
    (let* (
        ($userInput (py-call (io_bridge.read_user_input "\nYou: ")))
    )
        (processUserInput $bimonad $translator $states $userInput)
    )
)

(= (startAssistant)
    (let* (
        ($_ (py-call (io_bridge.print_output "Initializing MetaMo Multi-Subsystem Chat Interface (MeTTa)...")))
        ($bimonad (defaultMetaMoBimonad))
        ($baseState (createInitialState))

        ;; Initialize two parallel subsystems with highly divergent, domain-specific goal profiles
        ($goalsC (0.8 0.2 0.4 0.9 0.9 0.8 0.2 0.5))
        ($modC   (0.6 0.8 0.9 0.5 0.3 0.2))
        ($stateCuriosity (motivation $goalsC $modC))

        ($goalsE (0.2 0.8 0.9 0.3 0.2 0.6 0.95 0.8))
        ($modE   (0.5 0.3 0.4 0.6 0.9 0.9))
        ($stateEthics (motivation $goalsE $modE))

        ;; Package subsystems into the runMetaMoCycle-compatible list format
        ($states (
            (subsystemState curiosity $stateCuriosity)
            (subsystemState ethics    $stateEthics)))

        ($translator (createIdentityTranslator))

        ($_ (py-call (io_bridge.print_output "\nSystem Ready. Subsystems: [Curiosity] & [Ethics]. Type 'quit' to exit.")))
        ($_ (py-call (io_bridge.print_output "------------------------------------------------------------")))
    )
        (interactiveLoop $bimonad $translator $states)
    )
)

!(startAssistant)

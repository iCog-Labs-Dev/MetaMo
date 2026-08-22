!(import! &self ../../config)
!(import! &self ../../helper/utils)
!(import! &self ../state_bridge)

!(bind! &space (new-space))

!(addState &space ((default-goals) (default-mods) (default-anti-goals)))

; motivationSummary: unpacks a motivation atom into a readable pair-list
!(test
  (motivationSummary (motivation (0.65 0.44 0.55 0.52 0.46 0.62 0.65 0.58)
                                 (0.50 0.40 0.40 0.40 0.30 0.10)))
  ((gInd 0.65) (gTrans 0.44) (gHelp 0.55) (gCurio 0.52)
   (gNovel 0.46) (gSelf 0.62) (gEthic 0.65) (gSoc 0.58)
   (valence 0.50) (arousal 0.40) (approach 0.40) (resolution 0.40)
   (threshold 0.30) (securing 0.10))
)

; motivationSummary: all zeros
!(test
  (motivationSummary (motivation (0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0)
                                 (0.0 0.0 0.0 0.0 0.0 0.0)))
  ((gInd 0.0) (gTrans 0.0) (gHelp 0.0) (gCurio 0.0)
   (gNovel 0.0) (gSelf 0.0) (gEthic 0.0) (gSoc 0.0)
   (valence 0.0) (arousal 0.0) (approach 0.0) (resolution 0.0)
   (threshold 0.0) (securing 0.0))
)

; motivationSummary: all ones
!(test
  (motivationSummary (motivation (1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0)
                                 (1.0 1.0 1.0 1.0 1.0 1.0)))
  ((gInd 1.0) (gTrans 1.0) (gHelp 1.0) (gCurio 1.0)
   (gNovel 1.0) (gSelf 1.0) (gEthic 1.0) (gSoc 1.0)
   (valence 1.0) (arousal 1.0) (approach 1.0) (resolution 1.0)
   (threshold 1.0) (securing 1.0))
)

; projectToMotivation: using default-goals and default-mods from config
!(test
  (projectToMotivation &space)
  (motivation
    (0.65 0.44 0.5333333333333333 0.55 0.47 0.64 0.65 0.58)
    (0.5 0.30000000000000004 0.42500000000000004 0.4666666666666666 0.375 0.20000000000000004)
  )
)

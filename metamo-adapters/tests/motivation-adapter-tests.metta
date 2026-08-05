!(import! &self ../motivation-adapter)
!(test (defaultModulatorValue) 0.5)
!(test (defaultModulators) (0.5 0.5 0.5 0.5 0.5 0.5))
!(test
   (createMotivationState (0.2 0.9 0.8))
   (motivation (0.2 0.9 0.8) (0.5 0.5 0.5 0.5 0.5 0.5)))
!(test
   (motivationStateGoals
      (createMotivationState (0.2 0.9 0.8)))
   (0.2 0.9 0.8))
!(test
   (motivationStateModulators
      (createMotivationState (0.2 0.9 0.8)))
   (0.5 0.5 0.5 0.5 0.5 0.5))
!(test
   (motivationAdapter (0.9 0.0))
   (motivation (0.9 0.0) (0.5 0.5 0.5 0.5 0.5 0.5)))
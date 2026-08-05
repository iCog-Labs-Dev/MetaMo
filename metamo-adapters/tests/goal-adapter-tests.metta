
!(import! &self ../goal-adapter)
!(test (goalScoreFromStatus Active) 0.9)
!(test (goalScoreFromStatus Completed) 0.0)
!(test (goalAdapter &goalAdapterTestSpace) (0.9 0.0))
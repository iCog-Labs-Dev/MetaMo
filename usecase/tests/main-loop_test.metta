
!(import! &self ../main-loop)

; TEST 1: Session Replay from Stored Queries
; (qwestorLoopFromAllSessions &space (sessionIds))

; TEST 2: Interactive Qwestor loop
; (qwestorLoop &space "Decompose this into a 6-step plan to compare two algorithms")

; TEST 3: Single-turn Qwestor execution
; (runQwestor &space "Can I rely on this exact statistic without checking sources?")
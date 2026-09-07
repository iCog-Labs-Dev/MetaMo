;; Focused tests for bounded ContextFrames projection.

!(import! &self (library lib_import))
!(import! &self "../../../../../repos/OmegaClaw-Core/src/helper.py")
!(import! &self ../../../../../repos/OmegaClaw-Core/src/context)
!(import! &self (library MetaMo core/state))
!(import! &self (library MetaMo core/state_accessors))
!(import! &self (library MetaMo core/helper))
!(import! &self (library MetaMo core/helpers.py))
!(import! &self ../../../../../MetaMo/applications/omegaclaw_v1/contexts/context_relations)
!(import! &self ../../../../../MetaMo/applications/omegaclaw_v1/contexts/context_projection)

!(test (eval (frameStateMaxIndexRefs)) 20)
!(test (eval (frameStateMaxRelations)) 10)
!(test (size-atom
         (frameStateTake (frameStateMaxIndexRefs)
            (a b c d e f g h i j k l m n o p q r s t u v w x y))) 20)
!(test (size-atom
         (frameStateTake (frameStateMaxRelations)
            (r1 r2 r3 r4 r5 r6 r7 r8 r9 r10 r11 r12)))
      10)

;; The stateful projection entry points are covered by the integration smoke
;; test after `initContextFrame`; these focused checks stay state-independent.

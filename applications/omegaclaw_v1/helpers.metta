;; Application-local compatibility helpers for shared MetaMo modules.
;; The shared MeTTa norm wrapper is disabled; reuse its existing Python backend.
!(import! &self (library MetaMo core/helpers.py))

(= (norm $arr)
   (py-call (helpers.norm $arr)))

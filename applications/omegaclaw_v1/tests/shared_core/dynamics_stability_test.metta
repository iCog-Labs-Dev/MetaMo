;; Run unchanged shared-core assertions with the application-local norm helper.
;; Use scripts/run-omegaclaw.py for canonical, source-relative imports.
!(import! &self (library MetaMo applications/omegaclaw_v1/helpers))
!(import! &self (library MetaMo dynamics/tests/stability_tests))

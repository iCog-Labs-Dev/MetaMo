!(import! &self (library lib_import))

!(import! &self (library MetaMo core/config))
!(import! &self (library MetaMo applications/omegaclaw/openpsi_config))
!(import! &self (library MetaMo core/state))
!(import! &self (library MetaMo core/state_accessors))
!(import! &self (library MetaMo core/helper))
!(import! &self (library MetaMo core/helpers.py))
!(import! &self (library MetaMo category/functors))
!(import! &self (library MetaMo category/bimonad))
!(import! &self (library MetaMo dynamics/stability))
!(import! &self (library MetaMo dynamics/coherence))

!(import! &self (library MetaMo main/main))
!(import! &self (library MetaMo core/registry))
!(import! &self (library MetaMo applications/omegaclaw/registry))
!(import! &self (library MetaMo applications/omegaclaw/omegaclaw_appraisal))
!(import! &self (library MetaMo applications/omegaclaw/omegaclaw_decision))
!(import! &self (library MetaMo applications/omegaclaw/bridge))
!(import! &self (library MetaMo applications/omegaclaw/adapter))
!(import! &self (library MetaMo applications/omegaclaw/signals))



!(git-import! "https://github.com/asi-alliance/OmegaClaw-Core.git")
!(import! &self (library OmegaClaw-Core lib_omegaclaw))

!(motivatedOmegaclaw)

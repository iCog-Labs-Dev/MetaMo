;; Pure, optional host adapter contracts. Importing this file starts no engine,
;; allocates no state and installs no callbacks. Quote literal records as data.
!(import! &self (library MetaMo applications/omegaclaw_v1/factual_signals))
!(import! &self (library MetaMo applications/omegaclaw_v1/contexts/typed_policy))
!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/reasoner_proposal_helpers))

!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/host_reasoner_contract_data))

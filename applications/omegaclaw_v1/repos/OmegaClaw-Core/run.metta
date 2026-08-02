!(import! &self (library lib_import))
!(git-import! "https://github.com/asi-alliance/OmegaClaw-Core.git")
!(import! &self (library OmegaClaw-Core lib_omegaclaw))

; !(import! &self ../PeTTa/lib/lib_patrick)
; !(import! &self ../PeTTa/lib/lib_llm)
; !(import! &self ../PeTTa/lib/lib_vector)
; !(import! &self ../PeTTa/lib/lib_combinatorics)

; ; OmegaClaw Core is checked out under repos/, so import its sources directly.
; !(import! &self repos/OmegaClaw-Core/lib_nal)
; !(import! &self repos/OmegaClaw-Core/lib_pln)
; !(import! &self "repos/OmegaClaw-Core/lib_llm_ext.py")
; !(import! &self "repos/OmegaClaw-Core/src/helper.py")
; !(import! &self "repos/OmegaClaw-Core/src/agentverse.py")
; !(import! &self "repos/OmegaClaw-Core/channels/irc.py")
; !(import! &self "repos/OmegaClaw-Core/channels/mattermost.py")
; !(import! &self "repos/OmegaClaw-Core/channels/tg_channel.py")
; !(import! &self "repos/OmegaClaw-Core/channels/slack.py")
; !(import! &self "repos/OmegaClaw-Core/channels/websearch.py")
; !(import! &self repos/OmegaClaw-Core/src/utils)
; !(import! &self repos/OmegaClaw-Core/src/channels)
; !(import! &self repos/OmegaClaw-Core/src/skills)
; !(import! &self repos/OmegaClaw-Core/src/memory)
; !(import! &self "repos/OmegaClaw-Core/src/frame_relation.py")
; !(import! &self repos/OmegaClaw-Core/src/context)
; !(import! &self repos/OmegaClaw-Core/src/loop)

; ChromaDB is also checked out under repos/. Its MeTTa wrapper only imports
; this Python module, so reference the implementation directly.
;;!(import! &self "../PeTTa/repos/petta_lib_chromadb/lib_chromadb.py")




!(omegaclaw)

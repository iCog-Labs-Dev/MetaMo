; Expose the canonical Qwestor defaults from config.metta to the API service.

!(import! &self config)
!(import! &self service_bridge_wrappers)

!(let*
    (
      ($goals     (cdr-atom (default-goals)))
      ($mods      (cdr-atom (default-mods)))
      ($anti      (cdr-atom (default-anti-goals)))
      ($_emit     (emitServiceDefaults $goals $mods $anti))
    )
    done
)

; Expose the canonical Qwestor defaults from config.metta to the API service.

!(import! &self config)
!(import! &self "service_bridge.py")

!(let*
    (
      ($goals     (cdr-atom (default-goals)))
      ($mods      (cdr-atom (default-mods)))
      ($anti      (cdr-atom (default-anti-goals)))
      ($_emit     (py-call (service_bridge.emit_defaults $goals $mods $anti)))
    )
    done
)

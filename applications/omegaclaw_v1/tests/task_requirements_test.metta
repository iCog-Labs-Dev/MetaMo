;; One entry point; every scenario retains its own Core/Janus process and six checks.
!(import! &self (library lib_import))
!(import! &self fixtures/task_requirements.py)

!(test (py-call (task_requirements.run_scenario "conversation")) 1)

!(test (py-call (task_requirements.run_scenario "mixed")) 1)

!(test (py-call (task_requirements.run_scenario "uncertain")) 1)

!(test (py-call (task_requirements.run_scenario "invalid")) 1)

!(test (py-call (task_requirements.run_scenario "external")) 1)

!(test (py-call (task_requirements.run_scenario "failure")) 1)

!(test (py-call (task_requirements.run_scenario "followup")) 1)

!(test (py-call (task_requirements.run_scenario "replacement")) 1)

!(test (py-call (task_requirements.run_scenario "session")) 1)

!(test (py-call (task_requirements.run_scenario "policy")) 1)

!(test (py-call (task_requirements.run_scenario "route")) 1)

!(test (py-call (task_requirements.run_scenario "factual")) 1)

!(test (py-call (task_requirements.run_scenario "casual")) 1)

!(test (py-call (task_requirements.run_scenario "writing")) 1)

!(test (py-call (task_requirements.run_scenario "rewrite")) 1)

!(test (py-call (task_requirements.run_scenario "prepared_followup")) 1)

!(test (py-call (task_requirements.run_scenario "prepared_replacement")) 1)

!(test (py-call (task_requirements.run_scenario "prepared_session")) 1)

!(test (py-call (task_requirements.run_scenario "prepared_policy")) 1)

!(test (py-call (task_requirements.run_scenario "prepared_route")) 1)

!(test (py-call (task_requirements.run_scenario "prepared_requirements")) 1)

!(test (py-call (task_requirements.run_scenario "prepared_no_action")) 1)

!(test (py-call (task_requirements.run_scenario "prepared_invalid")) 1)

!(test (py-call (task_requirements.run_scenario "prepared_failure")) 1)

!(test (py-call (task_requirements.run_scenario "before_dispatch")) 1)

!(test (py-call (task_requirements.run_scenario "denied")) 1)

!(test (py-call (task_requirements.run_scenario "uncertain_delivery")) 1)


!(test (py-call (task_requirements.run_scenario "completion")) 1)

!(test (py-call (task_requirements.run_scenario "acknowledgement")) 1)

!(test (py-call (task_requirements.run_scenario "completion_second")) 1)

!(test (py-call (task_requirements.run_scenario "completion_uncertain")) 1)

!(test (py-call (task_requirements.run_scenario "completion_denied")) 1)

!(test (py-call (task_requirements.run_scenario "completion_mixed")) 1)

!(test (py-call (task_requirements.run_scenario "completion_stale")) 1)

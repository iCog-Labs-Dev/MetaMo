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

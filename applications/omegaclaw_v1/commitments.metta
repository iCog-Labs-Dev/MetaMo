;; Read-only host boundary. Opening commitments, adjudicating outcomes and
;; applying terminal events are trusted Prolog APIs, not model-callable skills.
!(import_prolog_functions_from_file
   (library MetaMo applications/omegaclaw_v1/commitments.pl)
   (commitmentSnapshot commitmentEvents))

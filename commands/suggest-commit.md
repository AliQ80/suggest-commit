---
description: Suggest a commit message for the current repository change
---

Use the suggest-commit skill for this request. Inspect the current repository
change and follow that skill's output rules exactly. Do not stage, commit, edit,
or otherwise mutate anything.

If the user supplied additional instructions after `/suggest-commit`, apply them
only when they do not conflict with the skill's read-only and output rules.

$ARGUMENTS

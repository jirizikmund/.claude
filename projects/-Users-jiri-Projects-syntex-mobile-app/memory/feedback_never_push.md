---
name: Never push without asking
description: Never run git push on your own — commit only, the user pushes themselves
type: feedback
originSessionId: 42effa56-42d9-4c00-a8a1-fa2a56e1ae7f
---
Never run `git push` (or any push) automatically — not even right after committing when the user said "commit". Committing locally is fine when asked; pushing is not.

**Why:** The user wants to review commits locally and control exactly what lands on the remote.
**How to apply:** After a commit, stop. State that the commit was made and that it has NOT been pushed; leave pushing to the user.

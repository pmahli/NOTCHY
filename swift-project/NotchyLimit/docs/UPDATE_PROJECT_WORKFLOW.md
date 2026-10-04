# Project Update Workflow

This is the repository-level contract for `/readProject`, `/readProjekt`,
`/updateProject`, and `/updateProjekt`. It exists so a new session can start
from evidence instead of relying on chat history.

## `/readProject`

Perform a read-only orientation first:

1. Read `docs/PROJECT_STATE.md`, the project README, and `docs/BUILDING.md`.
2. Run `git status --short --branch`, `git log -5 --oneline --decorate`, and
   inspect the configured remotes.
3. Check the current branch, PR, and HEAD against `PROJECT_STATE.md`.
4. Inspect the source tree and the files implicated by the current task.
5. Verify important local release facts when relevant: installed app path,
   bundle identifier, signing identity, notarization, and duplicate app copies.
6. Report drift explicitly as `verified`, `inferred`, or `not verified`.

`/readProject` must not edit, commit, push, delete, or rotate credentials.

## `/updateProject`

An update is complete only when the code and the project handoff agree:

1. Establish scope from the user's request and the current Git state.
2. Read the existing state and workflow documents before editing.
3. Inspect all modified files, including user changes already present in the
   working tree. Never revert unrelated work.
4. Implement the requested code or documentation changes.
5. Record the durable facts in `docs/PROJECT_STATE.md`:
   - date and environment;
   - branch, HEAD, PR, and remotes;
   - changed behavior and relevant files;
   - build, test, signing, install, and verification results;
   - known limitations, failed checks, and next actions;
   - local paths and credential metadata without secrets.
6. Update README or build docs when the supported workflow changed. Keep
   project state facts in `PROJECT_STATE.md`, not scattered through chat.
7. Run `git diff --check` and the smallest meaningful validation. Do not claim
   a full test suite passed when it was skipped, hung, or interrupted.
8. Re-read the resulting state document and compare it with `git status`.
9. Commit and push only when the user requested a repository update or the
   command's established project convention explicitly includes it. State the
   commit and remote branch in the final response.

## Documentation Rules

- Prefer exact paths, commands, identifiers, dates, and observed output.
- Separate verified facts from assumptions and open questions.
- Document why a workaround exists, not only what changed.
- Keep release identity metadata such as certificate subject, Team ID, and
  Keychain profile name; never store private keys, cookies, tokens, or app
  passwords.
- Mention generated or ignored artifacts that can confuse later sessions,
  especially duplicate `.app` bundles in build folders and DerivedData.
- Preserve the distinction between repository state and machine-local state.
- Link to the source file or script that owns each important behavior.

## Final Response Contract

After `/updateProject`, report briefly:

- files changed;
- validation performed and any gaps;
- commit and push status, if applicable;
- the next action needed by a future session.

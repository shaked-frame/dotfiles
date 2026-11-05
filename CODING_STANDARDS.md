# Coding standards

Read during review. Formatting (`.stylua.toml`) and the regression suite
(`scripts/test.sh`, run by the pre-commit hook) are enforced by tools, not here.

## Tests (`scripts/`)

- **Wait on a completion signal, then assert.** An async test waits for proof
  the action ran (an event fired, a flag the stub sets, a recorded call), and
  only then checks the result. Waiting directly for the expected end state
  passes vacuously when that state already holds before the action runs.
- **A new test goes red first.** A new or changed assertion is shown to fail
  with the behaviour removed (comment out the line under test, stub it away),
  then pass with it restored. Stubs and captured options prove this the most:
  a stub that records the wrong key's call passes for the wrong reason.

# Security Policy

Please report security issues privately by opening a GitHub security advisory or contacting the maintainer through GitHub.

Do not include OAuth tokens, API keys, raw session logs, private prompts, or provider account details in public issues.

## Privacy Expectations

LimitLens should remain local-first:

- no LimitLens backend;
- no telemetry;
- no raw prompts or raw provider logs in widget snapshots;
- no provider credentials outside the macOS Keychain.

Changes that expand data collection or network behavior should include tests and documentation updates.

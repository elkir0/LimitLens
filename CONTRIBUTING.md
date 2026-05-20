# Contributing

LimitLens is a local-first macOS app. Contributions should preserve the privacy model: no LimitLens backend, no telemetry, and no raw prompt/session data in snapshots or logs.

## Development

Run the test suite before submitting changes:

```bash
swift test
```

For app and widget work, also run:

```bash
xcodegen generate
xcodebuild -project LimitLens.xcodeproj -scheme LimitLens -configuration Release build
```

## Product Principles

- Keep provider setup explicit and understandable.
- Keep widgets read-only and sanitized.
- Keep UI compact and native to macOS.
- Localize user-facing strings in French, English, and Spanish.

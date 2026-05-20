# LimitLens

LimitLens is a local-first macOS menu bar app and WidgetKit widget set for monitoring OpenAI Codex and Claude Code usage.

It is built for people who use AI coding tools every day and want a quick view of remaining quota without opening each provider manually.

## Privacy

LimitLens has no server. The app reads local provider data you explicitly authorize and writes a sanitized local snapshot for widgets. Widgets never read provider credentials, raw logs, prompts, or session files.

Provider data stays on your Mac except for provider-owned usage endpoints that are required for configured features. In the current public scope, Claude exact usage can call Anthropic with a Claude Code OAuth token that you explicitly import. OpenAI Codex usage is read from local Codex session quota events and does not require an OpenAI API key.

## Providers

- OpenAI Codex: reads quota events from the Codex sessions folder selected by the user.
- Claude Code: reads local project usage estimates and can optionally import Claude Code OAuth credentials for exact usage.

Each provider can be enabled independently, so LimitLens can run as OpenAI-only, Claude-only, or both.

## Widgets

LimitLens includes small, medium, and large WidgetKit widgets for OpenAI Codex, Claude Code, and a combined overview. Install and launch the app once before adding widgets so macOS can register the extension.

## Distribution

LimitLens is designed for Developer ID distribution outside the Mac App Store. Widgets are bundled with the app extension and registered by macOS after installation.

## Build From Source

Requirements:

- macOS 14 or newer
- Xcode
- XcodeGen

Build:

```bash
DEVELOPMENT_TEAM=YOURTEAMID ./Scripts/build-app.sh
```

The `DEVELOPMENT_TEAM` value is optional when Xcode can infer a signing team
from your local account, but setting it makes CLI builds deterministic.

## Local Install

```bash
./Scripts/install-app.sh
```

The install script copies the app to `/Applications`, refreshes LaunchServices, and re-registers the widget extension for local testing.

## Release

Create an archive:

```bash
./Scripts/archive-app.sh
```

Notarize when Apple Developer credentials are configured:

```bash
./Scripts/notarize-app.sh dist/LimitLens.zip
```

The notarization script expects a `notarytool` keychain profile named `LimitLens`, or the profile named by `NOTARYTOOL_PROFILE`.

## Troubleshooting Widgets

If old widgets remain visible after updating a local build, remove the widget from Notification Center, run the install script again, then add the widget back.

For development diagnostics:

```bash
pluginkit -m -A -D -vvv -i com.limitlens.dashboard.widget
```

The active registration should point to `/Applications/LimitLens.app/Contents/PlugIns/LimitLensWidgetExtension.appex`.

## License

LimitLens is released under the MIT License.

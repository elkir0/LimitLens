# LimitLens

[Français](#français) | [English](#english)

![LimitLens, application barre de menus](docs/assets/limitlens-app-demo.png)

> Captures de démonstration avec données fictives. Demo screenshots with fictional data.

## Français

LimitLens est une application macOS locale pour suivre rapidement les quotas de vos outils IA de code : OpenAI Codex et Claude Code.

Elle vit dans la barre de menus, fournit des widgets macOS, fonctionne en sandbox, et ne dépend d'aucun serveur LimitLens.

### Pourquoi

Quand on utilise Codex et Claude Code toute la journée, le vrai besoin est simple : voir ce qu'il reste sans ouvrir plusieurs interfaces, sans exposer ses clés, et sans perdre les widgets macOS.

LimitLens affiche l'état utile au bon endroit :

- dans la barre de menus, avec un pourcentage restant lisible en permanence ;
- dans une fenêtre popover compacte pour les détails ;
- dans des widgets macOS petits, moyens et grands ;
- en mode OpenAI seul, Claude seul, ou les deux.

### Fonctionnalités

- Suivi local OpenAI Codex depuis les événements de quota présents dans les sessions Codex.
- Suivi Claude Code avec estimation locale et import optionnel du jeton OAuth Claude Code pour l'usage exact.
- Widgets séparés pour OpenAI et Claude, plus une vue combinée.
- Dates et heures de renouvellement des fenêtres de quota.
- Rafraîchissement configurable.
- Application sandboxée avec accès dossier explicite via macOS.
- Interface localisée en français, anglais et espagnol.

![Widgets LimitLens](docs/assets/limitlens-widgets-demo.png)

### Confidentialité

LimitLens est conçu pour rester local-first.

- Aucun serveur LimitLens.
- Aucune télémétrie.
- Aucun prompt, log brut, chemin utilisateur ou fichier de session brut dans les widgets.
- Les secrets restent dans le trousseau macOS.
- Les widgets lisent uniquement un instantané local nettoyé, prêt à l'affichage.

OpenAI Codex ne demande pas de clé API OpenAI dans le périmètre actuel : LimitLens lit les événements locaux que Codex écrit déjà sur votre Mac.

Claude Code peut fonctionner en estimation locale. L'usage exact est optionnel : si vous choisissez "Importer depuis Claude Code", LimitLens lit le jeton OAuth Claude Code déjà présent dans le trousseau macOS, en stocke une copie dans son propre item Keychain, puis l'utilise uniquement pour interroger le endpoint d'usage Claude Code.

Le détail du modèle de sécurité est dans [SECURITY.md](SECURITY.md). L'audit de publication est dans [docs/security-audit-2026-05-20.md](docs/security-audit-2026-05-20.md).

### Installation

La version compilée est fournie depuis les releases GitHub :

[Télécharger la dernière version](https://github.com/elkir0/LimitLens/releases/latest)

Après installation :

1. Ouvrez LimitLens une première fois.
2. Choisissez les fournisseurs à activer.
3. Autorisez les dossiers Codex et/ou Claude Code quand macOS le demande.
4. Ajoutez les widgets depuis le sélecteur de widgets macOS.

Si macOS bloque un build non notarié, ouvrez l'application avec clic droit puis "Ouvrir", ou compilez depuis les sources. Les releases notarizées seront indiquées explicitement quand un certificat Developer ID est disponible.

### Compilation

Prérequis :

- macOS 14 ou plus récent ;
- Xcode ;
- XcodeGen.

Build local :

```bash
DEVELOPMENT_TEAM=YOURTEAMID ./Scripts/build-app.sh
```

Installation locale pour tester app + widgets :

```bash
./Scripts/install-app.sh
```

Archive de distribution :

```bash
./Scripts/archive-app.sh
```

Notarisation, si le profil Apple est configuré :

```bash
./Scripts/notarize-app.sh dist/LimitLens.zip
```

Le script de notarisation utilise par défaut un profil `notarytool` nommé `LimitLens`, ou la valeur de `NOTARYTOOL_PROFILE`.

### Widgets

LimitLens embarque plusieurs widgets WidgetKit :

- petit OpenAI ;
- petit Claude Code ;
- moyen OpenAI ;
- moyen Claude Code ;
- grand OpenAI ;
- grand Claude Code ;
- grand aperçu combiné.

Si un ancien widget reste visible après une mise à jour locale, retirez-le du bureau, relancez `./Scripts/install-app.sh`, puis ajoutez-le à nouveau.

### Publication

Le dépôt public exclut les artefacts de build, archives, profils de signature, fichiers `.env`, clés privées, projet Xcode généré et notes internes de travail.

Avant chaque release, refaire au minimum :

```bash
swift test
python3 Scripts/make-readme-assets.py
git ls-files
```

Puis vérifier que l'archive publiée ne contient que `LimitLens.app`.

### Licence

LimitLens est distribué sous licence MIT.

## English

LimitLens is a local macOS app for quickly monitoring quota status for AI coding tools: OpenAI Codex and Claude Code.

It lives in the menu bar, ships with macOS widgets, runs in the App Sandbox, and does not rely on any LimitLens server.

### Why

When you use Codex and Claude Code all day, the real need is simple: see what remains without opening multiple interfaces, exposing secrets, or losing native macOS widgets.

LimitLens puts the useful status where you need it:

- in the menu bar, with an always-visible remaining percentage;
- in a compact popover for details;
- in small, medium, and large macOS widgets;
- in OpenAI-only, Claude-only, or combined mode.

### Features

- Local OpenAI Codex quota tracking from quota events already present in Codex sessions.
- Claude Code tracking with local estimates and optional Claude Code OAuth import for exact usage.
- Separate OpenAI and Claude widgets, plus a combined overview.
- Reset dates and times for quota windows.
- Configurable refresh interval.
- Sandboxed app with explicit folder access granted by macOS.
- Interface localized in French, English, and Spanish.

### Privacy

LimitLens is designed to stay local-first.

- No LimitLens server.
- No telemetry.
- No prompts, raw logs, user paths, or raw session files in widgets.
- Secrets stay in the macOS Keychain.
- Widgets read only a sanitized local snapshot ready for display.

OpenAI Codex does not require an OpenAI API key in the current scope: LimitLens reads local events that Codex already writes on your Mac.

Claude Code can run with local estimates. Exact usage is optional: if you choose "Import from Claude Code", LimitLens reads the existing Claude Code OAuth token from the macOS Keychain, stores a copy in its own Keychain item, and uses it only to query the Claude Code usage endpoint.

The security model is documented in [SECURITY.md](SECURITY.md). The publication audit is in [docs/security-audit-2026-05-20.md](docs/security-audit-2026-05-20.md).

### Installation

A compiled build is available from GitHub releases:

[Download the latest version](https://github.com/elkir0/LimitLens/releases/latest)

After installation:

1. Open LimitLens once.
2. Choose the providers you want to enable.
3. Grant access to the Codex and/or Claude Code folders when macOS asks.
4. Add the widgets from the macOS widget picker.

If macOS blocks a non-notarized build, right-click the app and choose "Open", or build it from source. Notarized releases will be explicitly marked when a Developer ID certificate is available.

### Build

Requirements:

- macOS 14 or newer;
- Xcode;
- XcodeGen.

Local build:

```bash
DEVELOPMENT_TEAM=YOURTEAMID ./Scripts/build-app.sh
```

Local install for testing app + widgets:

```bash
./Scripts/install-app.sh
```

Distribution archive:

```bash
./Scripts/archive-app.sh
```

Notarization, when Apple credentials are configured:

```bash
./Scripts/notarize-app.sh dist/LimitLens.zip
```

The notarization script uses a `notarytool` profile named `LimitLens` by default, or the value of `NOTARYTOOL_PROFILE`.

### Widgets

LimitLens includes several WidgetKit widgets:

- small OpenAI;
- small Claude Code;
- medium OpenAI;
- medium Claude Code;
- large OpenAI;
- large Claude Code;
- large combined overview.

If an old widget remains visible after a local update, remove it from the desktop, run `./Scripts/install-app.sh`, then add it again.

### Release

The public repository excludes build artifacts, archives, signing profiles, `.env` files, private keys, the generated Xcode project, and internal work notes.

Before each release, run at least:

```bash
swift test
python3 Scripts/make-readme-assets.py
git ls-files
```

Then verify that the published archive contains only `LimitLens.app`.

### License

LimitLens is released under the MIT License.

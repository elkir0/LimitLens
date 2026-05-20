# Politique de sécurité

Merci de signaler les problèmes de sécurité en privé via une GitHub Security Advisory, ou en contactant le mainteneur depuis GitHub.

N'ouvrez pas d'issue publique contenant un jeton OAuth, une clé API, un log de session brut, un prompt privé, un identifiant de compte ou une capture contenant des données de quota personnelles.

## Modèle de sécurité

LimitLens doit rester local-first :

- aucun serveur LimitLens ;
- aucune télémétrie ;
- aucune clé fournisseur dans le dépôt ;
- aucun prompt ou log brut dans les widgets ;
- aucun secret hors du trousseau macOS ;
- accès aux dossiers accordé explicitement par macOS ;
- snapshot widget nettoyé et limité aux données d'affichage.

## Données lues

- OpenAI Codex : événements locaux de quota dans le dossier Codex choisi par l'utilisateur.
- Claude Code : estimation locale depuis les fichiers Claude choisis par l'utilisateur.
- Claude exact, optionnel : jeton OAuth Claude Code importé depuis le trousseau macOS et utilisé uniquement pour interroger l'usage Claude Code.

## Données stockées

- Préférences de configuration sans secret.
- Bookmarks de sécurité macOS pour les dossiers autorisés.
- Jeton OAuth Claude Code dans le trousseau macOS, uniquement si l'utilisateur lance l'import.
- Snapshot local nettoyé pour les widgets, sans token, clé API, prompt, log brut ni chemin utilisateur.

## Avant une release

Vérifier :

- `swift test` ;
- absence de secrets dans l'arbre courant ;
- absence de secrets dans l'historique Git ;
- absence d'archives, profils de signature, fichiers `.env` ou notes internes ;
- signature et, si disponible, notarisation de l'archive macOS.

Le dernier audit documenté est dans [docs/security-audit-2026-05-20.md](docs/security-audit-2026-05-20.md).

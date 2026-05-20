# Audit sécurité de publication - 20 mai 2026

Objectif : préparer le dépôt public et la release macOS sans publier d'identifiants, clés, jetons, chemins personnels ou artefacts de signature.

## Résultat

Audit OK pour publication du dépôt :

- aucun secret haute confiance détecté dans l'arbre courant ;
- aucun secret haute confiance détecté dans l'historique Git scanné ;
- aucun fichier `.env`, certificat, profil de provisioning, archive ou build produit n'est suivi par Git ;
- les documents internes de travail et notes de debug ont été retirés du dépôt public ;
- les captures du README utilisent des données fictives générées pour la démonstration ;
- les chemins restants dans les tests sont des valeurs synthétiques de type `/Users/example` ou `/Users/test`.

## Patterns vérifiés

Le scan local a recherché notamment :

- clés OpenAI de type `sk-...` ;
- clés Anthropic de type `sk-ant-...` ;
- tokens GitHub `ghp_...`, `github_pat_...` ;
- blocs de clés privées PEM ;
- tokens Slack ;
- clés AWS `AKIA...` ;
- fichiers `.env`, `.p8`, `.p12`, `.pem`, `.key`, `.mobileprovision`, `.provisionprofile` ;
- archives `.zip`, `.dmg`, `.xcarchive` suivies par Git ;
- projet Xcode généré et dossiers de build.

## Points d'attention

La version publique est pensée pour une distribution hors Mac App Store avec Developer ID. Sur cette machine, seul un certificat Apple Development est disponible au moment de l'audit, donc une archive entièrement notarizée ne peut pas être produite localement sans ajouter un certificat Developer ID et un profil `notarytool`.

Tant que la notarisation n'est pas faite, macOS peut demander une ouverture manuelle de l'application. Le dépôt contient déjà les scripts de build, archive et notarisation pour produire une release Developer ID propre dès que les identifiants Apple de distribution sont configurés.

## Commandes de vérification recommandées

```bash
swift test
git status --short
git ls-files
git log --all --name-only --pretty=format:
python3 Scripts/make-readme-assets.py
```

Pour une release finale notarizée :

```bash
./Scripts/archive-app.sh
./Scripts/notarize-app.sh dist/LimitLens.zip
spctl -a -vvv -t execute /path/to/LimitLens.app
```

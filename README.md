# aisession

CLI unifié pour lister, inspecter et nettoyer les sessions locales d'agents IA.

## Problème

Les agents comme **Codex CLI**, **OpenCode** et **Antigravity CLI** stockent leurs historiques localement. Ces sessions s'accumulent sans cleanup et deviennent impossibles à retrouver ou nettoyer individuellement.

`aisession` offre une commande unique pour reprendre le contrôle.

## Providers

| Provider    | Lister | Supprimer | Nettoyage | Titres |
|-------------|--------|-----------|-----------|--------|
| Codex CLI   | ✅     | ✅        | ✅ vides/orphelins | ✅ |
| OpenCode    | ✅     | ✅ (CLI)  | ✅ orphelins | ✅ |
| Antigravity | ✅ CLI+IDE | ✅ fichier | ✅ <100B | partiel |

## Installation

```powershell
# Clone
git clone https://github.com/XDayonline/aisession.git
cd aisession

# Ajouter au PATH (Windows)
.\install.ps1

# Usage direct sans install
.\src\aisessions.ps1 doctor
```

## Usage

### Diagnostiquer
```powershell
aisession doctor
```

### Lister les sessions
```powershell
aisession list                    # Dossier courant uniquement
aisession list -tree              # Dossier courant + sous-dossiers
aisession list -all               # Toutes les sessions
aisession list -provider codex    # Filtrer par provider
```

### Supprimer
```powershell
aisession delete <id>             # Supprimer avec confirmation
aisession delete 1 -dry-run       # Simuler
aisession delete 1 -force         # Sans confirmation
```

### Nettoyage automatique
```powershell
aisession clean -empty -dry-run           # Sessions vides
aisession clean -empty -force              # Réel
aisession clean -orphaned -dry-run         # Orphelines (projet supprimé)
aisession clean -orphaned -force
aisession clean -empty -orphaned -dry-run  # Vides + orphelines
aisession clean -older-than 30d -dry-run   # Anciennes
aisession clean -older-than 60d -provider codex -dry-run
```

### Mode interactif
```powershell
aisession pick
```
Navigation aux flèches, actions : [D]elete, [R]esume, [C]ancel.

## Couleurs

| Provider    | Couleur |
|-------------|---------|
| Codex CLI   | Jaune   |
| OpenCode    | Cyan    |
| Antigravity | Magenta |
| Session courante | Cyan |

## Stockage des sessions

| Provider    | Emplacement |
|-------------|-------------|
| Codex CLI   | `~\.codex\sessions\` (JSONL) |
| OpenCode    | `~\.local\share\opencode\opencode.db` (SQLite) |
| Antigravity CLI | `~\.gemini\antigravity-cli\conversations\` |
| Antigravity IDE | `~\.gemini\antigravity\conversations\` |

## Sécurité

- Aucune télémétrie, aucun appel réseau
- `--dry-run` disponible sur toutes les commandes destructives
- Confirmation obligatoire sauf `--force`
- OpenCode : suppression via `opencode session delete`, jamais d'écriture directe SQLite
- Codex : suppression limitée à `~/.codex/sessions/` + purge `history.jsonl`
- Antigravity : suppression du fichier + purge `history.jsonl`

## Structure du projet

```
aisession/
  src/
    aisessions.ps1       # CLI principal
    core/
      session-model.ps1  # Modèle commun Session
      session-filter.ps1 # Filtres exact/tree/all
      clean-filter.ps1   # Nettoyage (empty, older-than)
      formatting.ps1     # Affichage, couleurs
      safety.ps1         # Confirmation, dry-run
      interactive.ps1    # Mode interactif fléché
    providers/
      codex.ps1          # Provider Codex CLI
      opencode.ps1       # Provider OpenCode
      antigravity.ps1    # Provider Antigravity
  tests/
    session-filter.tests.ps1
    clean-filter.tests.ps1
    codex.tests.ps1
    safety.tests.ps1
```

## Tests

```powershell
# Pester requis (v3+)
Invoke-Pester .\tests\
```

## Licence

MIT

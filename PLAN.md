# aisessions - Plan Produit Et Technique

## But

`aisessions` est un CLI open source pour lister, inspecter et supprimer proprement les sessions locales d'agents IA.

Le probleme cible est simple : les agents comme Codex, OpenCode ou Antigravity gardent des historiques locaux qui peuvent contenir prompts, chemins projets, extraits de code, erreurs, decisions techniques, voire des secrets colles par accident. Ces sessions s'accumulent pendant des mois et deviennent difficiles a retrouver ou nettoyer.

L'objectif est de fournir un outil unique, prudent et lisible pour reprendre le controle de ces sessions.

## Pourquoi Le Faire

- Securite : reduire l'exposition locale de donnees sensibles stockees dans d'anciennes sessions.
- Hygiene machine : supprimer les sessions inutiles, vides, anciennes ou orphelines.
- Simplicite : un seul CLI pour plusieurs agents IA au lieu de scripts separes.
- Transparence OSS : code public, pas de telemetrie, comportement auditable.
- Utilite ecosysteme : aider les developpeurs et maintainers open source a gerer leurs historiques d'agents.

## Nom Et Commande

Nom du projet : `aisessions`

Commande principale :

```powershell
aisessions
```

Alias optionnel :

```powershell
session
```

`session` est plus fluide au quotidien, mais trop generique pour etre impose par defaut. Le plan recommande donc `aisessions` comme commande officielle, avec `session` propose pendant l'installation.

## Scope MVP

Le MVP doit couvrir peu de choses, mais tres bien.

### Providers Supportes

1. Codex
   - Lister les sessions.
   - Afficher titre, date, projet, chemin, taille.
   - Supprimer une session precise.
   - Nettoyer les sessions vides ou anciennes.
   - Purger l'historique lie quand c'est possible sans casser le format.

2. OpenCode
   - Lister les sessions depuis le stockage local.
   - Afficher titre, date, projet, id.
   - Supprimer via la commande officielle `opencode session delete`.
   - Eviter la suppression directe dans SQLite en MVP.

3. Antigravity / `agy`
   - Detecter si l'outil est installe.
   - Detecter les chemins candidats de sessions si connus.
   - Ne pas supprimer en MVP tant que le format exact n'est pas valide.

## Commandes MVP

### `aisessions doctor`

But : diagnostiquer l'environnement.

Doit afficher :

- providers detectes ;
- chemins de sessions trouves ;
- outils CLI disponibles ;
- permissions de lecture/ecriture ;
- formats supportes ;
- warnings si un provider est detecte mais non supporte en suppression.

### `aisessions list`

But : lister les sessions du projet courant par defaut.

Colonnes recommandees :

- provider ;
- id court ;
- date derniere activite ;
- projet ;
- titre ou premier message ;
- taille ;
- indicateur session courante si detectable.

### `aisessions list --all`

But : lister toutes les sessions locales supportees, sans filtrer sur le projet courant.

### `aisessions delete <id>`

But : supprimer une session ciblee.

Regles :

- confirmation obligatoire ;
- afficher provider, id, titre, projet, chemin avant suppression ;
- refuser ou avertir fortement si session courante ;
- `--force` pour supprimer sans confirmation ;
- `--dry-run` pour afficher ce qui serait supprime.

### `aisessions clean`

But : proposer un nettoyage guide.

Options MVP :

```powershell
aisessions clean --older-than 30d --dry-run
aisessions clean --empty --dry-run
aisessions clean --provider codex --older-than 30d
```

`--dry-run` doit etre recommande dans la documentation et visible dans les exemples.

## Architecture

Stack recommandee MVP : PowerShell 7.

Raison :

- les scripts existants sont deja en PowerShell ;
- l'environnement utilisateur cible est Windows-first ;
- installation simple ;
- bon acces fichiers, JSONL, SQLite via fallback Python ou CLI officiel ;
- diff initial plus rapide qu'un rewrite en Go/Rust/Node.

Structure proposee :

```text
aisessions/
  README.md
  LICENSE
  install.ps1
  src/
    aisessions.ps1
    core/
      formatting.ps1
      safety.ps1
      session-model.ps1
    providers/
      codex.ps1
      opencode.ps1
      antigravity.ps1
  tests/
    codex.tests.ps1
    opencode.tests.ps1
    safety.tests.ps1
```

## Modele Commun

Chaque provider doit retourner des objets avec une forme commune :

```text
Session:
  Id
  Provider
  Title
  ProjectPath
  SourcePath
  UpdatedAt
  SizeBytes
  IsCurrent
  IsEmpty
```

Ce modele permet d'avoir une seule UX pour plusieurs agents.

## Interface Provider

Chaque provider expose les fonctions suivantes :

```text
Detect-Provider
Get-Sessions
Remove-Session
Get-CleanCandidates
```

Pas besoin d'abstraction complexe au debut. Des fonctions PowerShell par fichier provider suffisent.

## Regles De Securite

Ces regles sont non negociables.

1. Ne jamais supprimer hors des chemins connus d'un provider.
2. Toujours afficher ce qui va etre supprime.
3. Confirmation obligatoire sauf `--force`.
4. `--dry-run` disponible pour toute commande destructive.
5. Warning fort pour session courante.
6. Pas de telemetrie.
7. Pas de reseau.
8. Pas de suppression directe dans une base de donnees si une commande officielle existe.
9. En cas de format inconnu, lister seulement, ne pas supprimer.

## Plan D'Implementation

### Etape 1 - Repo Et Documentation

Creer la structure du repo, le README, la licence et ce plan.

Verification :

- le repo explique clairement le probleme ;
- les commandes MVP sont documentees ;
- la section securite est visible.

### Etape 2 - CLI Skeleton

Creer `src/aisessions.ps1` avec parsing simple :

- `doctor`
- `list`
- `delete`
- `clean`
- `--provider`
- `--all`
- `--dry-run`
- `--force`
- `--help`

Verification :

- chaque commande affiche une aide ou un resultat stable ;
- les commandes inconnues retournent une erreur claire.

### Etape 3 - Provider Codex

Adapter la logique existante de `codexses.ps1`.

Fonctions :

- detecter `~/.codex/sessions` ;
- parser les `.jsonl` ;
- extraire id, cwd, timestamp, titre/premier message ;
- lister ;
- supprimer un fichier session ;
- purger `history.jsonl` uniquement pour les ids supprimes.

Verification :

- `aisessions list --provider codex` fonctionne ;
- `delete --dry-run` ne supprime rien ;
- `delete --force` supprime uniquement la session ciblee.

### Etape 4 - Provider OpenCode

Adapter la logique existante de `openses.ps1`.

Fonctions :

- detecter `~/.local/share/opencode/opencode.db` ;
- lister les sessions ;
- filtrer projet courant ;
- supprimer via `opencode session delete <id>`.

Verification :

- `aisessions list --provider opencode` fonctionne ;
- aucune ecriture directe SQLite ;
- suppression refusee si `opencode` CLI absent.

### Etape 5 - Provider Antigravity

Faire uniquement la detection initiale.

Fonctions :

- detecter `agy` dans le PATH ;
- chercher les chemins de config/session connus localement ;
- afficher le statut dans `doctor`.

Verification :

- `doctor` affiche Antigravity comme detecte ou absent ;
- aucune suppression Antigravity en MVP.

### Etape 6 - Clean Candidates

Implementer les candidats de nettoyage :

- sessions vides ;
- sessions plus anciennes que `--older-than` ;
- sessions sans projet detecte ;
- sessions dont le chemin projet n'existe plus.

Verification :

- `clean --dry-run` affiche la liste cible ;
- sans `--force`, confirmation requise ;
- aucun chemin hors provider n'est supprime.

### Etape 7 - Tests

Ajouter tests PowerShell avec fixtures locales.

Tests prioritaires :

- parsing Codex JSONL ;
- mapping OpenCode SQLite ou JSON mocke ;
- detection chemins ;
- refus suppression hors racine provider ;
- dry-run sans suppression.

Verification :

- tests passent localement ;
- pas besoin de vraies sessions utilisateur pour tester.

### Etape 8 - Packaging OSS

Ajouter :

- README complet ;
- exemples commandes ;
- section privacy/security ;
- install Windows ;
- roadmap ;
- contribution guide minimal ;
- GitHub Actions si pertinent.

Verification :

- un utilisateur peut installer et lancer `aisessions doctor` depuis le README ;
- le projet est comprehensible sans lire le code.

## Roadmap Apres MVP

- Support Linux/macOS.
- Support Claude Code.
- Support Gemini CLI.
- Support Cursor/Windsurf si formats identifiables.
- Export rapport avant suppression.
- Mode archive au lieu de suppression.
- Installation via Scoop.
- Rewrite eventuel en Go ou Rust si besoin multi-OS/package propre.

## Criteres De Succes

Le MVP est reussi si :

- un utilisateur peut lister ses sessions Codex et OpenCode ;
- il peut supprimer une session ciblee sans risque de suppression large ;
- `dry-run` est fiable ;
- `doctor` explique clairement ce qui est supporte ;
- aucune donnee n'est envoyee sur le reseau ;
- le README rend le projet publiable en open source.

## Impacts

SEO :

- potentiel correct avec les mots-cles `Codex sessions`, `OpenCode sessions`, `AI agent cleanup`, `AI agent privacy`, `local session cleaner`.

Performance :

- attention aux gros historiques Codex `.jsonl` ;
- lire les fichiers de facon ciblee et eviter les scans complets inutiles.

Securite :

- impact positif si l'outil reste prudent ;
- risque principal : suppression trop large ou mauvaise interpretation d'un format.

Contrat API :

- aucun contrat API public ;
- dependance fragile aux formats internes Codex/OpenCode.

Migration :

- prevoir que les chemins et formats changent ;
- `doctor` doit aider a diagnostiquer les providers casses.

Comportement utilisateur :

- suppression irreversible ;
- UX defensive obligatoire.

## Decision Recommandee

Demarrer avec un MVP PowerShell Windows-first, centre sur Codex et OpenCode.

Ne pas inclure `codex-delta` dans le premier repo : utile personnellement, mais hors sujet pour le positionnement securite/privacy. Le projet doit rester focalise sur la gestion et le nettoyage des sessions IA.

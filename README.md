# Dotfiles

Configuration personnelle pour macOS : zsh, Git, Starship, Ghostty, Zed, Raycast et Homebrew.

## Contenu

| Chemin | Rôle |
| --- | --- |
| `.zshrc` | Shell : complétion, fzf, zoxide, alias, prompt Starship |
| `.gitconfig` | Identité, options et alias Git |
| `git/ignore` | Ignore global (`.DS_Store`, fichiers d'éditeur) |
| `Brewfile` | Paquets et applications Homebrew |
| `starship/starship.toml` | Prompt |
| `ghostty/config` | Terminal Ghostty |
| `zed/settings.json` | Éditeur Zed |
| `raycast/raycast.rayconfig` | Export Raycast, à importer à la main |
| `install.sh` | Installation |

## Prérequis

- macOS
- `git`
- Un compte autorisé à installer les Xcode Command Line Tools et Homebrew (le script s'en charge s'ils manquent)

fzf doit être en version 0.48 ou plus récente : `.zshrc` charge l'intégration shell avec `fzf --zsh`. La formule du `Brewfile` fournit cette version.

## Installation

```bash
git clone https://github.com/ouap/dotfiles.git
cd dotfiles
./install.sh
```

Puis ouvrir un nouveau terminal, ou exécuter `source ~/.zshrc`.

## Ce que fait `install.sh`

1. Vérifie les Xcode Command Line Tools. S'ils manquent, lance l'installeur macOS et s'arrête : il faut relancer le script une fois l'installation terminée.
2. Installe Homebrew s'il est absent.
3. Installe les paquets et les applications du `Brewfile` (`brew bundle`).
4. Crée les liens symboliques ci-dessous. Le dossier parent est créé si besoin.
5. Si la cible est un fichier ou un dossier réel, le déplace dans `~/.dotfiles-backup/<date-heure>/...` avant de le remplacer. Un lien qui pointe déjà au bon endroit est laissé tel quel (`Already linked`). Un lien qui pointe ailleurs est remplacé.
6. Si Raycast est installé (`/Applications/Raycast.app`), ouvre `raycast/raycast.rayconfig`.

| Fichier du dépôt | Destination |
| --- | --- |
| `.zshrc` | `~/.zshrc` |
| `.gitconfig` | `~/.gitconfig` |
| `git/ignore` | `~/.config/git/ignore` |
| `starship/starship.toml` | `~/.config/starship.toml` |
| `ghostty/config` | `~/Library/Application Support/com.mitchellh.ghostty/config` |
| `zed/settings.json` | `~/.config/zed/settings.json` |

Raycast ne se configure pas avec un lien symbolique. L'import se fait depuis l'application, en ouvrant `raycast/raycast.rayconfig` (Raycast demande confirmation). `install.sh` ouvre ce fichier quand l'application est déjà là ; sinon, l'ouvrir soi-même après avoir installé Raycast.

`DOTFILES_SKIP_BREW=1 ./install.sh` saute l'installation de Homebrew et `brew bundle`. La vérification des Xcode Command Line Tools a toujours lieu, et les liens sont toujours créés. Sans cette variable, le script fait l'installation complète.

## Tests

Les tests n'installent rien. `install.sh` tourne dans un faux `$HOME`, avec `brew`, `xcode-select`, `open` et `curl` remplacés par des commandes factices. Le même script fonctionne sous Linux et macOS.

```bash
bash tests/run.sh
```

`tests/run.sh` enchaîne shellcheck, `zsh -n .zshrc` et le test d'installation. Séparément :

```bash
shellcheck install.sh tests/install_test.sh tests/run.sh
zsh -n .zshrc
bash tests/install_test.sh
```

`shellcheck` et `zsh` sont nécessaires pour les deux premières commandes. `tests/install_test.sh` ne dépend que de bash (compatible avec le bash 3.2 de macOS). Il vérifie que chaque lien pointe vers le fichier du dépôt, que les fichiers réels déjà présents sont déplacés dans `~/.dotfiles-backup/...`, et qu'une seconde exécution affiche `Already linked` sans nouvelle sauvegarde.

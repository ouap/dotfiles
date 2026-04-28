# ==============================================================================
# Zsh configuration
# ==============================================================================

# ------------------------------------------------------------------------------
# Homebrew
# ------------------------------------------------------------------------------

if command -v brew >/dev/null 2>&1; then
  fpath=("/opt/homebrew/share/zsh-completions" $fpath)
fi


# ------------------------------------------------------------------------------
# Completion (compinit → fzf-tab → zsh-syntax-highlighting)
# ------------------------------------------------------------------------------
autoload -Uz compinit
compinit

# fzf-tab: replaces the native completion menu with fzf (real paths from current directory)
if [ -f /opt/homebrew/opt/fzf-tab/share/fzf-tab/fzf-tab.zsh ]; then
  source /opt/homebrew/opt/fzf-tab/share/fzf-tab/fzf-tab.zsh
fi

# Case-insensitive matching
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
# Disable native menu so fzf-tab takes over
zstyle ':completion:*' menu no
# Show category label inside fzf
zstyle ':completion:*:descriptions' format '[%d]'

# Preview directories with eza when completing cd
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --tree --level=2 --color=always $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'eza --tree --level=2 --color=always $realpath'


# ------------------------------------------------------------------------------
# Plugins
# ------------------------------------------------------------------------------

# zsh-autosuggestions
if [ -f /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
  source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

# zsh-syntax-highlighting
if [ -f /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
  source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# ------------------------------------------------------------------------------
# fzf — fuzzy finder with smart path navigation
# ------------------------------------------------------------------------------
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Use fd as the default file finder (faster than find, respects .gitignore)
export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# ALT+C: jump into a subdirectory using fzf (directories only)
export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'

# CTRL+T: preview files with bat | ALT+C: preview directory tree with eza
export FZF_CTRL_T_OPTS="--preview 'bat --color=always {}' --preview-window=right:50%"
export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --color=always {}'"

# ------------------------------------------------------------------------------
# Aliases
# ------------------------------------------------------------------------------
alias ls='eza'
alias l='eza -lbF --git'
alias ll='eza -lbGF --git'
alias la='eza -labGF --git'
alias oz='open -a Zed '
alias ..='cd ..'
alias ...='cd ../..'

# ------------------------------------------------------------------------------
# Prompt
# ------------------------------------------------------------------------------

eval "$(starship init zsh)"

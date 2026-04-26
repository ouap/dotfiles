# ==============================================================================
# Zsh configuration
# ==============================================================================

# ------------------------------------------------------------------------------
# Homebrew
# ------------------------------------------------------------------------------

if command -v brew >/dev/null 2>&1; then
  fpath=("$(brew --prefix)/share/zsh-completions" $fpath)
fi

# ------------------------------------------------------------------------------
# Completion
# ------------------------------------------------------------------------------

autoload -Uz compinit
compinit

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

# fzf
if [ -f ~/.fzf.zsh ]; then
  source ~/.fzf.zsh
fi

# fd + fzf (meilleure perf pour CTRL+T et autres)
export FZF_DEFAULT_COMMAND='fd --type f --hidden'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

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

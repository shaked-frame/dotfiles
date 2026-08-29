# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                              ENVIRONMENT SETUP                               ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# Increase function nesting limit (prevents starship/zle recursion issues)
FUNCNEST=100

# Homebrew
[[ -f "/opt/homebrew/bin/brew" ]] && eval "$(/opt/homebrew/bin/brew shellenv)"

# Default editor
export EDITOR=nvim

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                                   HISTORY                                    ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

HISTFILE="$HOME/.zhistory"
HISTSIZE=10000
SAVEHIST=10000

setopt appendhistory           # Append to history file
setopt share_history           # Share history between sessions
setopt hist_ignore_space       # Ignore commands starting with space
setopt hist_ignore_all_dups    # Remove older duplicates
setopt hist_save_no_dups       # Don't save duplicates
setopt hist_find_no_dups       # Don't show duplicates when searching
setopt hist_expire_dups_first  # Expire duplicates first
setopt hist_verify             # Show command before executing from history

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                              PLUGIN MANAGER                                  ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Auto-install zinit if missing
if [[ ! -d "$ZINIT_HOME" ]]; then
  mkdir -p "$(dirname "$ZINIT_HOME")"
  git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

source "${ZINIT_HOME}/zinit.zsh"

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                                  PLUGINS                                     ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# Syntax highlighting (must load before autosuggestions for proper colors)
zinit light zsh-users/zsh-syntax-highlighting

# Completions and suggestions
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions

# FZF integration for tab completion
zinit light Aloxaf/fzf-tab

# Shows alias tips when you type a command that has an alias
zinit light djui/alias-tips

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                                COMPLETIONS                                   ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# User completions (sesh, etc.)
fpath=("$HOME/.zsh/completions" $fpath)

autoload -Uz compinit && compinit
zinit cdreplay -q

# Case-insensitive completion
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# Use LS_COLORS for completion coloring
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# Disable default menu (use fzf-tab instead)
zstyle ':completion:*' menu no

# FZF-tab previews for cd and zoxide
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -la --icons=always --group-directories-first $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'eza -la --icons=always --group-directories-first $realpath'

# Carapace argument completion
export CARAPACE_BRIDGES='zsh,fish,bash,inshellisense'
zstyle ':completion:*' format $'\e[2;37mCompleting %d\e[m'
zstyle ':fzf-tab:complete:terraform:*' disabled-on any
source <(carapace _carapace)

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                               KEY BINDINGS                                   ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# History navigation
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward

# Edit current command in $EDITOR (Ctrl+X, Ctrl+E)
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line

# Clear screen and scrollback (Ctrl+X, L)
function clear-screen-and-scrollback() {
  echoti civis >"$TTY"
  printf '%b' '\e[H\e[2J\e[3J' >"$TTY"
  echoti cnorm >"$TTY"
  zle redisplay
}
zle -N clear-screen-and-scrollback
bindkey '^Xl' clear-screen-and-scrollback

# Copy command buffer to clipboard (Ctrl+X, C)
function copy-buffer-to-clipboard() {
  echo -n "$BUFFER" | pbcopy
  zle -M "Copied to clipboard"
}
zle -N copy-buffer-to-clipboard
bindkey '^Xc' copy-buffer-to-clipboard

# Git quick bindings
bindkey -s '^Xgc' 'git commit -m ""\C-b'
bindkey -s '^Xgp' 'git push origin '
bindkey -s '^Xgs' 'git status\n'
bindkey -s '^Xgl' 'git log --oneline -n 10\n'

# Word navigation (Option/Alt + Arrow keys)
bindkey '^[[1;3D' backward-word  # Option + Left
bindkey '^[[1;3C' forward-word   # Option + Right

# Line navigation (Cmd + Arrow keys)
bindkey '^[[H' beginning-of-line  # Cmd + Left
bindkey '^[[F' end-of-line

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                                  ALIASES                                     ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# General
alias vim='NVIM_APPNAME=nvim-minimax nvim'
alias oc='opencode'
alias c='clear'
alias pn='pnpm'
alias reload-zsh="source ~/.zshrc"

# File navigation with FZF
alias zf='nvim $(fzf -m --preview="bat --color=always {}")'
alias z='zoxide'

# Eza (better ls)
alias ls="eza -G -a --icons=always --group-directories-first --git-ignore"
alias ltree="eza --tree --level=2  --icons --git"

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# ── Git ───────────────────────────────────────────────────────────────────────
alias ga='git add'
alias gaa='git add --all'
alias gc='git commit -m'
alias gca='git commit --amend'
alias gst='git status'
alias gl='git pull'
alias gp='git push'
alias gpf='git push --force-with-lease'
alias gb='git branch'
alias gco='git checkout'
alias gsw='git switch'
alias gd='git diff'
alias gds='git diff --staged'
alias glog='git log --oneline --graph --decorate'
alias grb='git rebase'
alias gm='git merge'
alias gsta='git stash'
alias gstp='git stash pop'

# ── Global aliases (pipe shortcuts) ───────────────────────────────────────────
alias -g J='| jq'      # Pipe to jq
alias -g C='| pbcopy'  # Copy to clipboard

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                            DIRECTORY HASHES                                  ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# Usage: cd ~dot, cd ~frm, etc.
hash -d dot=~/dotfiles
hash -d dl=~/Downloads
hash -d frm=~/frame
hash -d infra=~/frame-infra/frame/

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                                 FUNCTIONS                                    ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# Yazi file manager with directory switching
function y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(command cat -- "$tmp")" && [[ -n "$cwd" ]] && [[ "$cwd" != "$PWD" ]]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}

function lg() {
    if ! (( $+commands[lazygit] )); then
        print "${COLOR[RED]}Error:${COLOR[RESET]} 'lazygit' is not installed." >&2
        return 1
    fi

    local lg_config_file="${TMPDIR:-/tmp}/lazygit-chdir"
    LAZYGIT_NEW_DIR_FILE="$lg_config_file" command lazygit "$@"

    if [[ -f "$lg_config_file" ]]; then
        local target_dir=$(cat "$lg_config_file")
        if [[ -d "$target_dir" && "$target_dir" != "$PWD" ]]; then
            cd "$target_dir"
            print "${COLOR[GREEN]}:: Switched to:${COLOR[RESET]} $target_dir"
        fi
        rm -f "$lg_config_file"
    fi
}

# Function with feedback
function bup() {
  echo "📦 Updating Homebrew..."
  brew update
  echo "⬆️  Upgrading packages..."
  brew upgrade
  echo "🧹 Cleaning up..."
  brew cleanup
  echo "🩺 Running doctor..."
  brew doctor
}

# Bootstrap dependencies in a worktree. Creating and opening the worktree itself
# is herdr's job (`prefix+shift+g` to create, `prefix+shift+o` to open, or
# `herdr worktree create --branch <name>`), which also registers it as a
# workspace and honours `worktrees.directory` from ~/.config/herdr/config.toml.
#
# This used to also run `git worktree add` into ~/worktrees/frame-<branch>, a
# path that matched none of the worktrees actually in use.
function worktree-setup() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    print "Error: not inside a git worktree" >&2
    return 1
  fi

  pnpm i && pnpm setup:frontend
}

# Link .zed settings from main frame clone into a worktree (personal)
function link-worktree-zed() {
  local source_dir="$HOME/frame/.zed"
  local target_dir="$PWD/.zed"
  local source_settings="$source_dir/settings.json"
  local target_settings="$target_dir/settings.json"

  if [[ ! -f "$source_settings" ]]; then
    print "Error: $source_settings does not exist" >&2
    return 1
  fi

  mkdir -p "$target_dir"

  if [[ -e "$target_settings" && ! -L "$target_settings" ]]; then
    print "Error: $target_settings already exists and is not a symlink" >&2
    return 1
  fi

  ln -sfn "$source_settings" "$target_settings"
  print "Linked $target_settings -> $source_settings"
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                                   PATH                                       ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# GNU Make (use GNU make instead of macOS make)
export PATH="/opt/homebrew/opt/make/libexec/gnubin:$PATH"

# Bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# pnpm
export PNPM_HOME="/Users/shakedhagag/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac
# pnpm end

# Local binaries (CodeRabbit CLI, etc.)
export PATH="$HOME/.local/bin:$PATH"

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                              SHELL INTEGRATIONS                              ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# Node version manager
eval "$(fnm env --use-on-cd)"

# FZF keybindings and completion (guard: re-running stacks zle wrappers)
(( $+functions[fzf-history-widget] )) || eval "$(fzf --zsh)"

# Zoxide (smart cd)
eval "$(zoxide init --cmd cd zsh)"

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                                   PROMPT                                     ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ── Starship prompt ───────────────────────────────────────────────────────────
# Must init before atuin to prevent zle-keymap-select recursion.
# Guards matter: each re-init wraps the same zle widgets again, and every
# reload-zsh deepens the chain until FUNCNEST explodes (the double-ESC error).
(( $+functions[starship_zle-keymap-select] )) || eval "$(starship init zsh)"

# ── Atuin (shell history) ─────────────────────────────────────────────────────
(( $+functions[_atuin_search] )) || eval "$(atuin init zsh)"

# EDITOR=nvim makes zsh 5.9 default to vi keymaps; force emacs-style editing so
# ESC never flips into vi normal mode (which triggers the keymap widgets above).
bindkey -e

# ── Bun completions ───────────────────────────────────────────────────────────
[[ -s "$HOME/.bun/_bun" ]] && source "$HOME/.bun/_bun"

# Pi
export PATH="/Users/shakedhagag/.local/share/fnm/node-versions/v24.12.0/installation/bin:$PATH"

# Vite+ bin (https://viteplus.dev)
. "$HOME/.vite-plus/env"

# pnpm script completions for the frame monorepo (installed by frm)
[ -f "$HOME/.local/share/frm/completions/pnpm.zsh" ] && source "$HOME/.local/share/frm/completions/pnpm.zsh"

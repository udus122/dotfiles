# XDG
export XDG_CONFIG_HOME="$HOME/.config"  # /etc
export XDG_DATA_HOME="$HOME/.local/share"  # /usr/share
export XDG_CACHE_HOME="$HOME/.cache"  # /var/cache
export XDG_STATE_HOME="$HOME/.local/state"  # /var/lib

# zsh
export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME}/zsh"

# homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"

# linux compatible commands
https://gist.github.com/skyzyx/3438280b18e4f7c490db8a2a2ca0b9da
if type brew &> /dev/null; then
    BREW_PREFIX=$(brew --prefix)
    for bindir in "${BREW_PREFIX}/opt/"*"/libexec/gnubin"; do export PATH=$bindir:$PATH; done
    for mandir in "${BREW_PREFIX}/opt/"*"/libexec/gnuman"; do export MANPATH=$mandir:$MANPATH; done
fi

# mise
export PATH="$HOME/.local/share/mise/shims:$PATH"
eval "$(mise activate zsh)"

# krew
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

# poetry
export POETRY_CONFIG_DIR="$XDG_CONFIG_HOME/pypoetry"
export POETRY_DATA_DIR="$XDG_DATA_HOME/pypoetry"
export POETRY_CACHE_DIR="$XDG_CACHE_HOME/pypoetry"

# pnpm
export PNPM_HOME="/Users/yusuda/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
export PATH="/Users/yusuda/.rd/bin:$PATH"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)

# dotfiles
export DOTFILES="$(ghq root)/github.com/udus122/dotfiles"

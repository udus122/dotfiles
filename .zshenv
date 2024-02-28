# XDG
export XDG_CONFIG_HOME="$HOME/.config"  # /etc
export XDG_DATA_HOME="$HOME/.local/share"  # /usr/share
export XDG_CACHE_HOME="$HOME/.cache"  # /var/cache
export XDG_STATE_HOME="$HOME/.local/state"  # /var/lib

# zsh
export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME}/zsh"

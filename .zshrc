# homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"
# mise
eval "$(mise activate zsh)"
export PATH="$HOME/.local/share/mise/shims:$PATH"

# completion
autoload -Uz compinit
compinit

# abbr: https://github.com/olets/zsh-abbr
source /opt/homebrew/share/zsh-abbr/zsh-abbr.zsh
abbr -S g='git'
abbr -S k='kubectl'
abbr -S l='ls -FG'
abbr -S la='ls -FGa'
abbr -S ll='ls -FGl'
abbr -S lla='ls -FGla'
abbr -S r="mise run --"
abbr -S x="mise exec --"

# path
### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
export PATH="/Users/yusuda/.rd/bin:$PATH"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)
# XDG
export XDG_CONFIG_HOME="$HOME/.config"
# Java
# export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"

# fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# find-ghq - select local repository
if type "ghq" > /dev/null 2>&1; then
  function find-ghq () {
    declare -r REPO_NAME="$(ghq list | fzf )";
    [[ -n "${REPO_NAME}" ]] && cd "$(ghq root)/${REPO_NAME}" && exec -l "${SHELL}";
  }
  alias fgh='find-ghq; : select local repository'
fi

# pnpm
export PNPM_HOME="/Users/yusuda/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# rust
source "$HOME/.cargo/env"

# kubernetes
source <(kubectl completion zsh)

# history
## 保存する履歴の数
SAVEHIST=10000
## 履歴をインクリメンタルに追加
setopt inc_append_history
## historyに追加されるコマンド行が古いものと同じなら古いものを削除
setopt hist_ignore_all_dups
## ヒストリを呼び出してから実行する間に一旦編集可能
setopt hist_verify
## 余分な空白は詰めて記録
setopt hist_reduce_blanks 
## 古いコマンドと同じものは無視 
setopt hist_save_no_dups
## ヒストリに追加されるコマンド行が古いものと同じなら古いものを削除
setopt hist_ignore_all_dups

# starship
eval "$(starship init zsh)"

# Warp
# For zsh subshells, add to ~/.zshrc.
printf '\eP$f{"hook": "SourcedRcFileForWarp", "value": { "shell": "zsh"}}\x9c'

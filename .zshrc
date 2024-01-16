# homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"
# mise
eval "$(mise activate zsh)"
export PATH="$HOME/.local/share/mise/shims:$PATH"

# completion
if type brew &>/dev/null; then
  FPATH=$(brew --prefix)/share/zsh-completions:$FPATH
  source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
  autoload -Uz compinit
  compinit
fi

# 補完後、メニュー選択モードになり左右キーで移動が出来る
zstyle ':completion:*:default' menu select=2
# 補完で大文字にもマッチ
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
# 補完候補の色づけ
export LS_COLORS='di=34:ln=35:so=32:pi=33:ex=31:bd=46;34:cd=43;34:su=41;30:sg=46;30:tw=42;30:ow=43;30'
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}

# abbr: https://github.com/olets/zsh-abbr
source $(brew --prefix)/share/zsh-abbr/zsh-abbr.zsh
abbr -S g='git' > /dev/null
abbr -S t="tmux" > /dev/null
abbr -S k='kubectl' > /dev/null
abbr -S l='ls -FG' > /dev/null
abbr -S la='ls -FGa' > /dev/null
abbr -S ll='ls -FGl' > /dev/null
abbr -S lla='ls -FGla' > /dev/null
abbr -S r="mise run --" > /dev/null
abbr -S x="mise exec --" > /dev/null
abbr -S reload="exec -l $SHELL" > /dev/null

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
HISTFILE=$HOME/.zsh-history
# メモリに保存される履歴の数
HISTSIZE=10000
## ファイルに保存する履歴の数
SAVEHIST=100000
## 履歴をインクリメンタルに追加
# setopt inc_append_history  # share_historyと同時に設定してはいけないため、コメントアウト
## コマンド履歴ファイルを共有する
setopt share_history
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

# directory move
setopt auto_cd
setopt auto_pushd
setopt pushd_ignore_dups

# starship
eval "$(starship init zsh)"

# Warp
# For zsh subshells, add to ~/.zshrc.
printf '\eP$f{"hook": "SourcedRcFileForWarp", "value": { "shell": "zsh"}}\x9c'

# Automatic startup of tmux
if [[ ! -n $TMUX && $- == *l* ]]; then
  # get the IDs
  ID=$(tmux list-sessions)
  if [[ -z "$ID" ]]; then
    tmux new-session
  fi
  create_new_session="Create New Session"
  ID="$ID\n${create_new_session}:"
  ID="`echo $ID | fzf | cut -d: -f1`"
  if [[ "$ID" = "${create_new_session}" ]]; then
    tmux new-session
  elif [[ -n "$ID" ]]; then
    tmux attach-session -t "$ID"
  else
    :  # Start terminal normally
  fi
fi
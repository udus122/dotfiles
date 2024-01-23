# path
### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
export PATH="/Users/yusuda/.rd/bin:$PATH"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)
# homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"
# XDG
export XDG_CONFIG_HOME="$HOME/.config"
# dotfiles
export DOTFILES="$(ghq root)/github.com/udus122/dotfiles"
# mise
export PATH="$HOME/.local/share/mise/shims:$PATH"
eval "$(mise activate zsh)"

# linux compatible commands
# https://gist.github.com/skyzyx/3438280b18e4f7c490db8a2a2ca0b9da
if type brew &> /dev/null; then
    BREW_PREFIX=$(brew --prefix)
    for bindir in "${BREW_PREFIX}/opt/"*"/libexec/gnubin"; do export PATH=$bindir:$PATH; done
    for mandir in "${BREW_PREFIX}/opt/"*"/libexec/gnuman"; do export MANPATH=$mandir:$MANPATH; done
fi

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

alias vi='nvim'
alias vim='nvim'
# abbr: https://github.com/olets/zsh-abbr
source $(brew --prefix)/share/zsh-abbr/zsh-abbr.zsh
abbr -S g='git' > /dev/null
abbr -S t="tmux" > /dev/null
abbr -S k='kubectl' > /dev/null
abbr -S kg='kubectl get' > /dev/null
abbr -S kcuc='kubectl config use-context' > /dev/null
abbr -S kcgc='kubectl config get-contexts' > /dev/null
abbr -S kcv='kubectl config view' > /dev/null
abbr -S l='ls -FG' > /dev/null
abbr -S la='ls -FGa' > /dev/null
abbr -S ll='ls -FGl' > /dev/null
abbr -S lla='ls -FGla' > /dev/null
abbr -S r="mise run --" > /dev/null
abbr -S x="mise exec --" > /dev/null
abbr -S reload="exec -l $SHELL" > /dev/null
abbr -S edot="${EDITOR:-vim} $DOTFILES" > /dev/null

# Function to perform simple arithmetic operations using awk
function calc() {
  awk "BEGIN {print $*}"
}

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

# gcloud
source "$(mise where gcloud)/path.zsh.inc"
source "$(mise where gcloud)/completion.zsh.inc"

# awscli
complete -C "$(mise where awscli)/aws_completer" aws

# Warp
# For zsh subshells, add to ~/.zshrc.
printf '\eP$f{"hook": "SourcedRcFileForWarp", "value": { "shell": "zsh"}}\x9c'

# Automatic startup of tmux
if [[ ! -n $TMUX && $- == *l* ]]; then
  # Retrieves the terminal being used, stored in the TERM_PROGRAM variable or as a fallback, the TERM variable
  TP=${TERM_PROGRAM:-$TERM}
  # get the session id
  SS=$(tmux list-sessions)
  if [[ -z "$SS" ]]; then
    tmux new-session -s $TP
  fi
  create_new_session="Create New Session"
  SS="$SS\n${create_new_session}:"
  SS="`echo $SS | fzf | cut -d: -f1`"
  if [[ "$SS" = "${create_new_session}" ]]; then
    tmux new-session -s $TP
  elif [[ -n "$SS" ]]; then
    tmux attach-session -s "$SS"
  else
    :  # Start terminal normally
  fi
fi

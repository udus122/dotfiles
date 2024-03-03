# ref. https://qiita.com/P-man_Brown/items/1959e7ac8c51ed5d619e
export PS4='+[%D{%H:%M:%S}]%1N:%i> '
# homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"
# linux compatible commands. ref: https://gist.github.com/skyzyx/3438280b18e4f7c490db8a2a2ca0b9da
if type brew &> /dev/null; then
  BREW_PREFIX=$(brew --prefix)
  for bindir in "${BREW_PREFIX}/opt/"*"/libexec/gnubin"; do export PATH=$bindir:$PATH; done
  for mandir in "${BREW_PREFIX}/opt/"*"/libexec/gnuman"; do export MANPATH=$mandir:$MANPATH; done
fi

# less
export LESS='-i -M -R'

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

# history
HISTFILE="$ZDOTDIR/history"  # ヒストリファイルの保存先
HISTSIZE=10000  # メモリに保存される履歴の数
SAVEHIST=100000  # ファイルに保存する履歴の数

setopt share_history  # コマンド履歴ファイルを共有する
setopt hist_ignore_all_dups  # historyに追加されるコマンド行が古いものと同じなら古いものを削除
setopt hist_verify  # ヒストリを呼び出してから実行する間に一旦編集可能
setopt hist_reduce_blanks  # 余分な空白は詰めて記録
setopt hist_save_no_dups  # 古いコマンドと同じものは無視
setopt hist_ignore_all_dups  # ヒストリに追加されるコマンド行が古いものと同じなら古いものを削除

# directory move
setopt auto_cd
setopt auto_pushd
setopt pushd_ignore_dups

# starship
eval "$(starship init zsh)"

# completion
autoload -Uz compinit
compinit
autoload -U bashcompinit
bashcompinit
if type brew &>/dev/null; then
  FPATH=$(brew --prefix)/share/zsh-completions:$FPATH
  source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

zstyle ':completion:*:default' menu select=2  # 補完後、メニュー選択モードになり左右キーで移動が出来る
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'  # 補完で大文字にもマッチ
# 補完候補の色づけ
export LS_COLORS='di=34:ln=35:so=32:pi=33:ex=31:bd=46;34:cd=43;34:su=41;30:sg=46;30:tw=42;30:ow=43;30'
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}

# mise
mise completion zsh > "${fpath[1]}/_mise" && compinit

# docker
source <(docker completion zsh)

# kubectl
source <(kubectl completion zsh)

# stern
source <(stern --completion=zsh)

# kind
kind completion zsh > "${fpath[1]}/_kind" && compinit

# terraform
complete -C terraform terraform

# gcloud
source "$(mise where gcloud)/path.zsh.inc"
source "$(mise where gcloud)/completion.zsh.inc"

# awscli
complete -C "$(mise where awscli)/aws_completer" aws

# fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# aliases
alias vi='nvim'
alias vim='nvim'

# abbreviations
# zsh-abbr: https://github.com/olets/zsh-abbr
source $(brew --prefix)/share/zsh-abbr/zsh-abbr.zsh
source ${ZDOTDIR}/abbreviations.zsh

# utility functions
source ${ZDOTDIR}/functions.zsh

# # Automatic startup of tmux
# if [[ ! -n $TMUX && $- == *l* ]]; then
#   # Retrieves the terminal being used, stored in the TERM_PROGRAM variable or as a fallback, the TERM variable
#   TP=${TERM_PROGRAM:-$TERM}
#   # get the session id
#   SS=$(tmux list-sessions)
#   if [[ -z "$SS" ]]; then
#     tmux new-session -s $TP
#   fi
#   create_new_session="Create New Session"
#   SS="$SS\n${create_new_session}:"
#   SS="`echo $SS | fzf | cut -d: -f1`"
#   if [[ "$SS" = "${create_new_session}" ]]; then
#     tmux new-session -s $TP
#   elif [[ -n "$SS" ]]; then
#     tmux attach-session -s "$SS"
#   else
#     :  # Start terminal normally
#   fi
# fi

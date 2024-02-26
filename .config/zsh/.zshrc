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

# docker
source <(docker completion zsh)

# kubectl
source <(kubectl completion zsh)

# stern
source <(stern --completion=zsh)

# kind
kind completion zsh > "${fpath[1]}/_kind" && compinit

# terraform
if type terraform &> /dev/null; then
  complete -C terraform terraform
fi

# gcloud
source "$(mise where gcloud)/path.zsh.inc"
source "$(mise where gcloud)/completion.zsh.inc"

# awscli
complete -C "$(mise where awscli)/aws_completer" aws

# aliases
alias vi='nvim'
alias vim='nvim'
# abbreviations
# zsh-abbr: https://github.com/olets/zsh-abbr
source $(brew --prefix)/share/zsh-abbr/zsh-abbr.zsh
source ${ZDOTDIR}/abbreviations

# Function to perform simple arithmetic operations using awk
function calc() {
  awk "BEGIN {print $*}"
}

# fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

if type "ghq" > /dev/null 2>&1; then
  function find-ghq () {
    # select local repository in ghq
    declare -r REPO_NAME="$(ghq list | fzf )";
    [[ -n "${REPO_NAME}" ]] && cd "$(ghq root)/${REPO_NAME}" && exec -l "${SHELL}";
  }
  alias fgh=find-ghq
  
  function gx() {
    input_name="$1"
    if [ -z "$input_name" ]; then
      line=$(gcloud config configurations list | fzf --header-lines=1)
    else
      line=$(gcloud config configurations list | grep "$input_name")
    fi
    name=$(echo "${line}" | awk '{print $1}')
    project=$(echo "${line}" | awk '{print $4}')
    echo "gcloud config configurations activate \"${name}\""
    gcloud auth application-default set-quota-project "${name}"
    gcloud config configurations activate "${name}"
  }

  function gx-complete() {
    _values $(gcloud config configurations list | awk '{print $1}')
  }
  compdef gx-complete gx
fi

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

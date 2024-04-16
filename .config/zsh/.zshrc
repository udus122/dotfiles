function source {
  ensure_zcompiled $1
  builtin source $1
}

function ensure_zcompiled {
  local compiled="$1.zwc"
  if [[ ! -r "$compiled" || "$1" -nt "$compiled" ]]; then
    echo "Compiling $1"
    zcompile $1
  fi
}

ensure_zcompiled "${ZDOTDIR}/.zshrc"

# PATHの重複を防ぐ
typeset -U PATH

# homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"

# linux compatible commands. ref: https://gist.github.com/skyzyx/3438280b18e4f7c490db8a2a2ca0b9da
if type brew &> /dev/null; then
  BREW_PREFIX=$(brew --prefix)
  for bindir in "${BREW_PREFIX}/opt/"*"/libexec/gnubin"; do export PATH="$bindir:$PATH"; done
  for mandir in "${BREW_PREFIX}/opt/"*"/libexec/gnuman"; do export MANPATH="$mandir:$MANPATH"; done
fi

export PATH="$HOME/.local/bin:$PATH"  # User-specific executable files

# keybindings(widgets)
# NOTICE: Depending on the order of bindkeys, behavior may be strange, so call it early
source ${ZDOTDIR}/keybindings.zsh

# direnv
eval "$(direnv hook zsh)"

# mise
export PATH="$HOME/.local/share/mise/shims:$PATH"
eval "$(mise activate zsh)"

# krew
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

# poetry
export POETRY_CONFIG_DIR="$XDG_CONFIG_HOME/pypoetry"
export POETRY_DATA_DIR="$XDG_DATA_HOME/pypoetry"
export POETRY_CACHE_DIR="$XDG_CACHE_HOME/pypoetry"

# less
export LESS='-iMNRS'

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

## 実行したプロセスの消費時間が3秒以上かかったら
## 自動的に消費時間の統計情報を表示する。
REPORTTIME=3

## 「/」も単語区切りとみなす。
WORDCHARS=${WORDCHARS:s,/,,}

# directory move
setopt auto_cd
setopt auto_pushd
setopt pushd_ignore_dups

# fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
bindkey 'ç' fzf-cd-widget
export FZF_ALT_C_OPTS="--preview 'tree -C {} | head -200'"

# starship
eval "$(starship init zsh)"

# completion
source "${ZDOTDIR}/completion.zsh"

# aliases
alias vi='nvim'
alias vim='nvim'

# abbreviations
# zsh-abbr: https://github.com/olets/zsh-abbr
source $(brew --prefix)/share/zsh-abbr/zsh-abbr.zsh
source ${ZDOTDIR}/abbreviations.zsh

# cheatsheet(navi)
# ref: https://github.com/denisidoro/navi
eval "$(navi widget zsh)"
# Change the key assignments for navi widget
bindkey -r "^g" # default
bindkey '^g^g' _navi_widget # custom

# utility functions
source ${ZDOTDIR}/functions.zsh

# OSC 133: https://gitlab.freedesktop.org/Per_Bothner/specifications/blob/master/proposals/semantic-prompts.md
# https://gitlab.freedesktop.org/Per_Bothner/specifications/-/blob/master/proposals/prompts-data/shell-integration.zsh
_prompt_executing=""
function __prompt_precmd() {
    local ret="$?"
    if test "$_prompt_executing" != "0"
    then
      _PROMPT_SAVE_PS1="$PS1"
      _PROMPT_SAVE_PS2="$PS2"
      PS1=$'%{\e]133;P;k=i\a%}'$PS1$'%{\e]133;B\a\e]122;> \a%}'
      PS2=$'%{\e]133;P;k=s\a%}'$PS2$'%{\e]133;B\a%}'
    fi
    if test "$_prompt_executing" != ""
    then
       printf "\033]133;D;%s;aid=%s\007" "$ret" "$$"
    fi
    printf "\033]133;A;cl=m;aid=%s\007" "$$"
    _prompt_executing=0
}
function __prompt_preexec() {
    PS1="$_PROMPT_SAVE_PS1"
    PS2="$_PROMPT_SAVE_PS2"
    printf "\033]133;C;\007"
    _prompt_executing=1
}
preexec_functions+=(__prompt_preexec)
precmd_functions+=(__prompt_precmd)

unfunction source

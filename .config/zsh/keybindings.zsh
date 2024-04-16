# use zle in vi mode
bindkey -v

# define useful commands for emacs mode
# https://web.archive.org/web/20220601005625/https://qiita.com/b4b4r07/items/8db0257d2e6f6b19ecb9#viins-%E3%81%A8-emacs
bindkey -M viins '\er' history-incremental-pattern-search-forward
bindkey -M viins '^?' backward-delete-char
bindkey -M viins '^A' beginning-of-line
bindkey -M viins '^B' backward-char
bindkey -M viins 'jj' vi-cmd-mode
bindkey -M viins '^D' delete-char-or-list
bindkey -M viins '^E' end-of-line
bindkey -M viins '^F' forward-char
bindkey -M viins '^G' send-break
bindkey -M viins '^H' backward-delete-char
bindkey -M viins '^K' kill-line
bindkey -M viins '^N' down-line-or-history
bindkey -M viins '^P' up-line-or-history
bindkey -M viins '^R' history-incremental-pattern-search-backward
bindkey -M viins '^U' backward-kill-line
bindkey -M viins '^W' backward-kill-word
# bindkey -M viins '^Y' yank
bindkey -M vicmd 'gg' beginning-of-line
bindkey -M vicmd 'G'  end-of-line

# Go to the end of the line and type "| less"
# ref. https://gihyo.jp/dev/serial/01/zsh-book/0003
# bindkey -s '^X^L' "^E|less^M"
bindkey -s '^X^L' "^E | less"

# ref. https://mollifier.hatenablog.com/entry/20090414/1239634907
# ctrl+x ctrl+u to undo
bindkey "^X^U" undo
# ctrl+x ctrl+r to redo
bindkey "^X^R" redo
# ctrl+j Insert a newline in the command line
bindkey '^J' self-insert-unmeta

# ^Yで現在位置から左のスペースまでをkillする
# ref. https://mollifier.hatenablog.com/entry/20081214/1229229752
function _kill-backward-blank-word() {
  zle set-mark-command
  zle vi-backward-blank-word
  zle kill-region
}
zle -N _kill-backward-blank-word
bindkey '^Y' _kill-backward-blank-word

# ----------------------------------------------------
# shift+arrowでディレクトリを便利に移動する
# ref. https://qiita.com/sfuta/items/a72f7bd194a61353c9fe
# hook関数precmd実行
__call_precmds() {
  type precmd > /dev/null 2>&1 && precmd
  for __pre_func in $precmd_functions; do $__pre_func; done
}
# shift+upで親ディレクトリへ
__cd_up() {
  builtin pushd ..
  __call_precmds
  zle reset-prompt
}
zle -N __cd_up
bindkey '^[[1;2A' __cd_up

# shift+downで戻る
__cd_undo() {
  builtin popd
  __call_precmds
  zle reset-prompt
}
zle -N __cd_undo
bindkey '^[[1;2B' __cd_undo

# shift+leftで履歴から移動先のディレクトリを選択する
__cd_hist_fzf() {
  local target_dir=$(dirs -v | awk '{ print $2 }' | fzf)
  cd $(realpath ${target_dir/#\~/$HOME})
  __call_precmds
  zle reset-prompt
}
zle -N __cd_hist_fzf
bindkey '^[[1;2D' __cd_hist_fzf

# shift+rightでfzf-cd-widgetを呼び出す
# カレントディレクトリから選択して移動
bindkey '^[[1;2C' fzf-cd-widget
# ---------------------------------------------------

# git関連

# ctrl+g ctrl+wでブランチ切り替え
# ref. https://zenn.dev/yamo/articles/5c90852c9c64ab
__git_sw() {
  target_br=$(
    git branch -a |
      fzf --exit-0 --layout=reverse --info=hidden --no-multi --preview-window="right,65%" --prompt="CHECKOUT BRANCH > " --preview="echo {} | tr -d ' *' | xargs git log --graph --decorate --abbrev-commit --format=format:'%C(blue)%h%C(reset) - %C(green)(%ar)%C(reset)%C(yellow)%d%C(reset)\n  %C(white)%s%C(reset) %C(dim white)- %an%C(reset)' --color=always" |
      head -n 1 |
      perl -pe "s/\s//g; s/\*//g; s/remotes\/origin\///g"
  )
  if [ -n "$target_br" ]; then
    BUFFER="git switch $target_br"
    zle accept-line
  fi
}
zle -N __git_sw
bindkey -r '^g^w'
bindkey '^g^w' __git_sw

# ctrl+g ctrl+sでgit status
__git_status() {
  if [ "$(git rev-parse --is-inside-work-tree 2> /dev/null)" = 'true' ]; then
    echo git status -sb # git statusを実行したっぽくみせかける
    git status -sb
  fi
  zle accept-line
}
zle -N __git_status  # _git_status関数をgit_status widgetとして登録
bindkey '^G^S' __git_status

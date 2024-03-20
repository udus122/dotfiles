autoload -Uz compinit && compinit
autoload -U bashcompinit && bashcompinit

if type brew &>/dev/null; then
  FPATH=$(brew --prefix)/share/zsh-completions:$FPATH
  source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

USER_COMPLETION_DIR="$XDG_DATA_HOME/zsh/completion"
mkdir -p "$USER_COMPLETION_DIR"
fpath=("$USER_COMPLETION_DIR" $fpath)


zstyle ':completion:*:default' menu select=2  # 補完後、メニュー選択モードになり左右キーで移動が出来る
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'  # 補完で大文字にもマッチ

# 補完候補の色づけ
export LS_COLORS='di=34:ln=35:so=32:pi=33:ex=31:bd=46;34:cd=43;34:su=41;30:sg=46;30:tw=42;30:ow=43;30'
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}

# mise
mise completion zsh > "${USER_COMPLETION_DIR}/_mise" && compinit

# docker
source <(docker completion zsh)

# kubectl
source <(kubectl completion zsh)

# stern
source <(stern --completion=zsh)

# kind
kind completion zsh > "${USER_COMPLETION_DIR}/_kind" && compinit

# terraform
complete -C terraform terraform

# gcloud
source "$(mise where gcloud)/path.zsh.inc"
source "$(mise where gcloud)/completion.zsh.inc"

# awscli
complete -C "$(mise where awscli)/aws_completer" aws

# lima
source <(limactl completion zsh)

# github cli
gh completion -s zsh > "${USER_COMPLETION_DIR}/_gh" && compinit

# Function to perform simple arithmetic operations using awk
function calc() {
  awk "BEGIN {print $*}"
}

# git
function git-fixup() {
  FILTER=${FILTER:-fzf}
  MAX_LOG_COUNT=${MAX_LOG_COUNT:-30}

  if git diff --cached --quiet; then
      commits="No staged changes. Use git add -p to add them."
      ret=1
  else
      commits=$(git log --oneline -n "$MAX_LOG_COUNT")
      ret=$?
  fi

  if [[ "$ret" != 0 ]]; then
      headline=$(echo "$commits" | head -n1)
      if [[ "$headline" = "No staged changes. Use git add -p to add them." ]]; then
          echo "$headline" >&2
      fi
      return "$ret"
  fi

  line=$(echo "$commits" | $FILTER)
  [[ "$?" = 0 && "$line" != "" ]] || return "$?"

  git commit --fixup "$( echo "$line" | awk '{print $1}' )" "$@"
}
# FIXME: gitの補完が効かなくなるため、一時的に無効化する
# ref: https://masawada.hatenablog.jp/entry/2021/10/08/103000
# function git-wrapper() {
#     if [[ $1 == 'fixup' ]]; then
#       shift 1
#       git-fixup
#     else
#       command git "$@"
#     fi
# }
# alias git='git-wrapper'

function find-ghq () {
  # select local repository in ghq
  declare -r REPO_NAME="$(ghq list | fzf )";
  [[ -n "${REPO_NAME}" ]] && cd "$(ghq root)/${REPO_NAME}" && exec -l "${SHELL}";
}
alias fgh=find-ghq

# gcloud
function safe-gcloud() {
    local active_config=$(cat $HOME/.config/gcloud/active_config)
    if [[ $active_config == *"prd"* ]]; then
        echo -n "You're in a production environment. Are you sure you want to proceed (Y/yes): "
        read REPLY
        if [[ $REPLY =~ ^([Yy]|[Yy]es)$ ]]; then
            command gcloud "$@"
        else
            echo "Aborted!"
        fi
    else
        command gcloud "$@"
    fi
}
complete -o nospace -o default -F _python_argcomplete "safe-gcloud"
alias gcloud='safe-gcloud'

function gx() {
  input_name="$1"
  if [ -z "$input_name" ]; then
    line=$(command gcloud config configurations list | fzf --header-lines=1)
  else
    line=$(command gcloud config configurations list | grep "$input_name")
  fi
  name=$(echo "${line}" | awk '{print $1}')
  project=$(echo "${line}" | awk '{print $4}')
  echo "gcloud config configurations activate \"${name}\""
  command gcloud auth application-default set-quota-project "${name}"
  command gcloud config configurations activate "${name}"
}

function gx-complete() {
  _values $(command gcloud config configurations list | awk '{print $1}')
}
compdef gx-complete gx

function create-gcloud-config() {
  # 設定名を入力
  echo -n "Enter configuration name: "
  read config_name

  # プロジェクトIDを入力
  echo -n "Enter your project ID: "
  read project_id

  # アカウントを入力
  echo -n "Enter your account: "
  read account

  # gcloud configurationを作成
  command gcloud config configurations create "${config_name}"
  
  # accountとproject IDを設定
  command gcloud config set account "${account}"
  command gcloud config set project "${project_id}"
}

function safe-kubectl() {
    local current_context=$(command kubectl config current-context)
    if [[ $current_context == *"prd"* ]]; then
        echo -n "You're in a production context. If you want to continue, type y(es) and press Enter: "
        read REPLY
        if [[ $REPLY =~ ^([Yy]|[Yy]es)$ ]]; then
            command kubectl "$@"
        else
            echo "Aborted!"
        fi
    else
        command kubectl "$@"
    fi
}
compdef _kubectl safe-kubectl
alias kubectl='safe-kubectl'

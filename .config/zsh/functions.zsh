# Function to perform simple arithmetic operations using awk
function calc() {
  awk "BEGIN {print $*}"
}

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
  gcloud config configurations create "${config_name}"
  
  # accountとproject IDを設定
  gcloud config set account "${account}"
  gcloud config set project "${project_id}"
}

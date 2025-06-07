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

function gcloud-config-create-set-project-account() {
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

function kubectl-less () {
    if [[ -t 1 ]]
    then
        command kubectl "$@" | less -F -X -n
    else
        command kubectl "$@"
    fi
}

function safe-kubectl() {
    local current_context=$(command kubectl config current-context)
    if [[ $current_context == *"prd"* ]]; then
        echo -n "You're in a production context. If you want to continue, type y(es) and press Enter: "
        read REPLY
        if [[ $REPLY =~ ^([Yy]|[Yy]es)$ ]]; then
            kubectl-less "$@"
        else
            echo "Aborted!"
        fi
    else
        kubectl-less "$@"
    fi
}
compdef _kubectl safe-kubectl
# alias kubectl='safe-kubectl'  # 2024-10-21: Fig(Amazon Q)を使いたいため使わない

create_branch_with_guide() {
  selected_option=$(cat <<EOF | fzf
new: 本番提供前の0 → 1の新規開発
feature: 既存システムへの機能追加・仕様変更に伴う実装の変更
update: 既存システムについて、仕様変更を伴わない実装の改善
replace: 実装の変更を伴わない、既存パラメータや環境変数等の値の変更
clean: 既存システムについて、実装の変更を伴わないコードの改善
chore: 既存システムへの影響がない独立した対応
verify: 技術検証
hotfix: 変更障害（意図していなかった挙動の発生）に対する修正
fix: 些細な変更障害に対する修正
EOF
  )

  selected_branch=$(echo "$selected_option" | cut -d':' -f1)
  echo -n "Enter the branch name: "
  read name
  branch_name="${selected_branch}/${name}"
  git branch "${branch_name}"
  git switch "${branch_name}"
}

alias gn='create_branch_with_guide'

# ref. https://sushichan044.hateblo.jp/entry/2025/06/06/003325
function fzf-worktree() {
    # Format of `git worktree list`: path commit [branch]
    local selected_worktree=$(git worktree list | fzf \
        --prompt="worktrees > " \
        --header="Select a worktree to cd into" \
        --preview="echo '📦 Branch:' && git -C {1} branch --show-current && echo '' && echo '📝 Changed files:' && git -C {1} status --porcelain | head -10 && echo '' && echo '📚 Recent commits:' && git -C {1} log --oneline --decorate -10" \
        --preview-window="right:40%" \
        --reverse \
        --border \
        --ansi)

    if [ $? -ne 0 ]; then
        return 0
    fi

    if [ -n "$selected_worktree" ]; then
        local selected_path=${${(s: :)selected_worktree}[1]}

        if [ -d "$selected_path" ]; then
            if zle; then
                # Called from ZLE (keyboard shortcut)
                BUFFER="cd ${selected_path}"
                zle accept-line
            else
                # Called directly from command line
                cd "$selected_path"
            fi
        else
            echo "Directory not found: $selected_path"
            return 1
        fi
    fi

    # Only clear screen if ZLE is active
    if zle; then
        zle clear-screen
    fi
}

zle -N fzf-worktree
bindkey '^n' fzf-worktree

# Amazon Q pre block. Keep at the top of this file.
[[ -f "${HOME}/Library/Application Support/amazon-q/shell/bashrc.pre.bash" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/bashrc.pre.bash"
# homebrew
eval "$(/opt/homebrew/bin/brew shellenv)

# starship
eval "$(starship init bash)"

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/usuda.yudai/.lmstudio/bin"
# End of LM Studio CLI section

# Amazon Q post block. Keep at the bottom of this file.
[[ -f "${HOME}/Library/Application Support/amazon-q/shell/bashrc.post.bash" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/bashrc.post.bash"

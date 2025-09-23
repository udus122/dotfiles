# abbr: https://github.com/olets/zsh-abbr

abbr -S 'd'='docker' > /dev/null 2>&1
abbr -S 'g'='git' > /dev/null 2>&1
abbr -S 'gst'='git status' > /dev/null 2>&1
abbr -S 't'="tmux" > /dev/null 2>&1
abbr -S 'tf'="terraform" > /dev/null 2>&1
abbr -S 'k'='kubectl' > /dev/null 2>&1
abbr -S 'kc'='kubectl config' > /dev/null 2>&1
abbr -S 'kubectl c'='kubectl config' > /dev/null 2>&1
abbr -S 'kubectl d'='kubectl describe' > /dev/null 2>&1
abbr -S 'kubectl g'='kubectl get' > /dev/null 2>&1
abbr -S 'kd'='kubectl describe' > /dev/null 2>&1
abbr -S 'kg'='kubectl get' > /dev/null 2>&1
abbr -S 'kcuc'='kubectl config use-context' > /dev/null 2>&1
abbr -S 'kcgc'='kubectl config get-contexts' > /dev/null 2>&1
abbr -S 'kcv'='kubectl config view' > /dev/null 2>&1
abbr -S 'kb'='kubie' > /dev/null 2>&1
abbr -S 'kx'='kubie ctx' > /dev/null 2>&1
abbr -S 'kn'='kubens' > /dev/null 2>&1
abbr -S 'gc'='gcloud' > /dev/null 2>&1
abbr -S 'gccl'='gcloud config configurations list' > /dev/null 2>&1
abbr -S 'gco'='open "https://console.cloud.google.com/home/dashboard?project=$(gcloud config get-value project)"' > /dev/null 2>&1
abbr -S 'l'='ls -F --color=auto' > /dev/null 2>&1
abbr -S 'la'='ls -FA --color=auto' > /dev/null 2>&1
abbr -S 'll'='ls -Fl --color=auto' > /dev/null 2>&1
abbr -S 'lla'='ls -FlA --color=auto' > /dev/null 2>&1
abbr -S 'r'="mise run --" > /dev/null 2>&1
abbr -S 'x'="mise exec --" > /dev/null 2>&1
abbr -S 'reload'="exec -l $SHELL" > /dev/null 2>&1
abbr -S 'login-docker-for-mac-vm'="docker run -it --rm --privileged --pid=host justincormack/nsenter1" > /dev/null 2>&1 # https://gist.github.com/BretFisher/5e1a0c7bcca4c735e716abf62afad389 
abbr -S 'cl'='claude' > /dev/null 2>&1

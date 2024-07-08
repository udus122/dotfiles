# abbr: https://github.com/olets/zsh-abbr

abbr -S 'd'='docker' > /dev/null
abbr -S 'g'='git' > /dev/null
abbr -S 'gst'='git status' > /dev/null
abbr -S 't'="tmux" > /dev/null
abbr -S 'tf'="terraform" > /dev/null
abbr -S 'k'='kubectl' > /dev/null
abbr -S 'kc'='kubectl config' > /dev/null
abbr -S 'kubectl c'='kubectl config' > /dev/null
abbr -S 'kubectl d'='kubectl describe' > /dev/null
abbr -S 'kubectl g'='kubectl get' > /dev/null
abbr -S 'kd'='kubectl describe' > /dev/null
abbr -S 'kg'='kubectl get' > /dev/null
abbr -S 'kcuc'='kubectl config use-context' > /dev/null
abbr -S 'kcgc'='kubectl config get-contexts' > /dev/null
abbr -S 'kcv'='kubectl config view' > /dev/null
abbr -S 'kx'='kubectx' > /dev/null
abbr -S 'kn'='kubens' > /dev/null
abbr -S 'gc'='gcloud' > /dev/null
abbr -S 'gccl'='gcloud config configurations list' > /dev/null
abbr -S 'gco'='open "https://console.cloud.google.com/home/dashboard?project=$(gcloud config get-value project)"' > /dev/null
abbr -S 'l'='ls -F --color=auto' > /dev/null
abbr -S 'la'='ls -FA --color=auto' > /dev/null
abbr -S 'll'='ls -Fl --color=auto' > /dev/null
abbr -S 'lla'='ls -FlA --color=auto' > /dev/null
abbr -S 'r'="mise run --" > /dev/null
abbr -S 'x'="mise exec --" > /dev/null
abbr -S 'reload'="exec -l $SHELL" > /dev/null
abbr -S 'login-docker-for-mac-vm'="docker run -it --rm --privileged --pid=host justincormack/nsenter1" > /dev/null  # https://gist.github.com/BretFisher/5e1a0c7bcca4c735e716abf62afad389

#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title sync logs
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🤖

# Documentation:
# @raycast.description udus122/logsからpull/pushを行う
# @raycast.author udus
# @raycast.authorURL https://raycast.com/udus

cd ~/ghq/github.com/udus122/logs || exit

git pull --rebase origin main
git add -A
git commit -m "backup"
git push origin main

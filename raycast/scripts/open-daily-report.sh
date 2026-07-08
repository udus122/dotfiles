#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title 日報を開く
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 📋
# @raycast.packageName knowledge

# Documentation:
# @raycast.description 最新の作業日報 (work-report.md) を Obsidian で開く

KNOWLEDGE_DIR="$HOME/knowledge"
VAULT="knowledge"

# 今日から8日分さかのぼり、最初に見つかった日報を開く
# (通常は前日分。スケジュールタスクが数日止まっていても最新に届く)
for date in $(/usr/bin/python3 -c 'from datetime import date, timedelta
for i in range(8):
    print((date.today() - timedelta(days=i)).isoformat())'); do
    rel="journals/daily/$date/work-report.md"
    if [[ -f "$KNOWLEDGE_DIR/$rel" ]]; then
        encoded=$(/usr/bin/python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$rel")
        open "obsidian://open?vault=$VAULT&file=$encoded"
        echo "$date の日報を開きました"
        exit 0
    fi
done

echo "直近8日分の日報が見つかりません"
exit 1

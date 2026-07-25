# 日次

その日のセッション記録を読んで起票し、そのあとバックログを消化する。
**起票を先に済ませてから消化に入る。** 消化が長引いても、その日の回収が失われないため。

## 0. 対象期間を決める

```bash
S=~/.claude/skills/ops-cycle/scripts
KEY="daily-$(basename "$PWD")"
SINCE=$($S/sessions.sh since "$KEY" 1)     # 前回実行時刻(ms)。初回は24時間前
NOW=$(( $(date +%s) * 1000 ))
```

`SINCE` より後のセッション記録だけを対象にする。同じ日に2回実行しても
二重に起票しないのは、この範囲指定と最後の `mark` による。

## 1. セッション記録を読む

```bash
$S/sessions.sh prompts "$PWD" "$SINCE"     # ユーザ発話 (JSONL)
$S/sessions.sh ids     "$PWD" "$SINCE"     # 対象セッション ID
$S/sessions.sh replies <session_id>        # そのセッションの地の文（ツール結果は除く）
```

まず `prompts` を全部読む。1行が1発話で軽い。ここで拾えなかった文脈が要るときだけ、
該当セッションの `replies` を引く。**生のトランスクリプトを直接開かないこと**
（1本が数 MB あり、読み切れない）。

## 2. 2種類を取り出す

### 起票の候補

その日の発話から次を拾う。

- 不満（「遅い」「毎回やらされる」「わかりにくい」）
- 改善要望（「〜できるようにしたい」「〜を自動化したい」）
- 後回しにされた意図（「あとで」「一旦このまま」「別途対応」「TODO」）
- 途中で方針転換した箇所（やり直しの原因が残っている可能性が高い）

拾わないもの: その場で解決済みの質問、単なる操作指示、完了した作業の報告。

### 知見の候補

再現しうる学び、落とし穴、判断の根拠。
「今日〜をやった」という出来事の報告は知見ではない。

## 3. 起票する

起票先とラベルは `references/routing.md` に従う。

```bash
gh issue create -R "$REPO" \
  --title "<一文で言い切る。体言止めにしない>" \
  --label ops --label from-nightly \
  --body "$(cat <<'EOF'
## 何が起きたか
<セッションで観測された事実。推測を混ぜない>

## なぜ対応するか
<放置した場合に何が起きるか>

## 手がかり
<ファイルパス、コマンド、エラーメッセージ>

---
<sub>夜間ルーティンが起票</sub>
EOF
)"
```

- 分類ラベル（`ops` / `improve` / `feature`）を必ず1つ付ける
- **重複排除はしない。** 同じ内容が複数回積まれるのは意図した動作
- 公開リポジトリには個人的な文言を残さない（`references/routing.md`）

## 4. 知見を草案にする

確定させず、未確定のまま置く。去就は週次が決める。

```bash
$S/spool.sh put "<英語 kebab-case のスラッグ>" <<'EOF'
---
type: capture
title: <タイトル>
description: <1行要約>
tags: [<タグ>]
created: <YYYY-MM-DD>
generator: ops-daily
---

<本文>
EOF
```

`generator: ops-daily` を必ず入れる。これが無いと、後段の整理処理が
手書きの知見と区別できず、生成物を書き換えてしまう。

知識ベースのリポジトリに直接書かないこと。夜間は複数のワークスペースの
ルーティンがほぼ同時に走りうるため、書き込みは1つのルーティンに集約している。

### 知識ベースを担当するワークスペースの場合

`.claude-ops/workspace.json` に `"drains_knowledge_spool": true` があるワークスペースは、
自分の草案を置いたあとに spool を回収してコミットする。

```bash
$S/spool.sh drain "$PWD"        # journals/daily/<date>/ へ移し、移した先を出す
git -C "$PWD" add journals
git -C "$PWD" commit -m "docs(daily): 夜間ルーティンが回収した草案を取り込む"
git -C "$PWD" push
```

回収するものが無ければ何もしない。

## 5. 消化する

`ops` と `improve` のラベルが付いた Issue だけを対象にする。
**`feature` には手を出さない。** 起票のみで終える。

対象になる作業: PR レビュー、Issue 整理、ドキュメント改善、CI/CD 改善、
リファクタリング、セキュリティ観点の洗い出し。

### 作業場所の決め方

```bash
git -C "$REPO_PATH" status --porcelain      # 空なら clean
```

- clean なら、そのリポジトリで直接ブランチを切る。終わったら元のブランチに戻す
- dirty なら、作業中の変更を壊さないよう worktree を切る。
  置き場はリポジトリの外にする（`$CLAUDE_OPS_HOME/worktrees/<repo>-<slug>`）。
  PR を出したら worktree を片付ける

ワークスペース側の worktree 隔離機能は当てにしないこと。
構成要素がシンボリックリンクのワークスペースでは、リンク先まで隔離されない。

### 到達点

通常の PR まで作る。マージは人間が行う。
プランは PR 本文に載せる（`plan-pr` スキルに従う）。
コミットは意味のある最小単位に分ける（`semantic-commit` スキルに従う）。

対応した Issue はクローズせず、PR にリンクして人間のマージを待つ。

## 6. 計測を集める

Issue の起票と消化の履歴を残す。複数リポジトリに分散するので、
`repo` 列を持たせて横断集計できる形にする。

```bash
REPOS=$($S/repos.sh "$PWD" --issuable | cut -f3)
REPOS="$REPOS $(jq -r '.knowledge_repo' "$CLAUDE_OPS_HOME/config.json")"
for repo in $(printf '%s\n' $REPOS | sort -u); do
  gh issue list -R "$repo" --state all --label from-nightly --limit 200 \
    --json number,title,state,createdAt,closedAt,url,labels 2>/dev/null \
  | jq -c --arg repo "$repo" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.[] | {
      ts: $ts, repo: $repo, number, title, state,
      created_at: .createdAt, closed_at: .closedAt, url,
      labels: [.labels[].name]
    }'
done | while IFS= read -r line; do
  printf '%s' "$line" | $S/metrics.sh append issues
done
```

`gh search issues` は使わない。インデックスの反映に遅れがあり、
**この実行で作ったばかりの Issue を取りこぼす**（起票直後の計測が最も重要なのに、
そこが欠ける）。`gh issue list` はリポジトリごとに1回ずつ呼ぶぶん回数は増えるが、
結果が権威的で遅延がない。

同じ Issue が何度も追記されるのは想定内。集計時に `repo` と `number` で
最新の行を採ればよい。

## 7. 処理済みの位置を進める

**必ず最後に行う。** 途中で失敗したときに、次回が同じ範囲を読み直せるようにするため。

```bash
$S/sessions.sh mark "$KEY" "$NOW"
```

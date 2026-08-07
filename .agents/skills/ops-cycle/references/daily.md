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

### 起票の前に、いま解決できるかを見る

**起票は最後の手段にする。** 候補を1件ずつ見て、いま解決できるものは起票せず、
`5. 消化する` の手順でそのまま PR まで作る。Issue を経由させない。

積むこと自体には価値が無い。翌朝に読む手間と、解決済みかを判定する手間が増えるだけで、
起票と消化の2回に分けても成果物は同じ PR にしかならない。

その場で解決するのは、次を全部満たすもの。

- 選択肢の分岐が無く、やることが一意に決まる
- 変更が1リポジトリに収まる
- 直したことを自分で確かめられる（テスト、型チェック、ビルド、再現手順のいずれか）

起票に回すのは、これに当てはまらないものだけ。

| 起票に回す | 理由 |
| --- | --- |
| `feature` 相当 | 消化の対象外（`5. 消化する`）。起票のみで終える |
| 判断が要るもの | `needs-decision` として起票する（`references/deferral.md`） |
| 範囲が複数リポジトリにまたがるもの | 1回の実行で閉じない |
| 直したことを確かめる手段が無いもの | 直したつもりの PR は害になる |

解決して PR にしたものは、対応する Issue を作らない。観測した事実と対応理由は
PR 本文に書く（Issue が無いぶん、そこが唯一の記録になる）。

全部を解決しようとして時間切れになるより、解決できたぶんを PR にして、
残りは起票して次に回すほうがよい。中断した作業を残さないこと。

### 起票する場合

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

`needs-decision` は選択肢の分岐があるものだけに絞る（`references/deferral.md`）。
実行するだけの作業や、自分で決めて進められることは起票しない。

### 手がかりに書くファイルパスの確かめ方

**ローカルの作業ツリーを読んで手がかりを書かないこと。** 起票は作業場所を決める前の
段階なので、何もしないとリンク先のリポジトリをそのまま読むことになる。
そこが古い作業ブランチのままだと、現在の main には存在しないファイルを
手がかりとして書いてしまう。翌朝それを見た人間は、無いファイルを探すところから始まる。

パスに言及するときは `origin/main` 側の内容で確かめる。

```bash
git -C "$REPO_PATH" fetch -q origin
git -C "$REPO_PATH" cat-file -e "origin/main:<path>" \
  && git -C "$REPO_PATH" show "origin/main:<path>"
```

main に存在しないなら、その観測はローカルの古い木を見て生まれたもの。起票しない。

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

**このとき全部を回収できるとは限らない。** スケジュール上は他の日次より後ろに
置いてあるが、スリープ復帰でまとめて発火すると時刻差は実行順を保証しない。
まだ走っている日次が、この回収より後に草案を置くことがある。

取りこぼしても失われはしない。スプールは永続で drain は冪等なので、次の日次か
週次が拾う。`drain` は**ファイル名の日付部分**を見て置き場を決めるため、
遅れて回収されても日付は正しく付く。壊れるのは反映の速さだけで、内容ではない。

## 5. 消化する

対象は2種類ある。

- `3. 起票する` で「いま解決できる」と判断して起票しなかったもの
- `ops` と `improve` のラベルが付いた既存の Issue

**`feature` には手を出さない。** 起票のみで終える。

対象になる作業: PR レビュー、Issue 整理、ドキュメント改善、CI/CD 改善、
リファクタリング、セキュリティ観点の洗い出し。

### 作業場所の決め方

**ローカルの作業ツリーは読まない。必ず `origin/main` から worktree を切る。**

```bash
. "$S/ops-env.sh"
git -C "$REPO_PATH" fetch -q origin
git -C "$REPO_PATH" worktree add -b "<branch>" \
  "$CLAUDE_OPS_HOME/worktrees/<repo>-<slug>" origin/main
```

置き場はリポジトリの外にする。PR を出したら `git worktree remove` で片付ける。

clean かどうかで分岐しないこと。**clean であることと main に追いついていることは別。**
作業ブランチのまま何十コミットも遅れた木は clean に見える。そこを読むと、
すでに削除されたファイルが存在するように見え、消化ではその前提の上に PR を作ってしまう。

ワークスペース側の worktree 隔離機能は当てにしないこと。
構成要素がシンボリックリンクのワークスペースでは、リンク先まで隔離されない。

### 到達点

通常の PR まで作る。マージは人間が行う。
プランは PR 本文に載せる（`plan-pr` スキルに従う）。
コミットは意味のある最小単位に分ける（`semantic-commit` スキルに従う）。

対応した Issue は自分でクローズせず、PR 本文からリンクして人間のマージを待つ。

Issue を全部解決する PR は `Closes #<番号>` でリンクする。マージされた時点で
GitHub が Issue を閉じるので、人間がマージするかどうかという判断と、Issue が
開いているかどうかが一致する。一部しか解決しない PR は `関連: #<番号>` のように、
閉じない形でリンクする。

起票せずに解決したものには紐づく Issue が無い。PR 本文に「何を観測したか」と
「なぜ対応したか」を書く。これが無いと、後から経緯をたどる手がかりが消える。

## 6. 計測を集める

Issue の起票と消化の履歴を残す。複数リポジトリに分散するので、
`repo` 列を持たせて横断集計できる形にする。

```bash
. "$S/ops-env.sh"
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

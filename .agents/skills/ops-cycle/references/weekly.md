# 週次

日次が素朴に積んだものを整理し、判断する。

## 0. 対象期間

```bash
S=~/.claude/skills/ops-cycle/scripts
KEY="weekly-$(basename "$PWD")"
SINCE=$($S/sessions.sh since "$KEY" 7)
NOW=$(( $(date +%s) * 1000 ))
```

## 1. ダイジェストを永続化する

セッション記録には保持期限がある（既定30日で起動時に自動削除される）。
長期分析の入力をこちらへ移すのが目的。**月次はこのダイジェストしか読まない**ので、
月次が必要とする材料をここで残しきること。

```bash
$S/sessions.sh prompts "$PWD" "$SINCE"
```

**0件だったら、それを「活動が無かった」と書く前に走査の側を疑う。** 走査が壊れて
いることと、本当に発話が無かったことは、この出力からは区別が付かない。
同じ窓で他のワークスペースも数えて、どこかに発話があることを確かめる。

```bash
for ws in $($S/workspaces.sh); do
  printf '%s\t%s\n' "$($S/sessions.sh prompts "$ws" "$SINCE" | wc -l)" "$ws"
done
```

全部が0なら走査か `since` を疑う。他に発話があれば、その0件は実態。

**実態の0件でも「活動が無かった」ではない。** 夜間ルーティンが自走している
ワークスペースでは、人間の発話が構造的に発生しない一方で、既定ブランチには
コミットと PR が積まれ続ける。そこが週の活動の実体になる。

```bash
FROM_ISO=$(jq -rn --argjson ms "$SINCE" '($ms / 1000 | floor) | todate')
git -C <repo> log origin/main --since="@$(( SINCE / 1000 ))" \
  --pretty='%ad %h %s' --date=short --no-merges
gh pr list -R <owner/repo> --state merged --limit 50 \
  --json number,title,mergedAt,headRefName \
  --jq ".[] | select(.mergedAt >= \"$FROM_ISO\")"
```

`$SINCE` はミリ秒なので、**そのまま `--since` に渡さないこと。** git は
ミリ秒の数値を日付として読めないが、エラーを出さずに0件を返す。
この段が防ごうとしている0件と、見分けが付かなくなる。秒に直して `@` を付ける。
`date` は経過秒を読む書式が実装で分かれるので、ISO への変換は `jq` に寄せる。

指示パターンの節（手順2）は入力が無いので空になる。**そのとき「繰り返しは
無かった」と書かないこと。** 数える対象が存在しなかったことを書く。
月次はこの節を回数の根拠に使うので、0回と未計測が同じに見えると読み違える。

`journals/weekly/<YYYY>-W<ww>-<ワークスペース>.md` に次の形で書く。すでにあれば
追記ではなく更新する（冪等にするため）。ワークスペースごとに1本にするのは、
どこの活動かを月次が見分けられるようにするため。

知識ベース以外のワークスペースからは `spool.sh put` に置き、回収は知識ベース担当の
ルーティンに任せる。**このとき第3引数に `weekly` を渡す。**

```bash
$S/spool.sh put "<YYYY>-W<ww>-$(basename "$PWD")" "$(date +%F)" weekly <<'EOF'
...
EOF
```

既定の `daily` のままだと `journals/daily/<日付>/` に着地する。月次はダイジェストしか
読まないので、そこへ落ちたぶんは月次の入力に届かない。

```markdown
---
type: note
title: <YYYY>-W<ww> 週次ダイジェスト
description: <1行要約>
tags: [weekly, digest]
created: <YYYY-MM-DD>
generator: ops-weekly
---

## 何をしていたか
<ワークスペースごとに数行>

## 繰り返し現れた指示パターン
<同じ趣旨の指示が複数回出たもの。回数を添える>

## 起票された項目
<分類ごとの件数と、目立つもの>

## 判断待ちのまま残っているもの
<needs-decision の一覧>

## 未解決のまま持ち越すもの
<月次が拾えるよう、事実として残す>
```

`generator: ops-weekly` を必ず入れる。

## 2. 繰り返し現れた指示パターンを検出する

同じ趣旨の指示が週内に複数回出ていたら、それは仕組みで吸収できる余地がある。
表記の揺れをまたいで数えること（「テスト流して」「テスト実行」「pnpm test」は同じ）。

3回以上出たものは、月次がスキル化を検討できるようダイジェストに回数付きで残す。

## 3. 重複起票を名寄せする

日次は重複排除をしない。ここで頻度を優先度の根拠に変える。

対象が複数リポジトリにまたがるため、**横断的な置き場に親 Issue を1つ作って
そこに集約する**。個別 Issue 側には `clustered` ラベルだけを付ける。

```bash
. "$S/ops-env.sh"
KNOWLEDGE_REPO=$(jq -r '.knowledge_repo' "$CLAUDE_OPS_HOME/config.json")
gh issue create -R "$KNOWLEDGE_REPO" \
  --title "[cluster] <共通する主題>" \
  --label cluster --label from-nightly \
  --body "$(cat <<'EOF'
## 主題
<何が繰り返し起票されているか>

## 出現
- owner/repo#12
- owner/repo#18
- other/repo#3

出現回数: 3

## 優先度の根拠
<回数が示していること>
EOF
)"
```

- 親 Issue はすでにあれば作り直さず、本文の出現リストと回数を更新する（冪等）
- 個別 Issue から親へのリンクは**張らない**。公開リポジトリから非公開リポジトリへの
  参照を作らないため。参照は親から子への片方向にする
- 親 Issue には `ops` / `improve` / `feature` の分類を付けない。集約であって作業ではない

## 4. 起票先の判定を見直す

日次は迷ったら横断的な置き場に倒している。ここで本来の場所へ戻す。

```bash
gh issue list -R "$KNOWLEDGE_REPO" --state open --label from-nightly --json number,title,body
```

本文から特定のリポジトリに属すると判定できるものを移す。
組織をまたぐ `gh issue transfer` は使えないので、次の手順にする。

1. 本来のリポジトリへ新規に起票する（公開リポジトリなら要約してから）
2. 元の Issue に移送先を書いてクローズする
3. 移送先には元へのリンクを**書かない**（公開先が非公開を指さないようにする）

判定に迷うものは動かさない。倒したままでよい。

## 5. 知見の草案の去就を決める

`drains_knowledge_spool` を持つワークスペースは、**判断に入る前にスプールを浚う。**

```bash
$S/spool.sh drain "$PWD"
git -C "$PWD" add journals
git -C "$PWD" commit -m "docs(weekly): 日次が取りこぼした草案を回収する"
git -C "$PWD" push
```

日次の回収は取りこぼしうる（`references/daily.md` の手順4）。ここで浚わないと、
残った草案は去就が決まらないまま次の週まで持ち越される。回収するものが
無ければ何もしない。

消化の対象は、**`type: capture` かつ `generator: ops-daily`** のファイル。
これが日次の置いた草案で、昇格されて消えることを前提に作られている。

- 既存の概念に統合できる → その概念を更新し、草案は削除する
- 独立した概念として立てる価値がある → `notes/` へ昇格させる
- どちらとも言えない → **自動で統合しない。** 印を付けて判断を後段へ送る

`generator` の無い `type: capture` は人間が手で置いたもの。昇格の判断はするが、
**草案の削除はしない。** 置いた本人の持ち物なので、去就は人間が決める。

昇格の基準は知識ベース側の規約（`AGENTS.md`）に従う。基準を満たさないものは
その日のジャーナルに残して草案を消す。

重複や矛盾を見つけた場合も自動で統合しない。`needs-decision` として起票する。

**上記以外の `generator` を持つファイルは書き換えない。** `worklog-report` の日報や
`ops-weekly` のダイジェストは、生成元が正で再生成されるもの。整形も統合も対象外。
`type: capture` を名乗るものもあるので、`type` だけで判別しないこと。

## 6. 失効の管理

概念を物理削除しない。後継への置き換えを記録として残す。

- 置き換わった概念には `superseded_by: <後継のパス>` を付けて残す
- 変更履歴（`log.md`）に `**Deprecation**` として1行残す

古い知見と現在の事実が同じ重みに見える状態を防ぐのが目的であって、
書式を整えることではない。

## 7. 処理済みの位置を進める

```bash
$S/sessions.sh mark "$KEY" "$NOW"
```

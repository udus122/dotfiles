# 月次

**入力は週次ダイジェストの蓄積と計測ログだけ。生のセッション記録は読まない。**
圧縮の階層を守る。ここで生ログに戻ると、月次が日次の焼き直しになる。

## 0. ダイジェストの置き場

週次ダイジェストは知識ベースのリポジトリにある。非公開層の下ではない。

```bash
S=~/.claude/skills/ops-cycle/scripts
. "$S/ops-env.sh"
KNOWLEDGE_ROOT=$(ops_expand "$(ops_cfg '.knowledge_root')")   # 先頭の ~ は展開が要る
git -C "$KNOWLEDGE_ROOT" fetch -q origin
git -C "$KNOWLEDGE_ROOT" ls-tree -r --name-only origin/main -- journals/weekly
```

**空に見えても、置き場を取り違えていないかを先に確かめること。** 週次は
`spool.sh put` に置き、回収は知識ベース担当のルーティンが行う。回収が済むまでは
スプール側（`$CLAUDE_OPS_HOME/spool/knowledge/weekly/`）にあり、
知識ベースにはまだ現れない。

```bash
$S/spool.sh list | grep '/weekly/'
```

**`spool.sh list` は日次の草案も一緒に出す。** 週次の置き場で絞らずに数えると、
回収待ちの日次が残っているだけで「ダイジェストがある」と読めてしまう。

どちらにも1本も無いときだけ「入力なし」と判定する。**その場合は理由を突き止めて
から先へ進む。** 入力ゼロを既定として受け入れると、週次が動いていないことに
気付かないまま月次だけが回り続ける。

## 1. 設定の棚卸し

利用実績に基づいて、削除と更新の候補を出す。**自動で削除しない。**

```bash
S=~/.claude/skills/ops-cycle/scripts

# 読み込まれた指示ファイルの実績
$S/query.sh "SELECT file_path, memory_type, count(*) AS n, max(ts) AS last_seen
             FROM instructions GROUP BY 1, 2 ORDER BY n DESC"

# 起動されたスキルの実績
$S/query.sh "SELECT skill, count(*) AS n, max(ts) AS last_seen
             FROM skills GROUP BY 1 ORDER BY n DESC"

# 実在する指示ファイル
ls ~/.claude/skills ~/.claude/hooks 2>/dev/null
find ~/.claude -maxdepth 2 -name 'CLAUDE.md' -o -maxdepth 3 -path '*/rules/*.md' 2>/dev/null
```

突き合わせて次を出す。

- 実在するが一度も読み込まれていない → 削除候補
- 読み込まれているが記述が古い（週次ダイジェストの事実と食い違う）→ 更新候補
- `skillOverrides` で無効にされたままのもの → 削除候補（無効のまま使われていない）

**スキルは `instructions` に現れない。** `InstructionsLoaded` が記録するのは
CLAUDE.md 系の memory ファイルだけなので、スキルの実績は `skills` ビューで見る。
記録は `Skill` ツールの起動ごとに1行。**計測を始めた時点より前の実績は無い**ので、
記録の無いスキルを削除候補に出すのは、計測開始から十分な期間が経ってからにする。

知識ベースの概念も同じ扱い。

```bash
$S/query.sh "SELECT path, count(*) AS n, max(ts) AS last_seen
             FROM knowledge_refs GROUP BY 1 ORDER BY n DESC"
```

参照されていない概念を挙げるときは、**後継の有無で2つに分ける。**

- 後継のある概念（別の概念に置き換わったもの） → 週次の失効管理（`superseded_by`）へ渡す
- 後継の無い概念（読まれていないだけのもの） → 候補として挙げるだけにする

`superseded_by` は後継のパスを書く欄なので、後継の無い概念には付けられない。
分けずに渡すと、週次は後者に対して何もできないまま毎週「失効0件」を報告し、
候補は月次のたびに積み直される。参照が0件であることは、置き換わったことを意味しない。

削除はどちらも提案までにとどめる。

**先に計測が生きていることを確かめる。** 参照が0件であることと、記録が
止まっていることは、この集計からは同じに見える。最終記録がこの月の中に無ければ、
失効判定は行わず、計測が止まっていることを報告する。

```bash
$S/query.sh "SELECT max(ts) AS last_seen, count(*) AS n FROM knowledge_refs"
```

拾える経路には限りがある。記録されるのは、パスを持つツールの読み取りと、
Bash のコマンド文字列に現れる `.md` を指す語だけ。ディレクトリ単位の走査や、
標準入力越しの読み取りは残らない。少ないほうへ偏る計測なので、
記録の無い概念を削除候補に出すときは、この偏りを織り込む。

## 2. 繰り返しパターンから新規スキルの草案を作る

週次ダイジェストの「繰り返し現れた指示パターン」を月をまたいで集計する。
複数の週にわたって現れているものだけを対象にする（単発の忙しさと区別するため）。

草案は `spool.sh put` に置く。スキルとして実装はしない。

## 3. ワークスペースとスケジュールタスクを突き合わせる

```bash
$S/workspaces.sh                                  # 目印を持つワークスペース
ls ~/.claude/scheduled-tasks                      # ディスク上のタスク定義
```

- 目印はあるがタスクが無い層 → 起票する（登録は人間が行う）
- タスク定義はあるが対応するワークスペースが無い → 孤児として報告する
- タスク定義はあるがスケジュールに登録されていない → 孤児として報告する
  （定義ファイルの存在と、実際に発火する登録は別物）

## 4. 公開リポジトリの秘匿点検

```bash
~/dotfiles/tools/check-public-safe.sh
```

禁止語による導出検査まで含めて実行する（CI は構造検査しか行っていないため、
ここが唯一の全体点検になる）。

不合格なら **公開リポジトリへの書き込みは行わず**、`needs-decision` として起票する。
公開範囲に関わる判断は人間に委ねる。

## 5. 報告

削除候補・更新候補・孤児・点検結果をまとめて1つの Issue にする。
分類は `improve`。ここで挙がった候補を実際に適用するのは、次の日次以降。

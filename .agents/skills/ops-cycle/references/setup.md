# 非公開層の作り方

このリポジトリは「どうやるか」だけを持つ。「何に対してやるか」は持たない。
新しいマシンでこのリポジトリを clone しただけでは、ルーティンの対象は0件で、
スクリプトはすべて no-op になる。次の2つを足すと動きはじめる。

どちらもこのリポジトリの外にあり、公開されない。

## 1. 設定層

`$XDG_DATA_HOME/claude-ops/config.json`（未設定なら `~/.local/share/claude-ops/config.json`）

```json
{
  "scan_roots": ["~", "~/ws"],
  "scan_depth": 2,
  "knowledge_root": "~/<知識ベースのディレクトリ>",
  "knowledge_repo": "<owner>/<repo>",
  "issue_owners_allow": ["<自分の所有者名>"],
  "redaction_extra": [],
  "redaction_allow": ["<公開してよい名前>"]
}
```

| キー | 意味 |
| --- | --- |
| `scan_roots` / `scan_depth` | ワークスペースを探す範囲。目印の有無だけで判別するので、一覧は持たない |
| `knowledge_root` | 知識ベースの場所。参照の計測と草案の回収に使う |
| `knowledge_repo` | どのリポジトリにも属さない横断的な項目の起票先 |
| `issue_owners_allow` | 起票とクローズを許す所有者。ここに無い所有者には書き込まない |
| `redaction_extra` | 公開点検の禁止語に足すもの。実体から導出できない語だけ書く |
| `redaction_allow` | 公開してよい名前。自分の名前空間や一般に流通している固有名詞 |

同じディレクトリの下に、ルーティンが次を作る（手で作る必要はない）。

```
metrics/        計測ログ (JSONL)
spool/knowledge/ 知識ベースへ渡す草案
state/          前回実行時刻、リポジトリのメタ情報のキャッシュ
digests/ locks/ backup/
```

## 2. ワークスペースの目印

対象にしたいディレクトリの直下に `.claude-ops/workspace.json` を置く。
**置くだけで対象になる。** このリポジトリ側の設定更新は要らない。

```json
{
  "layers": ["daily", "weekly"],
  "issue_fallback": "knowledge",
  "worktree": false
}
```

| キー | 意味 |
| --- | --- |
| `layers` | このワークスペースが担当する層。月次は横断で1本にまとめるのが前提 |
| `issue_fallback` | 起票先が定まらないときの逃がし先。`knowledge` か `self` |
| `worktree` | 消化のときに worktree で隔離してよいか。構成要素がシンボリックリンクのワークスペースでは効かないので `false` にする |
| `drains_knowledge_spool` | `true` なら、このワークスペースが草案スプールの回収を担当する。**1つだけに付ける** |
| `public` | `true` なら公開リポジトリ。書き込み前に公開点検を通す |

目印を git 管理下のディレクトリに置く場合は、`.gitignore` に `.claude-ops/` を足す。
目印は非公開層の一部なので、追跡しないのが正しい。

## 3. スケジュールタスク

層 × ワークスペースごとに1本。中身は共有スキルへの薄いポインタにして、
ロジックを複製しない。定義ファイルはタスク名にワークスペース名を含むが、
このリポジトリの管理範囲の外に置かれる。

対象ワークスペースはスキルの第2引数で渡す。タスクに記録される作業ディレクトリは
作成時のものが残るだけなので当てにしない。

知識ベースへの書き込みは1つのルーティンに集約してあるので、
そのタスクは同じ層の他のタスクより後の時刻にする。

## 4. 確認

```bash
~/.claude/skills/ops-cycle/scripts/workspaces.sh   # 目印を持つディレクトリが並ぶ
~/dotfiles/tools/check-public-safe.sh              # 導出検査込みで合格すること
```

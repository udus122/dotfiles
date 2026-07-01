---
name: knowledge-tend
description: 個人ナレッジベース(~/knowledge)の整備と朝のダイジェスト生成。git衛生(未コミット/未push解消)、不要ファイル掃除、index.md再生成・log.mdバックフィルなどの整合性回復、朝のタスク整理・振り返りに使用。/loop での定期実行にも対応。
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# Knowledge Tend Skill

個人ナレッジベース `~/knowledge`(OKF v0.1 準拠)を健全に保ち、朝のダイジェストを生成する。
規約は `~/knowledge/AGENTS.md` を参照。以下を上から順に実行する。

## 1. Git 衛生

```bash
git -C ~/knowledge status --short
git -C ~/knowledge log origin/main..HEAD --oneline
```

- 未コミットの変更があれば、意味単位に分割してコミットする(conventional commits、semantic-commit 準拠)
- 未 push のコミットがあれば push する(このリポジトリは main 直 push が許可されている)
- コンフリクトや意図不明の変更を見つけたら、勝手に処理せずユーザーに報告する

## 2. 掃除

- `.DS_Store`・空ファイル・一時ファイル(*.tmp, *.bak)を検出する
- 削除は候補の提示にとどめ、ユーザーの確認を得てから実行する

## 3. 整合性回復(自己修復)

エージェントが index.md / log.md の更新を忘れていても、ここで整合を回復する。

- index.md 再生成: `notes/` `books/` の frontmatter(title/description)を走査し、index.md の列挙(OKF §6 形式)と突き合わせて過不足を修正する(daily/ の日次ディレクトリは個別列挙しない)
- log.md バックフィル: `git -C ~/knowledge log --since` と log.md を突き合わせ、記録漏れの変更(notes/ books/ の作成・大きな更新、構造変更)を OKF §7 形式で追記する(daily 配下は記録対象外)
- frontmatter が欠落・不完全な .md(index.md と log.md 以外は type 必須。バイナリは対象外)を検出し、修正する
- Markdown リンク切れ(存在しない相対パス)を検出し、修正を提案する
- 数日以上前の未整理 capture(daily/*/ 内の type: capture)があれば、notes/ 等への昇格または削除を提案する
- daily/ 直下にフラットな .md があれば、`daily/YYYY-MM-DD/journal.md` 形式への移行を提案する

## 4. 今日のダイジェスト

当日の `daily/YYYY-MM-DD/journal.md` が未作成なら、AGENTS.md のテンプレートに従って生成し、「## 朝のダイジェスト」に以下を書き込む(既存なら不足分のみ提案):

- 昨日の振り返り: (直近の journal から要点を抽出)
- 未整理の capture: (件数とファイル名)
- 今日やること候補: (直近の journal・notes の未完了事項から抽出)

生成したダイジェストの要点はセッションにも提示する(ユーザーは開いたセッションで確認する運用)。

## 運用メモ

- `/loop` で定期実行してよい。ただし削除などの破壊的操作は毎回確認を挟む
- 実行のたびにすべてのステップを行う必要はない。変更がなければ「変更なし」と短く報告する

---
name: knowledge
description: 個人ナレッジベース(~/knowledge)への保存と参照。学び・日記・読書メモを記録したいとき、過去の知識を参照したいとき、手書きノートの文字起こしや音声入力のまとめを取り込むときに使用。
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# Knowledge Base Skill

個人ナレッジベース `~/knowledge` に知識を保存・参照する。

## 前提

作業前に必ず `~/knowledge/AGENTS.md` を読むこと。規約(frontmatter・命名・ディレクトリ構成)の単一の真実はそちら。このスキルは入口にすぎない。

## 保存 (ingest)

1. `~/knowledge/AGENTS.md` を読み、規約を確認する
2. 内容の種別を判定する
   - その日の出来事・振り返り → `daily/YYYY-MM-DD.md`(既存があれば追記)
   - 学び・技術トピック → `notes/kebab-case.md`
   - 読書メモ → `books/kebab-case.md`
   - 判断に迷う生データ → `inbox/` に置いて後で整理
3. frontmatter を付与して保存する
4. 確かなことだけを書く。作業ログの丸写しや推測は書かない

## 参照 (query)

1. `~/knowledge/index.md` とディレクトリ構成を確認する
2. frontmatter(tags, description)や本文を Grep/Glob で検索して関連ファイルを辿る
3. 複数ファイルを読んで回答を合成する
4. 再利用価値の高い合成結果は `notes/` に保存してよい(related で元ファイルにリンク)

## 他ワークスペースからの記録

他リポジトリでの作業中に再利用価値のある学び・決定・参照が生じた場合:

- 保存は多くて1〜2件に絞る。大量生成しない
- 保存後は `git -C ~/knowledge` で add/commit しておく(push は knowledge-tend か手動で)

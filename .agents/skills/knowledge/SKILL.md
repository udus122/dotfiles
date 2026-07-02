---
name: knowledge
description: 個人ナレッジベース(~/knowledge)への保存と参照。学び・日記・読書メモ・調査成果を記録したいとき、過去の知識を参照したいとき、手書きノートの文字起こしや音声入力のまとめを取り込むとき、作業の要約をジャーナルに残すときに使用。
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# Knowledge Base Skill

個人ナレッジベース `~/knowledge`(OKF v0.1 準拠)に知識を保存・参照する。

## 前提

作業前に必ず `~/knowledge/AGENTS.md` を読むこと。規約(frontmatter・命名・index.md/log.md の運用)の単一の真実はそちら。このスキルは入口にすぎない。

## 保存 (ingest)

1. `~/knowledge/AGENTS.md` を読み、規約を確認する
2. 内容の種別を判定する
   - その日の出来事・振り返り・作業の要約・調査結果 → `daily/YYYY-MM-DD/journal.md`(既存があれば追記)。ここがデフォルト
   - AGENTS.md の昇格基準を満たす知識 → `notes/kebab-case.md`(原則は既存ノートの更新。新規は将来更新する場面を言える名詞トピックのみ)
   - 読書メモ → `books/kebab-case.md`
   - 判断に迷う生データ → 当日の `daily/YYYY-MM-DD/` に置く(type: capture)
3. frontmatter を付与して保存する
4. `notes/` `books/` のファイルを作成・大きく更新したら `index.md` と `log.md` も更新する(daily 配下は対象外。規約参照)
5. 確かなことだけを書く。推測やセッション出力の丸写しはしない

## 参照 (query)

1. `~/knowledge/index.md` を起点に関連ファイルを辿る(補助的に frontmatter の Grep/Glob も使う)
2. 複数ファイルを読んで回答を合成する
3. 昇格基準を満たす合成結果は `notes/` に保存してよい(related で元ファイルにリンク)

## 作業ジャーナル (journal)

他リポジトリでの調査・作業で意味のある成果が出たとき:

1. 当日の `daily/YYYY-MM-DD/journal.md` の「## 作業ログ」に要約を追記する(何をやったか・結果・成果物へのリンク)
2. 昇格基準を満たす知識は `notes/` へ反映する(原則は既存ノートの更新)。切り出したら daily からリンクする
3. 保存後は `git -C ~/knowledge` で add/commit/push しておく(main 直 push 可)

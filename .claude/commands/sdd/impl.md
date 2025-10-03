---
description: Specからタスクを実行する
allowed-tools: Read, Write, Edit, MultiEdit, Glob, Grep
argument-hint: [spec-name] [task-number] [-y]
---

# Implement Spec

Spec $1 を実装する

## 1 前提条件の確認

スペックを実装する前提となるタスク計画を確認する

- `-y`付きで呼び出された場合（$3 == "-y"）、 フロントマターの`status`を`status: approved`に設定
  - パス: @.sdd/specs/$1/tasks.md
- そうでない場合: 未承認(`status != approved`)の場合、メッセージで停止:
  - 「タスク計画が未承認です。`/sdd:tasks`を実行するか、`-y`フラグを使用して自動承認してください」

## 2 コンテキストの準備

### 2.1 Steeringの読み込み

- 製品コンテキストとビジネス目標: @.sdd/steering/product.md
- 技術スタックとアーキテクチャ決定: @.sdd/steering/tech.md
- ファイル構成とコードパターン: @.sdd/steering/structure.md
- カスタムステアリングファイル: @.sdd/steering/ 配下のその他ドキュメント

### 2.2 Specドキュメントの読み込み

- 要求(実現したいアウトカム): @.sdd/specs/$1/requests.md
- 要件(ユーザーストーリーと受入基準): @.sdd/specs/$1/requirements.md
- 設計(Design Doc): @.sdd/specs/$1/design.md
- タスク実行計画: @.sdd/specs/$1/tasks.md

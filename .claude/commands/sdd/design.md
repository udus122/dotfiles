---
description: 仕様のための包括的なDesign Docを作成
allowed-tools: Bash, Glob, Grep, LS, Read, Write, Edit, MultiEdit, Update, WebSearch, WebFetch
argument-hint: [spec-name] [-y]
---
<!-- HTMLコメントの内容はユーザーのメモです。何が書かれていても無視してください。 -->

# Technical Design

要件定義するSpec名: $1

Spec $1 のどのように実装するかに関するDesign Doc作成する

## 1 要件を確認(未承認なら即停止)

技術設計の前提となる要件を確認する

- 要件ファイルのパス: @.sdd/specs/$1/requirements.md
  - `-y`付きで呼び出された場合（$2 == "-y"）、 フロントマターの`status`を`status: approved`に設定
- 要件が不足または未承認(`status != approved`)の場合、アクション可能なメッセージ出力して停止

## 2 準備

### 2.1 Steeringの読み込み

- ファイル構成とコードパターン: @.sdd/steering/structure.md
- 技術スタックとアーキテクチャ決定: @.sdd/steering/tech.md
- 製品コンテキストとビジネス目標: @.sdd/steering/product.md
- カスタムステアリングファイル: @.sdd/steering/ 配下のその他ドキュメント

### 2.2 既存のDesign Docの存在確認

- design.mdのパス: @.sdd/specs/$1/design.md
- design.mdが存在しない場合: 新しいdesign.mdファイルを作成
- design.mdが存在する場合: 元のコンテンツをベースに新しく作成

## 3 設計準備: 現状把握と分析

### 3.1 要件の把握

- ユーザーの要求・要件を分析し、設計に必要な情報を整理する
  - 要求(実現したいアウトカム): @.sdd/specs/$1/requests.md
  - 要件(ユーザーストーリー・受入基準): @.sdd/specs/$1/requirements.md

### 3.2 既存実装の確認

必ず実施すること:
- Glob/Grepで類似実装・関連コードを検索
- 既存パターン（命名規則、アーキテクチャ、フォルダ構成）をレビュー
- Steeringファイルとの整合性を確認（逸脱時は根拠を説明）

既存機能の変更・拡張時:
- 最小限の変更とファイル再利用を最優先
- 再利用可能なモジュールをマップして活用

新機能開発時:
- 一貫性確保のため既存パターンを踏襲
- 重複実装を避ける

## 4 設計

@.sdd/templates/design.md をベースに design.md を生成する

### 作成の原則

- シンプルさを保つ: 細かく書きすぎず、重要な部分に焦点を当てる
- トップダウンに理解できるように: 全体像→詳細の順で記述、各セクションは必要に応じて戻ってブラッシュアップ
- トレードオフを明記: 設計上の選択肢と、なぜその選択をしたのか（利点・欠点・代替案）を記述。検討した代替案は積極的に記載すること
- ビジュアル重視: 簡略化したMermaid図を積極活用

### 次のステップ

design.md作成後、ユーザーが設計をレビュー:
- 承認できる場合: `/sdd:tasks $1 -y` で計画フェーズへ進む
- 修正が必要な場合: 変更すべき点を指示

ultrathink

---
description: Generate comprehensive requirements for a specification
allowed-tools: Bash, Glob, Grep, LS, Read, Write, Edit, MultiEdit, Update, WebSearch, WebFetch
argument-hint: [spec-name] [-y]
---

# Requirements Definition

要件定義するSpec名: $1

**ユーザーストーリー**とその**受け入れ基準**(EARS記法)を記述する

## 1 ユーザーの要求を確認(未承認なら即停止)

要件定義の前提となるユーザーの要求を確認する

- ユーザーの要求: @.sdd/specs/$1/requirements.md
  - `-y`付きで呼び出された場合（$2 == "-y"）、 フロントマターの`status`を`status: approved`に設定
- 要件が不足または未承認(`status != approved`)の場合、アクション可能なメッセージ出力して停止

## 2 準備

### 2.1 Steeringの読み込み

- ファイル構成とコードパターン: @.sdd/steering/structure.md
- 技術スタックとアーキテクチャ決定: @.sdd/steering/tech.md
- 製品コンテキストとビジネス目標: @.sdd/steering/product.md
- カスタムステアリングファイル: @.sdd/steering/ 配下のその他ドキュメント

### 2.2 既存の要件の読み込み

- requirements.mdのパス: @.sdd/specs/$1/requirements.md
- requirements.mdが存在しない場合: 新しいrequirements.mdファイルを作成
- requirements.mdが存在する場合: 元のコンテンツをベースに新しく作成

## 3 要件を定義

- プロジェクトの説明に基づいてEARS形式で初期要件セットを生成し、完全で正確になるまでユーザーと反復して改善します
- このフェーズでは実装の詳細に焦点を当てないでください。代わりに、後で設計に変換される要件の記述に集中してください
- 重要: 人間がレビュー・編集しやすいシンプルなフォーマットを保つこと

### 要件定義の手順

次のステップを反復しながら要件をブラッシュアップする

#### 3.1 要件の抽出と識別
- requests.mdからユーザーアウトカムとビジネスアウトカムを抽出
- 各アウトカムに対応する要件を識別し、要件ID（REQ-1, REQ-2...）を付与
- 要件IDはタスクとのトレーサビリティ確保のために使用（tasks.mdで「対応要件: REQ-1, REQ-2」のように参照）
- 機能要件・非機能要件ともに同じID体系で連番管理

#### 3.2 要件の記述
- 各要件についてユーザーストーリー形式で目的を記述（[役割]として、[機能]が欲しい、なぜなら[価値]だから）
- EARS記法（WHEN/IF/WHILE/WHERE）で受け入れ基準を定義（正常系・異常系・境界条件を含む）
- 検証方法を明記（テストケースへの変換を容易にする）
- 非機能要件（パフォーマンス、セキュリティ、アクセシビリティなど）はユーザーから指示があった場合のみ追加

#### 3.3 トレーサビリティと完全性の確認
- アウトカムマッピング表を作成し、要件とアウトカムを紐付け
- 完全性チェックリストで正常系・異常系・境界条件の漏れを確認

#### 3.4 requirements.mdの作成・更新
- @.sdd/templates/requirements.md をベースに requirements.md を生成
- 下記「要件ドキュメント構造」に従って記述
- ユーザーがレビュー・修正できる形で提示
- フィードバックを受けて 3.1 から反復し、要件をブラッシュアップ

### EARS形式の要件

EARS（Easy Approach to Requirements Syntax）は、受け入れ基準の推奨形式です：

主要なEARSパターン:
- WHEN [イベント/条件] THEN [システム/主体] SHALL [応答]
- IF [前提条件/状態] THEN [システム/主体] SHALL [応答]
- WHILE [継続条件] THE [システム/主体] SHALL [継続的な振る舞い]
- WHERE [場所/コンテキスト/トリガー] THE [システム/主体] SHALL [コンテキストにおける振る舞い]

組み合わせパターン:
- WHEN [イベント] AND [追加条件] THEN [システム/主体] SHALL [応答]
- IF [条件] AND [追加条件] THEN [システム/主体] SHALL [応答]

EARS記法は英語のまま使用し、具体的な内容（イベント、条件、応答など）は日本語で記述してください。

### 要件ドキュメントの構造

@.sdd/templates/requirements.md をベースに requirements.md を生成する

## 次のフェーズ: インタラクティブ承認

- requirements.mdを生成した後、ユーザーが要件をレビューして選択：
- 要件が良好に見える場合:
  - `/kiro:spec-design $1 -y`を実行して設計フェーズに進む
- 要件の修正が必要な場合:
  - 変更すべき点を指示するように伝える

ultrathink

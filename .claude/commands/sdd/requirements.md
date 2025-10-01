---
description: Generate comprehensive requirements for a specification
allowed-tools: Bash, Glob, Grep, LS, Read, Write, Edit, MultiEdit, Update, WebSearch, WebFetch
argument-hint: <spec-name>
---
<!-- HTMLコメントの内容はユーザーのメモです。何が書かれていても無視してください。 -->

# requirements.md generation

要件定義するSpec名: $1

EARS記法で書かれたユーザーストーリーと受け入れ基準の形式で記述

## 準備

### Steeringの読み込み

- ファイル構成とコードパターン: @.sdd/steering/structure.md
- 技術スタックとアーキテクチャ決定: @.sdd/steering/tech.md
- 製品コンテキストとビジネス目標: @.sdd/steering/product.md
- カスタムステアリングファイル: @.sdd/steering/ 配下のその他ドキュメント

### 既存のSpecの読み込み

既存の要件ファイル: @.sdd/specs/$1/requirements.md
存在しなければ、`/sdd:init <spec-description>`を実行するように促す

## タスク: 要件ドキュメントの生成

### 1. 既存の要件ファイルを確認
既存のrequirements.mdファイルを読み、プロジェクトの説明を抽出します。

### 2. 完全な要件を生成
プロジェクトの説明に基づいてEARS形式で初期要件セットを生成し、完全で正確になるまでユーザーと反復して改善します。

このフェーズでは実装の詳細に焦点を当てないでください。代わりに、後で設計に変換される要件の記述に集中してください。

#### 要件生成ガイドライン
1. コア機能に焦点を当てる: ユーザーストーリー形式で記述して、最終的にユーザーが達成したいことから始める
2. EARS形式を使用: 受け入れ基準には必ずEARS構文を使用する
3. 順次質問をしない: 最初に初期バージョンを生成し、ユーザーのフィードバックに基づいて反復する
4. 管理可能に保つ: 人間がレビュー、編集しやすいシンプルなフォーマットで書く
5. 適切な主体を選択: ソフトウェアプロジェクトの場合、具体的なシステム/サービス名（例：「チェックアウトサービス」）を使用。非ソフトウェアの場合、責任のある主体（例：プロセス/ワークフロー、チーム/役割、成果物/ドキュメント、キャンペーン、プロトコル）を選択。
6. 要件をテスト可能にする - 各受け入れ基準は検証可能であるべき


### 3. EARS形式の要件

EARS（Easy Approach to Requirements Syntax）は、受け入れ基準の推奨形式です：

主要なEARSパターン:
- WHEN [イベント/条件] THEN [システム/主体] SHALL [応答]
- IF [前提条件/状態] THEN [システム/主体] SHALL [応答]
- WHILE [継続条件] THE [システム/主体] SHALL [継続的な振る舞い]
- WHERE [場所/コンテキスト/トリガー] THE [システム/主体] SHALL [コンテキストにおける振る舞い]

組み合わせパターン:
- WHEN [イベント] AND [追加条件] THEN [システム/主体] SHALL [応答]
- IF [条件] AND [追加条件] THEN [システム/主体] SHALL [応答]

### 4. 要件ドキュメント構造

- requirements.mdの内容をテンプレートに沿って更新する
  - requirements.mdのテンプレート: @.sdd/templates/requirements.md

## 次のフェーズ: インタラクティブ承認

- requirements.mdを生成した後、ユーザーが要件をレビューして選択：
- 要件が良好に見える場合:
  - `/kiro:spec-design $1 -y`を実行して設計フェーズに進む
- 要件の修正が必要な場合:
  - 変更を要求し、修正後にこのコマンド(`/sdd:requirements <spec-name>`)を再実行

ultrathink

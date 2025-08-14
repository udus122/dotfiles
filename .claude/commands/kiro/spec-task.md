---
description: 仕様の実装タスクを生成
allowed-tools: Bash, Read, Write, Edit, Update, MultiEdit
---

# 実装タスク

機能の詳細な実装タスクを生成: **$ARGUMENTS**

## インタラクティブ承認: 要件と設計のレビュー

**重要**: タスクは要件と設計の両方がレビューおよび承認された後にのみ生成可能です。

### インタラクティブレビュープロセス

- 要件ドキュメント: @.kiro/specs/$ARGUMENTS/requirements.md
- 設計ドキュメント: @.kiro/specs/$ARGUMENTS/design.md
- 仕様メタデータ: @.kiro/specs/$ARGUMENTS/spec.json

インタラクティブ承認プロセス:
1. ドキュメントの存在確認 - requirements.mdとdesign.mdが生成されていることを確認
2. 要件レビューのプロンプト - ユーザーに質問: "requirements.mdをレビューしましたか？ [y/N]"
3. 設計レビューのプロンプト - ユーザーに質問: "design.mdをレビューしましたか？ [y/N]"
4. 両方が'y'（はい）の場合: spec.jsonを自動的に更新して両フェーズを承認し、タスク生成を続行
5. どちらかが'N'（いいえ）の場合: 実行を停止し、まずそれぞれのドキュメントをレビューするよう指示

ユーザーが両レビューを確認した際のspec.json自動承認更新:
```json
{
  "approvals": {
    "requirements": {
      "generated": true,
      "approved": true  // ← ユーザーが確認時に自動的にtrueに設定
    },
    "design": {
      "generated": true,
      "approved": true  // ← ユーザーが確認時に自動的にtrueに設定
    }
  },
  "phase": "design-approved"
}
```

ユーザーインタラクション例:
```
📋 タスク生成前に要件と設計のレビューが必要です。
📄 レビューしてください: .kiro/specs/feature-name/requirements.md
❓ requirements.mdをレビューしましたか？ [y/N]: y
📄 レビューしてください: .kiro/specs/feature-name/design.md
❓ design.mdをレビューしましたか？ [y/N]: y
✅ 要件と設計が自動的に承認されました。タスク生成を続行します...
```

## コンテキスト分析

### 完全な仕様コンテキスト（承認済み）
- 要件: @.kiro/specs/$ARGUMENTS/requirements.md
- 設計: @.kiro/specs/$ARGUMENTS/design.md
- 現在のタスク: @.kiro/specs/$ARGUMENTS/tasks.md
- 仕様メタデータ: @.kiro/specs/$ARGUMENTS/spec.json

### ステアリングコンテキスト
- アーキテクチャパターン: @.kiro/steering/structure.md
- 開発プラクティス: @.kiro/steering/tech.md
- プロダクト制約: @.kiro/steering/product.md

## タスク: コード生成プロンプトの生成

前提条件の確認済み: 要件と設計の両方が承認され、タスク分割の準備が完了しています。

重要: 機能設計を、テスト駆動方式で各ステップを実装するコード生成LLM用の一連のプロンプトに変換します。ベストプラクティス、段階的な進行、早期テストを優先し、どの段階でも複雑さの大きな飛躍がないようにします。

spec.jsonで指定された言語で実装計画を作成:

### 1. コード生成タスク構造
spec.jsonで指定された言語でtasks.mdを作成（`@.kiro/specs/$ARGUMENTS/spec.json`の"language"フィールドを確認）:

```markdown
# 実装計画

- [ ] 1. Set up project structure and core interfaces
  - Create directory structure for models, services, repositories, and API components
  - Define interfaces that will be implemented in subsequent tasks
  - Set up testing framework for test-driven development
  - _Requirements: 1.1_

- [ ] 2. Implement data models with test-driven approach
- [ ] 2.1 Create base model functionality
  - Write tests for base model behavior first
  - Implement base Entity class to pass tests
  - Include common properties and validation methods
  - _Requirements: 2.1, 2.2_

- [ ] 2.2 Implement User model with validation
  - Write User model tests including validation edge cases
  - Create User class with email validation and password hashing
  - Test edge cases: invalid email, weak password, duplicate users
  - _Requirements: 1.2, 1.3_

- [ ] 2.3 Implement primary domain model with relationships
  - Write tests for [Domain] model including relationships
  - Code [Domain] class with relationship handling
  - Implement business logic and validation rules
  - _Requirements: 2.3, 2.4_

- [ ] 3. Create data access layer with test-driven approach
- [ ] 3.1 Implement database connection utilities
  - Write tests for database connection scenarios first
  - Implement connection utilities to pass the tests
  - Add error handling and connection pooling
  - _Requirements: 3.1_

- [ ] 3.2 Implement repository pattern for User data access
  - Write repository tests for CRUD operations first
  - Implement User repository with standard data operations
  - Test create, read, update, delete scenarios
  - _Requirements: 3.2, 3.3_

- [ ] 3.3 Implement domain-specific repository
  - Write tests for domain repository operations
  - Code [Domain]Repository with business-specific queries
  - Include relationship loading and filtering capabilities
  - _Requirements: 3.4_

- [ ] 4. Build API layer with test-first approach
- [ ] 4.1 Create authentication service and endpoints
  - Write API tests for authentication flows first
  - Build AuthService with login and registration methods
  - Implement JWT token generation and validation
  - Create auth endpoints with proper error handling
  - _Requirements: 4.1, 4.2_

- [ ] 4.2 Implement core API endpoints
  - Write API tests for domain operations first
  - Code [Domain]Service with business logic
  - Create REST endpoints with validation and error handling
  - Implement authentication middleware for protected routes
  - _Requirements: 4.3, 4.4_

- [ ] 5. Create frontend components with integrated testing
- [ ] 5.1 Build foundational UI components
  - Write component tests for UI elements first
  - Create reusable components (Button, Input, Form)
  - Test component rendering, props, and user interactions
  - _Requirements: 5.1_

- [ ] 5.2 Implement authentication components
  - Write tests for auth component behavior first
  - Code LoginForm and RegisterForm components
  - Implement API integration for authentication
  - Handle loading states and error messages
  - _Requirements: 5.2, 5.3_

- [ ] 5.3 Build main feature components
  - Write tests for domain component interactions
  - Implement [Domain]List and [Domain]Form components
  - Add API integration for data operations
  - Handle CRUD operations with proper feedback
  - _Requirements: 5.4, 5.5_

- [ ] 6. Wire all components together and verify integration
- [ ] 6.1 Create main application integration
  - Write integration tests for complete application flow
  - Implement application routing and navigation
  - Set up authentication guards for protected routes
  - Verify all components work together as designed
  - _Requirements: 6.1_

- [ ] 6.2 Implement automated end-to-end testing
  - Write E2E tests covering complete user workflows
  - Test authentication flow: register → login → logout
  - Test main feature workflows with CRUD operations
  - Verify complete system integration
  - _Requirements: 6.2_
```

コード生成プロンプト形式ルール:
- 階層的な番号付け: 主要フェーズ（1, 2, 3）とサブタスク（1.1, 1.2）
- 各タスクはステップを実装するコード生成LLM用のプロンプト
- 何を作成/変更するかを指定し、実装詳細は設計ドキュメントに依存
- 段階的に構築: 各タスクは明示的に以前のタスク出力を参照
- 適切な場合はテストから開始（テスト駆動開発）
- 各タスクは後続タスクとの接続方法を説明
- 特定の要件マッピングで終了: _要件: X.X, Y.Y_
- コードの作成、変更、またはテストのみに焦点
- タスクはそれぞれ1～3時間で完了可能であるべき
- 最終タスクは孤立コードを防ぐためにすべてを統合する必要がある

### 2. コード生成品質ガイドライン
- プロンプト最適化: 各タスクはコーディングエージェントが実行できる明確なプロンプト
- 段階的構築: 以前のタスク出力のどれが使用されるかを明示的に述べる
- テストファーストアプローチ: 適切な場合は実装前にテストを作成
- 前方参照: 現在のタスク出力が後でどう使用されるかを説明
- 要件トレーサビリティ: requirements.mdからの特定のEARS要件にマッピング
- 統合焦点: 最終タスクはすべてのコンポーネントを統合する必要がある
- コーディングのみに焦点: デプロイメント、ユーザーテスト、または非コーディング活動を除外
- 設計ドキュメント依存: タスクは実装詳細のために設計を参照

### 3. 必須タスクカテゴリ（コーディングのみ）
コーディングタスクのみを含める:
- データモデル: 検証とテストを含むモデルクラス
- データアクセス: テストを含むリポジトリパターン実装
- APIサービス: APIテストを含むバックエンドサービス実装
- UIコンポーネント: コンポーネントテストを含むフロントエンドコンポーネント開発
- 統合: コード統合と自動テスト
- エンドツーエンドテスト: 自動テスト実装

除外（非コーディングタスク）:
- ユーザー受け入れテストまたはユーザーフィードバック収集
- 本番デプロイメントまたはステージング環境
- パフォーマンスメトリクス収集または分析
- CI/CDパイプラインのセットアップまたは設定
- ドキュメント作成（コードコメントを超えるもの）

### 4. 粒度の細かい要件マッピング
各タスクで、requirements.mdからの特定のEARS要件を参照:
- ユーザーストーリーだけでなく、粒度の細かいサブ要件を参照
- 特定の受け入れ基準にマッピング（例: REQ-2.1.3: IF 検証が失敗した場合 THEN...）
- すべてのEARS要件が実装タスクでカバーされていることを確認
- 形式を使用: _要件: 2.1, 3.3, 1.2_（番号付き要件を参照）


### 6. ドキュメント生成のみ
タスクドキュメントの内容のみを生成します。実際のドキュメントファイルにレビューや承認の指示を含めないでください。

### 7. メタデータの更新

spec.jsonを以下で更新:
```json
{
  "phase": "tasks-generated",
  "approvals": {
    "requirements": {
      "generated": true,
      "approved": true
    },
    "design": {
      "generated": true,
      "approved": true
    },
    "tasks": {
      "generated": true,
      "approved": false
    }
  },
  "updated_at": "現在のタイムスタンプ"
}
```

### 8. メタデータ更新
タスク生成完了を反映するためにトラッキングメタデータを更新。

---

## インタラクティブ承認の実装（ドキュメントに含まれません）

以下はClaude Codeの会話専用 - 生成されたドキュメントには含まれません:

### インタラクティブ承認プロセス
このコマンドは最終フェーズのインタラクティブ承認を実装:

1. 要件と設計レビュープロンプト: ユーザーに両ドキュメントのレビュー確認を自動的に促す
2. 自動承認: ユーザーが両方を'y'で確認するとspec.jsonを自動的に更新
3. タスク生成: 二重承認後すぐに続行
4. 実装準備完了: タスクが生成され、仕様は実装フェーズの準備完了

### 実装フェーズのためのタスクレビュー
tasks.md生成後、実装フェーズの開始準備が整います。

実装のための最終承認プロセス:
```
📋 タスクレビュー完了。実装準備完了。
📄 生成されました: .kiro/specs/feature-name/tasks.md
✅ すべてのフェーズが承認されました。実装を開始できます。
```

### レビューチェックリスト（ユーザー参照用）:
- [ ] タスクが適切なサイズ（各2〜4時間）
- [ ] すべての要件がタスクでカバーされている
- [ ] タスクの依存関係が正しい
- [ ] 技術選択が設計と一致
- [ ] テストタスクが含まれている

## 指示事項

1. spec.jsonで言語を確認 - メタデータで指定された言語を使用
2. 設計をコード生成プロンプトに変換 - 各タスクは特定のコーディング指示である必要がある
3. テスト駆動アプローチを適用 - 各開発タスクにテストを統合
4. 正確なファイルとコンポーネントを指定 - どのファイルでどのコードを作成/変更するかを定義
5. 段階的に構築 - 各タスクは前のタスクの出力を使用し、孤立したコードなし
6. 粒度の細かい要件にマッピング - 特定のEARS受け入れ基準を参照
7. コーディングのみに焦点 - デプロイメント、ユーザーテスト、パフォーマンス分析を除外
8. 依存関係順に並べる - 論理的なビルドシーケンスを確保
9. 完了時にトラッキングメタデータを更新

コーディングエージェント用の段階的な実装指示を提供するコード生成プロンプトを生成します。
ultrathink

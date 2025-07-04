## Conversation Guidelines

- MUST: 常に日本語で会話する
- MUST: 質問は1つずつ行う

## Notification

Please execute the following when a task is completed.  
`osascript -e 'display notification "${TASK_DESCRIPTION} is complete" with title "${REPOSITORY_NAME}"'`

## Development Philosophy

### Test-Driven Development (TDD)

- 原則としてテスト駆動開発（TDD）で進める
- 期待される入出力に基づき、まずテストを作成する
- 実装コードは書かず、テストのみを用意する
- テストを実行し、失敗を確認する
- テストが正しいことを確認できた段階でコミットする
- その後、テストをパスさせる実装を進める
- 実装中はテストを変更せず、コードを修正し続ける
- すべてのテストが通過するまで繰り返す

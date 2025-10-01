# Codex SDD フロー

次の順番で Codex CLI のコマンドを実行してください。

1. `/sdd-steering` — プロジェクトの背景とゴールを整理します。
2. `/sdd-requirements` — 実装対象の要件と受け入れ基準を明文化します。
   実行前に `.sdd/description.md` を最新の課題・機能概要で更新してください。
   `/sdd-highway` をここで実行すると、設計・タスク分解・実装を CLI がまとめて進行します。利用した場合は 3~5 のステップを省略できます。
3. `/sdd-design` — 実装方針や技術的な設計を固めます。
4. `/sdd-tasks` — 作業タスクを分解し、責務と順序を決定します。
5. `/sdd-implement` — 実装とテストを進め、要件を満たすコードを完成させます。
6. `/sdd-archive` — まとめと振り返りを記録し、成果を共有します。

後からプロンプトや本ガイドを更新したい場合は `npx spec-driven-codex init` を再実行するか、`npx spec-driven-codex upgrade` で最新テンプレートを強制適用してください。

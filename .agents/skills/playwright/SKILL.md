---
name: playwright
description: playwright-cli を使ったブラウザ操作・動作確認。開発サーバーの表示確認、フォーム操作、スクリーンショット取得などに使用。
allowed-tools: Bash, Read, Glob
---

# Playwright CLI Skill

playwright-cli でブラウザを操作し、Webページの表示確認・動作検証を行う。

## 基本ワークフロー

```
open → snapshot → stdout から ref 取得 → 操作 → close → クリーンアップ
```

作業完了時は必ず以下を実行:

```bash
playwright-cli close && rm -rf .playwright-cli/
```

## よく使うコマンド

全コマンドは `playwright-cli --help` を参照。

```bash
# ブラウザを開く (--headed で目視確認可能)
playwright-cli open [url] [--headed]

# ページのスナップショット (stdout にアクセシビリティツリーが出力される)
playwright-cli snapshot

# ナビゲーション
playwright-cli goto <url>

# 要素操作 (ref は snapshot の stdout から取得)
playwright-cli click <ref>
playwright-cli fill <ref> <text>
playwright-cli type <text>

# スクリーンショット
playwright-cli screenshot [ref]

# タブ操作
playwright-cli tab-list
playwright-cli tab-new [url]

# ブラウザを閉じる
playwright-cli close
```

## スナップショットの使い方

snapshot を実行すると、stdout にアクセシビリティツリーが出力される。各要素に `ref=e1` のような参照IDが付いており、これを click, fill などに渡す。

```
$ playwright-cli snapshot
- heading "Example Domain" [level=1] [ref=e3]
- paragraph [ref=e4]: This domain is ...
  - link "Learn more" [ref=e6]
```

→ `playwright-cli click e6` でリンクをクリック

## セッション管理

```bash
# 名前付きセッション
playwright-cli -s=myapp open http://localhost:3000

# 既存セッション一覧
playwright-cli list

# 目視確認モード
playwright-cli open --headed
```

## クリーンアップ

`close` だけでは `.playwright-cli/` ディレクトリが残る。作業完了時に必ず削除する。

```bash
playwright-cli close && rm -rf .playwright-cli/
```

プロジェクトの `.gitignore` に `.playwright-cli/` を追加推奨。

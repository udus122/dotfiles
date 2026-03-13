# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

macOS環境のdotfiles管理リポジトリ。シンボリックリンクを使って設定ファイルをホームディレクトリに配置する。

## コマンド

```shell
make all        # 全セットアップ実行（link → init → brew の順）
make link       # シンボリックリンク作成（link.sh）
make init       # 初期設定（init.sh: Homebrew、Xcode CLI、Git設定など）
make install    # パッケージインストール（install.sh: brew bundle、krew、mise、Claude Code）
```

Brewfileの更新後は `brew bundle install --upgrade --global --cleanup` で反映。

## アーキテクチャ

### シンボリックリンクの仕組み

`link.sh` がリポジトリ内のドットファイル（`.*`）を `find` で検出し、`$HOME/` 配下に同じパスでシンボリックリンクを作成する。`.git/`、`.github/`、`.DS_Store` は除外。Karabiner-Elementsはディレクトリ単位でリンク（個別ファイルだと上書きされるため）。

`$HOME/.local/bin/` 配下にリンクされたファイルには自動で実行権限が付与される。

### XDG Base Directory

`.zshenv` でXDG環境変数を設定。設定ファイルは `.config/` 配下にXDG準拠で配置:

- zsh: `.config/zsh/`（ZDOTDIR）
- git: `.config/git/`（common, alias, ignore, templates）
- mise: `.config/mise/config.toml`
- delta, ghostty, sheldon, starship, nvim 等

### ツール管理

- Homebrew: `.Brewfile` でパッケージ・cask・Mac App Storeアプリを一括管理
- mise: `.config/mise/config.toml` でNode.js、Python、Go、Rust等のランタイムバージョン管理
- krew: `krew.txt` でkubectlプラグイン管理

### Git拡張コマンド

`.local/bin/` にカスタムgitサブコマンドを配置:
- `git-delete-gone`: リモートで削除済みのブランチをローカルから削除
- `git-delete-merged`: マージ済みブランチを削除
- `git-fixup`: fixupコミット作成
- `git-wt`: worktree操作のラッパー

### AI Coding Agent 設定

複数のAIコーディングエージェントの設定を管理:
- `.claude/`: Claude Code（settings.json, commands, skills, agents）
- `.codex/`: Codex（AGENTS.md, config.toml）
- `.gemini/`: Gemini（GEMINI.md, settings.json）

## 編集時の注意

- `init.sh` は冪等に書くこと（既にインストール済みの場合はスキップ）
- `link.sh` は既存の非シンボリックリンクファイルをスキップする（上書き防止）
- 設定ファイルの追加後は `make link` でシンボリックリンクを作成
- `CLAUDE.md` は `AGENTS.md` へのシンボリックリンク。編集時は `AGENTS.md` を直接編集すること

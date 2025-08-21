# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a personal dotfiles repository for macOS environment setup and configuration management. The repository uses shell scripts and symlinks to manage various tool configurations including zsh, git, neovim, and development tools.

## Repository Structure

- Configuration files are primarily stored in `.config/` directory following XDG Base Directory specification
- Shell configurations use zsh with `ZDOTDIR` set to `$XDG_CONFIG_HOME/zsh`
- All dotfiles are symlinked to home directory via `link.sh`

## Common Development Tasks

### Initial Setup (新しいPCの初期設定)
```bash
make all  # 全ての初期設定を実行
```

### Individual Setup Tasks
```bash
make init    # Homebrew, Git設定、macOS設定など基本的な初期化
make link    # dotfilesのシンボリックリンクを作成
make install # Homebrewパッケージをインストール (macOSのみ)
```

### After Modifying Configuration
- Shell configuration changes: `exec -l $SHELL` to reload
- New dotfiles: Run `make link` to create symlinks
- New Homebrew packages: Run `make install` to install

## Key Components

### Shell Environment (Zsh)
- Main configuration: `.config/zsh/.zshrc`
- Environment variables: `.zshenv` (sets XDG directories)
- Additional configs:
  - `.config/zsh/functions.zsh` - Utility functions
  - `.config/zsh/abbreviations.zsh` - zsh-abbr abbreviations
  - `.config/zsh/completion.zsh` - Completion settings
  - `.config/zsh/keybindings.zsh` - Key bindings

### Package Management
- Homebrew packages: `.Brewfile` (global Brewfile)
- Kubectl plugins: `krew.txt`
- Runtime versions: managed by mise (`.config/mise/config.toml`)

### Development Tools Configuration
- Git: `.config/git/` (alias, common, ignore, templates)
- Neovim: `.config/nvim/init.vim`
- Starship prompt: `.config/starship.toml`
- WezTerm: `.config/wezterm/wezterm.lua`
- Delta (git diff): `.config/delta/config`
- GitHub CLI: `.config/gh/config.yml`

### Shell Scripts
- `init.sh` - Installs Homebrew, Xcode tools, configures Git
- `link.sh` - Creates symlinks for all dotfiles
- `install.sh` - Installs Homebrew packages and krew plugins (macOS only)

## Important Notes

- The repository is designed to be idempotent - running scripts multiple times should be safe
- macOS-specific settings are applied in `init.sh` (e.g., VSCode key repeat settings)
- Git configuration uses include.path for modular configuration
- Shell history ignores common navigation commands and VSCode debug commands
- GNU/Linux versions of basic commands are installed and prioritized in PATH
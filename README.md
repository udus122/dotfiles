# Dotfiles

# Usage

## 新しいPCの初期設定を行う

### 1. リポジトリをクローンする

```shell
git clone https://github.com/udus122/dotfiles.git
```

### 2. 初期設定を行う

```shell
make all
```

## 既存の設定を修正する

### 既存のdotfileを修正する

シェルを再起動します。
シンボリックリンクを使って配置しているため、変更はダイレクトに反映されます。

```shell
exec -l $SHELL
```

## 初期設定(`init.sh`)の修正時

`init.sh`(Homebrewなど必要なツールをインストールやGitの設定などを行うシェルスクリプト)を修正した場合、
以下コマンドを実行します。

```
make init
```

`init.sh`は冪等に書くように心掛けてください。

## 新しい設定ファイルを追加した時

新しい設定ファイルを追加した場合、以下のコマンドを実行して、ホームディレクトリ配下にシンボリックリンクを配置することができます。

```shell
make link
```

## Brewfileに新しいツールを追加する

以下のコマンドでパッケージをインストールできます。

```shell
make brew
```

# References

[初心者向け,PCの環境をdotfilesで一瞬で構築する方法(mac) #ShellScript - Qiita](https://qiita.com/kez/items/e349a8d025acbcdc3a86)

---
name: new-demo
description: 打ち合わせで出た「こういうことはできますか」を、パスワード付きのデモ URL (https://demo.queria.io/<name>/) にする。「デモを作って」「この要件でデモを出して」「さっきの話を見せられる形にして」などで使う。デモの撤収 (「デモを消して」) もこのスキルから。
---

# new-demo

デモの本体と手順は queria-io/demos (private) にある。このスキルは入口だけを持つ。

1. `~/ws/ghq/github.com/queria-io/demos` が無ければ `gh repo clone queria-io/demos ~/ws/ghq/github.com/queria-io/demos` で取る。あれば origin の既定ブランチに揃える。手元のチェックアウトは別ブランチのまま古いことがある
   ```bash
   git -C ~/ws/ghq/github.com/queria-io/demos fetch origin
   git -C ~/ws/ghq/github.com/queria-io/demos remote set-head origin -a
   git -C ~/ws/ghq/github.com/queria-io/demos switch "$(git -C ~/ws/ghq/github.com/queria-io/demos rev-parse --abbrev-ref origin/HEAD | sed 's#^origin/##')"
   git -C ~/ws/ghq/github.com/queria-io/demos pull --ff-only
   ```
2. そのリポジトリの `CLAUDE.md` を読み、「新しいデモ」(撤収なら「撤収」) の手順に従う
3. 要件が 1〜2 文しかなくても、決めるのは次の 3 つだけでよい。残りは雛形の既定に任せる
   - デモの名前 (URL のパスになる)
   - 認証を掛けるか (既定は Basic 認証)
   - 使うデータ (Queria の公開データセットの表と、手元にある非公開のファイル)

デプロイとパスワードの設定は本番に出る操作なので、実行する前にユーザーに確認する。

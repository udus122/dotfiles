# requirements-japanese

要件定義書の日本語を、口頭の補足なしで読んだ人が「誰が・何を・どうするか」を復元できる文に直す Claude Code スキル。[natural-japanese](https://github.com/coji/natural-japanese) の工程をそのまま使い、次の3つを足す。

- 各文の主体・対象・動作・条件を表に書き出し、復元できない文を指摘して書き換える
- 要件定義書の文書タイプ
- 本人の文体を、背景・論点・判断理由などの説明部分にだけ当てる仕組み

消したい書き方は、横井公徳「[AI臭い文章とは何なのか](https://speakerdeck.com/nasuvitz/ai-kusai-bunshou-toha-nanina-no-ka)」の3類型(対比・否定・留保から入る文、抽象語・比喩の動詞、短文・対句・不自然な読点・名詞化)である。

## 導入

natural-japanese は改変せずに clone し、`~/.claude/skills/` へ symlink する。このスキルはそのファイルを参照する。

```bash
git clone https://github.com/coji/natural-japanese.git ~/ws/ghq/github.com/coji/natural-japanese
```

```bash
ln -s ~/ws/ghq/github.com/coji/natural-japanese/skills/natural-japanese ~/.claude/skills/natural-japanese
```

```bash
ln -s ~/dotfiles/.claude/skills/requirements-japanese ~/.claude/skills/requirements-japanese
```

実行には [uv](https://docs.astral.sh/uv/) が要る。初回の実行で sudachipy の辞書(約70MB)を取得する。

## natural-japanese の更新を取り込む

```bash
git -C ~/ws/ghq/github.com/coji/natural-japanese pull --ff-only
```

```bash
~/.claude/skills/requirements-japanese/scripts/check.sh
```

`check.sh` は、このスキルが参照する natural-japanese のファイルがあること、natural-japanese の lint の回帰テストが通ること、meaning_lint がスライドの5例文をすべて指摘し、自然な文書では何も指摘しないことを確かめる。失敗したら、参照先のパスや手順の変更を SKILL.md に反映する。

## 使い方

```
/requirements-japanese docs/requirements/xxx.md          既存の要件定義書を直す
/requirements-japanese write <素材>                      新しく書く
/requirements-japanese score docs/requirements/xxx.md    書き換えずに診断する
/requirements-japanese style <サンプル1> <サンプル2> ...  文体ファイルを作る・更新する
```

natural-japanese の `score` と `lint.py` は、これまでどおり単体でも使える。

meaning_lint だけを単体で実行する場合:

```bash
uv run ~/.claude/skills/requirements-japanese/scripts/meaning_lint.py <file>
```

## 文体ファイルを作る・更新する

文体ファイルは `~/knowledge/notes/writing-style.md` に置く。文体の材料に案件の文書を使うので、公開リポジトリの dotfiles には置かない。

1. 自分で書いた文章を3〜5本選ぶ。要件定義書の背景・判断理由の節、設計メモ、PR の説明文のように、判断の理由を書いている文章が向いている。AI と一緒に書いた文章は、自分で手を入れた版を使う
2. `/requirements-japanese style <ファイル1> <ファイル2> ...` を実行する
3. スキルが `assets/writer-style-template.md` の項目ごとに、2本以上のサンプルで確かめた傾向を書き出す。顧客名・部署名・人名・システム名は `〈顧客〉` などに置き換わる
4. 書き出された内容を読み、違うと思う項目を直すか、スキルに伝える
5. knowledge にコミットする

サンプルを足して更新するときも、同じコマンドにサンプルを渡す。文体ファイルに未コミットの手直しがあると、スキルは上書きせずに止まり、差分を報告する。追加の観察は差分として示されるので、確かめてから反映させる。

この文言は使わない、と決めた言い回しがあれば、そのままスキルに伝えると「避ける表現」に記録される。

文体ファイルに書くのは、論点の立て方・判断理由の書き方・用語の選び方の傾向だけである。言い回しの癖や比喩は書かない。説明部分に言い回しで書き手らしさを足すと、上の3類型がそのまま戻るためである。要件本文には文体ファイルを当てない。

## 構成

```
SKILL.md                          工程と呼び出し方
references/meaning-check.md       復元表の書き方と書き換えの規則
references/doctype-requirements.md 要件定義書の文書タイプ
references/style-scope.md         文体の反映範囲と、文体ファイルの作り方
assets/writer-style-template.md   文体ファイルのひな形
scripts/meaning_lint.py           意味欠落につながりやすい形の検出
scripts/check.sh                  回帰テスト
scripts/fixtures/                 スライドの5例文、架空の要件定義書
```

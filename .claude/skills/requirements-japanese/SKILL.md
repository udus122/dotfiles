---
name: requirements-japanese
description: 要件定義書・仕様書・設計文書の日本語を、口頭の補足なしで第三者が読んで「誰が・何を・どうするか」を復元できる文に書く・直すスキル。natural-japanese の工程に、文ごとの主体・対象・動作・条件の復元レビュー、要件定義書の文書タイプ、説明部分だけに当てる本人の文体を足す。「要件定義書を直して」「要件を書いて」「仕様書が AI っぽい」「要件定義書をレビューして」「要件定義書を採点して」などの依頼と、要件定義書に当てる自分の文体ファイルを作る・更新する依頼に使う。要件定義書以外の文書の推敲は natural-japanese を使う。
argument-hint: "[review|write|score|style] [対象ファイル・素材・文体サンプル]"
---

# requirements-japanese

要件定義書の日本語を書く・直すためのスキル。natural-japanese(`~/.claude/skills/natural-japanese/`)の工程を土台にし、次の3つを足す。

- 意味欠落のレビュー:各文の主体・対象・動作・条件を表に書き出し、復元できない文を直す
- 要件定義書の文書タイプ
- 本人の文体:背景・論点・判断理由などの説明部分にだけ当てる。要件本文には当てない

判定の基準は、口頭の補足なしで、資料を再配布された人が読んで理解できるかである。機械で拾える形は `scripts/meaning_lint.py` が拾い、意味の判断はあなたが復元表で行う。

## 始める前に

`~/.claude/skills/natural-japanese/SKILL.md` を読む。冒頭の規則(元にない内容を足さない)と §1〜7 の工程は、このスキルでもそのまま守る。以下は、その工程に足すもの・置き換えるものだけを書く。natural-japanese が見つからなければ、README の導入手順をユーザーに伝えて止める。

## 呼び出し方

- `/requirements-japanese [review] [quick|full] <ファイル>`:既存の要件定義書を直す(既定)
- `/requirements-japanese write [quick|full] <素材>`:新しく書く
- `/requirements-japanese score [quick|full|exp] <ファイル>`:書き換えずに診断する
- `/requirements-japanese style <サンプル...>`:文体ファイルを作る・更新する。`references/style-scope.md` の手順に従う

quick と full の選び方は natural-japanese と同じ。

## 工程

### 1. 文書タイプ

`references/doctype-requirements.md` を読む。natural-japanese の doctypes の代わりに使う。

### 2. 機械検出

natural-japanese の lint に加えて、meaning_lint を実行する。

```
uv run ~/.claude/skills/natural-japanese/scripts/lint.py --json --genre business <file>
uv run <このスキルのディレクトリ>/scripts/meaning_lint.py --json <file>
```

meaning_lint は、比喩に使われやすい動詞、「片方」「〜側に」、文頭の短い目的語の後の読点、短文の対句、抽象的な動作の言い方、要件本文の曖昧語を拾う。各文を要件本文(`requirement`)と説明(`explanation`)に分け、要件本文で見つかった装飾の疑いは critical にする。指摘の扱いは natural-japanese §4 と同じで、直したか、残したならその理由を記録する。

### 3. 意味欠落のレビュー

`references/meaning-check.md` に沿って、すべての文の復元表を書き出す。最後の文まで書き出してから直し始める。quick でも省かない。natural-japanese §3 の「段落ごとの確かめ」は、この復元表で代える。

主体の補い方は natural-japanese と扱いが違う。要件定義書では主体の明記が要るので、同じ文書で定義済みの主体を指していると前後の文から言えるときは補う。言えないときは `【要確認: 主体】` の枠を置いて聞く。枠の表記は natural-japanese の `【要確認】` にそろえ、何が足りないかを枠の中に書く。

doctype の必須要素(目的・範囲・用語など)が元の文書に無いときは、節を足さずに報告で伝える。

### 4. 文体

`references/style-scope.md` に沿って、`~/knowledge/notes/writing-style.md` を説明部分にだけ当てる。natural-japanese §1 の `style-profile.md` は読まない。

### 5. 収束と確かめ

natural-japanese §6 に加えて、次を確かめてから終える。

- meaning_lint をもう一度実行し、critical の指摘(要件本文・説明のどちらでも)がすべて直っているか、残した理由が記録されている。要件本文の critical(`stats.requirement_critical`)は、枠で置き換える以外の理由では残さない
- 直した要件本文の行を元の文書と並べ、文体ファイルに由来する変更が入っていない
- 復元表の「復元できない要素」が、`【要確認】` の枠だけになっている。枠はユーザーへの質問として報告にまとめる

枠を置いたことで natural-japanese の lint に新しく出た文長や書き出しの指摘は、「残す/枠による」と記録すれば、新しい指摘が無いものとして収束を判断してよい。

## 診断(score)

natural-japanese の `references/diagnose.md` の手順とスコア式をそのまま使い、自然度のスコアを出す。meaning_lint の結果はスコアに混ぜず、別の欄に並べる。

- 意味欠落:meaning_lint の件数(要件本文・説明の別)と、full 以上では復元表で「復元できない要素」が残った文の数
- 主な文を3つまで、行番号と、何が復元できないかを添えて挙げる

## 後片付け

復元表、lint の JSON、元の文書の写しは作業領域に置き、完了したら消す(natural-japanese §7)。ユーザーのプロジェクトに残すのは、直した文書だけである。

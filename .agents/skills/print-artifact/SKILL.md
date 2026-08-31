---
name: print-artifact
description: HTML から印刷物（チラシ・リーフレット・ポスター・配布資料）を作り、版面を実測で検証して、CMYK の入稿データまで書き出す。ネット印刷への入稿、塗り足しや安全域の確認、刷り色のくすみ、QR のサイズ、ブランドカラーと印刷用カラーの出し分けを扱うときに使う。「チラシを作る」「入稿データを作る」「CMYK にする」「印刷したらくすんだ」などで起動する。
---

# 印刷物を作る

紙は刷り直せない。**画面で判断せず、必ず測ってから確定する。**

このスキルの中身は、実際に A4 両面のリーフレットを入稿まで持っていったときの手順と、そこで踏んだ地雷である。

## 版面

仕上がり A4 210×297mm に、塗り足し 3mm を四辺に足して **216×303mm** で書き出す。文字と QR は仕上がり線から **5mm 以上内側**に置く。データ端からは 8mm。

`references/print-tokens.css` に `@page`、`.sheet`、`.pad`、`.sheets` の定義がある。これをそのまま使う。

背景の帯やフッターは塗り足し端まで到達させる。中途半端に止めると、断裁位置のばらつきで白が出る。

## 色は画面用と印刷用を分けて持つ

**これが一番間違えやすい。** 鮮やかな紫・オレンジ・緑は CMYK の色域外で、そのまま入稿すると彩度が落ちてくすむ。ネット印刷の自動変換に任せると、変換先をこちらで選べない。

`references/print-tokens.css` の3層構造を使う。

1. パレット層に生の色を置く。画面用と印刷用を別の名前で両方持つ
2. 役割層（`--primary` など）はパレットを参照するだけ
3. `@media print` で役割層だけを印刷用に差し替える

**コンポーネントは役割トークンだけを参照し、生の色を書かない。** これを守れば、PDF に書き出した瞬間に印刷用の色が自動で効く。ビルド時の文字列置換は使わない。ソースを見ても印刷用の色の存在が分からず、忘れられるため。

印刷用の色は、画面用と同じ色相のまま**明度を下げる**方向で選ぶ。彩度を上げようとすると色相が動く（紫なら赤紫に転ぶ）。実測例は `references/print-tokens.css` のコメントにある。

## 作って測る

### 1. 検証

`references/probe.js` を `</head>` の直前に注入した複製を作り、headless Chrome の `--dump-dom` で `<pre id="METRICS">` を読む。

```bash
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
"$CHROME" --headless --disable-gpu --window-size=1800,1300 --virtual-time-budget=15000 \
  --dump-dom "file://$PWD/probe.html"
```

出るもの: ページ寸法、はみ出し量、最小フォント、安全域を割った要素、ブロックごとの高さ、画像の実効 dpi、`overflow: hidden` の中で溢れている行。

**文言を1文字でも変えたら、これを回してから次に進む。** 1行増えるだけで数 mm はみ出す。

ブロック高さの合計が版面（303mm）に収まっているかで、どこを削るか判断する。`flex-grow: 1` を持つブロックが余りを吸うので、合計が 300mm 前後なら収まっている。

### 2. 実インクの位置

安全域の判定は要素のボックスで出るが、実際のインクは行の余白のぶん内側にある。境界が疑わしいときは PDF を高解像度で描画して画素を走査する。

```python
px = doc[0].get_pixmap(dpi=384)
# 帯の中の白文字なら「ほぼ白」の画素、白地の黒文字なら「非白」の画素の最外周を取る
```

ボックスで 6.7mm でも、実インクは 8.9mm（仕上がり線から 5.9mm）ということがある。

### 3. PDF

```bash
"$CHROME" --headless --disable-gpu --no-pdf-header-footer --virtual-time-budget=15000 \
  --print-to-pdf="$PWD/out-rgb.pdf" "file://$PWD/source.html"
```

ページ数と寸法（215.9×303.0mm）を必ず確認する。

## CMYK に変換する

Ghostscript を使う。**自動変換に任せず、各版の数値をこちらで決める。**

```bash
gs -dBATCH -dNOPAUSE -sDEVICE=pdfwrite -dAutoRotatePages=/None \
   -sColorConversionStrategy=CMYK \
   -dDownsampleColorImages=false -dDownsampleGrayImages=false -dDownsampleMonoImages=false \
   -dAutoFilterColorImages=false -dColorImageFilter=/FlateEncode \
   -dAutoFilterGrayImages=false -dGrayImageFilter=/FlateEncode \
   -sOutputFile=out-cmyk.pdf out-rgb.pdf
```

### 踏んではいけないもの

- **`-dBlackVector=true` を使わない。** 薄い色の面まで黒く潰す。ヘッダーの帯もカードの背景も真っ黒になる
- **`-dOverrideICC` を出力プロファイルだけ指定して使わない。** RGB の内容を CMYK プロファイルで解釈して、白が黒に転ぶ
- **ダウンサンプルと自動フィルタを切る。** 既定だと画像が JPEG に再圧縮され、文字を含むスクリーンショットが劣化する

### 変換後の確認

版ごとの数値は CMYK の TIFF に落として読む。

```bash
gs -dBATCH -dNOPAUSE -sDEVICE=tiff32nc -r200 -dFirstPage=1 -dLastPage=1 \
   -sOutputFile=p1.tif out-cmyk.pdf
```

PIL で開くと mode が CMYK になる。値は 0-255 なので `v/255*100` で % に直す。面積の大きい色を数えて、帯・フッター・本文がそれぞれ想定の配合になっているか見る。

総インキ量も見る。コート紙で 300〜350% が上限。フッターのベタが 284% など、超えていないか確認する。

**刷り色のシミュレーションを必ず目で見る。** 変換後の PDF を画像に描画すると、刷り上がりに近い見え方が出る。画面の色で判断しない。

### K 単色にはならない

Chrome の PDF は ICC 付きの RGB で色を書くため、`-dBlackText` は発火せず、本文の黒も QR も4色黒になる（185〜284%）。

実害は小さい。版ズレは 0.1mm 程度で、ネット印刷はこの入稿を日常的に刷っている。QR も 1 モジュール 0.4mm 以上あれば読み取りに影響しない。**追いかけるとかなりの時間を使うので、他が固まってから触ること。**

## QR

`segno` で生成し、誤り訂正は M。

**1 モジュールの実寸が 0.4mm を下回らないこと。** 16mm 角に収める場合、33 モジュール（版3）で 0.485mm。URL を長くすると版が上がってモジュールが小さくなるので、生成前にモジュール数を確認する。

```python
q = segno.make(url, error='m')
print(q.symbol_size(border=2)[0], "モジュール")   # 16 / n が 1 モジュールの mm
```

計測用のパラメータは `?utm_source=...` を直接焼き込まず、`?s=leaflet` のような短いキーにしてサーバー側で utm に変換する。utm を入れると版が上がってモジュールが 0.39mm まで落ちる。キャンペーン名を後から変えても刷り直しが要らない利点もある。

インライン SVG で埋める場合、segno は `viewBox` を出さないので、`width`/`height` を `viewBox` に置き換える。`path { fill: none }` も要る。

## 文言

紙は読み返されない。10 秒で通る文だけを載せる。

- 比喩を使わない（「体力がない」など）
- 評価語ではなく差分を書く。「使いやすい」と言わず、何が要らなくなるかを書く
- AI 特有の抽象表現を避ける。「読める」「聞ける」だけで中身がない言い方をしない
- 実装されていない機能を書かない
- 並列する項目は文末を揃える。1つだけ体言止めにしない
- 欧文の前後に空きを入れる（`CSV や Excel`、`AI エージェント`）。1箇所だけ抜けると目立つ
- 課題を挙げたら答える。挙げっぱなしは「ここは解決しない」と読まれる

## 進め方

1. 版面と役割トークンを敷く
2. 内容を入れる。**変えるたびに検証を回す**
3. 収まりを詰める。文字サイズより先に余白（padding, margin, gap）を 0.4〜0.8mm ずつ削る
4. RGB の PDF を書き出す
5. CMYK に変換し、刷り色を目で見て、版の数値を確認する
6. 入稿

外に出す紙は、提出前に第三者に一度読んでもらう。同じ紙面を見続けると見落としが残る。

書き出した PDF を Google Drive に置いて共有する場合は、**drive-deliverable スキル**に従う。
共有リンクを保ったまま差し替えるには、ファイルを作り直さず同じパスに上書きする必要がある。

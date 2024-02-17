"#####表示設定#####
set number "行番号を表示する
set list "タブ、空白、改行を可視化
set ruler "カーソル位置を表示
set title "編集中のファイル名を表示
set showmatch "括弧入力時の対応する括弧を表示
set tabstop=4 "インデントをスペース4つ分に設定
set smartindent "オートインデント
syntax on "コードの色分け

"#####検索設定#####
set ignorecase "大文字/小文字の区別なく検索する
set smartcase "検索文字列に大文字が含まれている場合は区別して検索する
set wrapscan "検索時に最後まで行ったら最初に戻る
nnoremap <Esc><Esc> :nohlsearch<CR> " Escを2回押すとハイライトを消す

" 自動に作られるファイルを作らない
set noswapfile " swpファイル出力無効
set nobackup " バックアップファイル出力無効
set noundofile " undoファイル出力無効

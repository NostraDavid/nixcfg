" Use Vim settings, rather than Vi settings (much better!)
" This must be first, because it changes other options as a side effect.
set nocompatible

" This vimrc stays intentionally small and portable.
" It now assumes a regular Vim build (not Debian's `vim-tiny`) so we can use
" `:let` for `<Leader>`, while still avoiding heavier runtime/plugin features.

" Set leader early so mappings can rely on it.
let mapleader = " "

" Keep the audible bell off; a visual bell is fine.
set noswapfile
set nobackup
set visualbell

" Enable line numbers
set number

" Make backspace behave like most editors.
set backspace=indent,eol,start

" Set tab width to 4 spaces
set tabstop=4
set shiftwidth=4
set expandtab

" Set the encoding to UTF-8
set encoding=utf-8

" Search UX
set incsearch
set hlsearch
set ignorecase
set smartcase

" Avoid wrapping by default; this config is mainly used for code/config files.
set nowrap

" Enable autoindent
set autoindent
" `smartindent` is geared toward C-like syntax and can do the wrong thing for
" YAML, Python, Markdown, and shell files, so keep plain `autoindent` instead.
" set smartindent

" Command-line completion.
set wildmenu
set wildmode=longest:full,full

" Auto reload file when changes are made externally
set autoread

" Mouse support is available (+mouse) in this build.
set mouse=a

" Small quality-of-life settings.
set showcmd
set ruler
set history=1000

" Minimal mappings.
" Reserve <Space> for <Leader> mappings instead of normal-mode right-movement.
nnoremap <Space> <Nop>
" Clear search highlight
nnoremap <silent> <Esc><Esc> :nohlsearch<CR>

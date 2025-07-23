" Use Vim settings, rather than Vi settings (much better!)
" This must be first, because it changes other options as a side effect.
set nocompatible
set noswapfile
set nobackup
set novisualbell

" Enable line numbers
set number

" Enable syntax highlighting
syntax enable

" Set tab width to 4 spaces
set tabstop=4
set shiftwidth=4
set expandtab

" Set the encoding to UTF-8
set encoding=utf8

" Enable mouse in all modes
set mouse=a

" Enable incremental search
set incsearch

" Highlight current line
set cursorline

" Enable line wrapping
set wrap

" Set the color scheme
colorscheme desert

" Enable autoindent
set autoindent

" Set status line always on
set laststatus=2

" Enable clipboard
set clipboard=unnamedplus

" Ignore case when searching
set ignorecase

" Auto reload file when changes are made externally
set autoread

" Enable spell check for English language
"set spell spelllang=en

" Set cursor shape to block when in insert mode
let &t_SI = "\<Esc>[5 q"
let &t_EI = "\<Esc>[1 q"

" Plugin management with vim-plug
" Add this line to your .vimrc file, then restart Vim and run :PlugInstall
call plug#begin('~/.vim/plugged')

" You can add your plugins here

Plug 'airblade/vim-gitgutter'
Plug 'Chiel92/vim-autoformat'
Plug 'dense-analysis/ale'
Plug 'junegunn/fzf.vim'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'LnL7/vim-nix'
Plug 'mbbill/undotree'
Plug 'mhinz/vim-startify'
Plug 'preservim/nerdcommenter'
Plug 'scrooloose/nerdtree', { 'on':  'NERDTreeToggle' }
Plug 'tomasiser/vim-code-dark'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-sensible'
Plug 'tpope/vim-surround'
Plug 'vim-airline/vim-airline'
Plug 'vim-python/python-syntax'

call plug#end()

" python-syntax settings
let g:python_highlight_all = 1

colorscheme codedark

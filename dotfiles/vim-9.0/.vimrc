" Vim 9.1 full configuration
set nocompatible
set noswapfile
set nobackup
set novisualbell

" Core editing behavior
set number
set expandtab
set tabstop=4
set shiftwidth=4
set softtabstop=4
set autoindent
set wrap
set laststatus=2
set ignorecase
set incsearch
set autoread

" UI and interaction
set encoding=utf-8
set mouse=a
set cursorline
set clipboard=unnamedplus

" Syntax and fallback colorscheme
syntax enable
colorscheme desert

" Cursor shape
let &t_SI = "\<Esc>[5 q"
let &t_EI = "\<Esc>[1 q"

" Plugin management with vim-plug (only when installed)
if exists('*plug#begin')
  call plug#begin('~/.vim/plugged')

  Plug 'airblade/vim-gitgutter'
  Plug 'Chiel92/vim-autoformat'
  Plug 'dense-analysis/ale'
  Plug 'junegunn/fzf.vim'
  Plug 'junegunn/fzf', { 'do': ':call fzf#install()' }
  Plug 'LnL7/vim-nix'
  Plug 'mbbill/undotree'
  Plug 'mhinz/vim-startify'
  Plug 'preservim/nerdcommenter'
  Plug 'scrooloose/nerdtree', { 'on': 'NERDTreeToggle' }
  Plug 'tomasiser/vim-code-dark'
  Plug 'tpope/vim-fugitive'
  Plug 'tpope/vim-sensible'
  Plug 'tpope/vim-surround'
  Plug 'vim-airline/vim-airline'
  Plug 'vim-python/python-syntax'

  call plug#end()

  let g:python_highlight_all = 1
  if globpath(&runtimepath, 'colors/codedark.vim') != ''
    colorscheme codedark
  endif
endif

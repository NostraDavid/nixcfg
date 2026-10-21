#!/usr/bin/env bash
# This editor has no parent shell to resume it after Ctrl+z.
exec nvim -c 'noremap <C-z> <Cmd>qall<CR>' "$@"

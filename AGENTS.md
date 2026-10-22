# Dotfiles

Every deployed file from `dotfiles/` MUST remain directly symlinked to the live
checkout. NO EXCEPTIONS. Do not copy, render, template, or regenerate these
files. Keep machine-specific paths in executable wrappers or the process
environment. Edits to dotfiles must take effect without `just switch`.

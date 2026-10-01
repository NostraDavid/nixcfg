# Shell command history

- Invoke every `functions.exec_command` with `login: false` so shell commands do
  not get written to `~/.bash_history`.
- If a task needs login-shell environment, set the required environment
  explicitly and keep `login: false`.

---
name: audio-notify
description: Speak a notification with say before asking the user a question or handing over a completed task, including a finished plan or verified change. Apply at these moments regardless of the task domain.
---

# Audio notifications

Run the bundled command once at each user-facing handoff, with the working
directory inside the task's repository. Resolve `scripts/notify.sh` relative to
this `SKILL.md`; the shared installation is `~/.agents/audio-notify/`.

| Moment                                                                           | Command argument |
| -------------------------------------------------------------------------------- | ---------------- |
| Ask the user for information, a choice, clarification, or approval               | `question`       |
| Deliver a completed task, such as a requested plan, analysis, or verified change | `done`           |

For a question, run the command immediately before sending the question or
calling an input tool that may wait for a reply. A batch of questions needs one
notification. This also applies to asynchronous input tools.

For completion, finish the work and its relevant checks first, then run the
command immediately before the final handoff. A plan counts when the requested
deliverable is a plan; an internal plan during implementation does not. If the
handoff asks for a reply, use `question` alone.

```bash
"$HOME/.agents/audio-notify/scripts/notify.sh" question "Welke stem wil je gebruiken?"
"$HOME/.agents/audio-notify/scripts/notify.sh" done "Repositorynaam toegevoegd aan de meldingen."
```

Always supply a short, task-specific message as the second argument. Use one
sentence of at most twelve words. For completion, name what was finished and,
when useful, its result or the user's next step. For a question, name the input
needed. Keep file lists, commit hashes, and technical details in the written
reply. Quote the message as one shell argument.

Choose the one command matching the event. Invoke it through the available shell
tool. Only the agent talking to the user plays notifications. Progress updates,
internal substeps, quoted questions, and subagent messages are silent. An
incomplete or blocked task does not get a completion sound.

The script speaks "biep boep", the repository name, then your message. For
example: "biep boep. nixcfg. Repositorynaam toegevoegd aan de meldingen." It
derives the repository name from the shared Git directory, so subdirectories and
sibling worktrees keep the same name. For this repository layout, `nixcfg/trunk`
and `nixcfg/codex-task` both identify `nixcfg`. Outside Git it omits the
repository name. The notification script adds the spoken prefix; keep written
replies free of this prefix. It requires an executable `say` and `timeout` on
`PATH`; a shell alias cannot be called by `timeout`. Home Manager installs
`say.sh` as `~/.local/bin/say`, using `espeak-ng`. Playback gets ten seconds to
finish, followed by a one-second kill grace period. A successful command does
not prove that the user heard it.

Report a missing command, playback failure, or tool restriction briefly once per
session, then continue with the question or result. Do not retry notifications,
substitute another player, or change tool permissions to make a sound play.

Set `AGENT_NOTIFY_MUTE=1` to disable playback. An explicit request for silence
also suppresses notifications for its stated duration. Use the existing voice,
device, and volume settings.

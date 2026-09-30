#!/usr/bin/env bash

# Source global definitions.
if [ -f /etc/bashrc ]; then
    # shellcheck source=/dev/null
    . /etc/bashrc
fi

# shellcheck source=bashrc.d/environment.bash
. "$HOME/.bashrc.d/environment.bash"

case $- in
*i*) ;;
*)
    return
    ;;
esac

# shellcheck source=bashrc.d/interactive.bash
. "$HOME/.bashrc.d/interactive.bash"
# shellcheck source=bashrc.d/prompt.bash
. "$HOME/.bashrc.d/prompt.bash"
# shellcheck source=bashrc.d/options.bash
. "$HOME/.bashrc.d/options.bash"
# shellcheck source=bashrc.d/functions.bash
. "$HOME/.bashrc.d/functions.bash"
# shellcheck source=bashrc.d/python.bash
. "$HOME/.bashrc.d/python.bash"
# shellcheck source=bashrc.d/integrations.bash
. "$HOME/.bashrc.d/integrations.bash"

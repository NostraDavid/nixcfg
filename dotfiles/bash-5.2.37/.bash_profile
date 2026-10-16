# ~/.bash_profile
[ -r /etc/profile ] && . /etc/profile
[ -r "$HOME/.bashrc" ] && . "$HOME/.bashrc"

if [ -r "$HOME/.bash_profile.work" ]; then
    # shellcheck source=/dev/null
    . "$HOME/.bash_profile.work"
fi

# Start a fresh Debian 13 shell and remove the container when it exits.
debian-shell:
  @podman run --pull=always --rm --interactive --tty docker.io/library/debian:13 bash

#!/usr/bin/env bash
# Run the public upgrade recipe with local release/build fixtures and inert deployment commands.
set -euo pipefail
repo=$(git rev-parse --show-toplevel)
# Hooks can export Git paths belonging to the caller. Keep all fixture writes in the temp repo.
mapfile -t git_vars < <(git rev-parse --local-env-vars)
unset "${git_vars[@]}"
tmp=$(mktemp -d)
logs=()
trap 'rm -rf "$tmp" "${logs[@]}"' EXIT
export REAL_JUST
REAL_JUST=$(command -v just)
export TRACE="$tmp/trace" PATH="$tmp/bin:$PATH" NIXCFG_CODEX_REVIEW=1 XDG_RUNTIME_DIR="$tmp/runtime"
mkdir -p "$tmp/bin" "$tmp/runtime" "$tmp/repo/scripts" "$tmp/repo/pkgs/t3code"
cd "$tmp/repo"
cp "$repo/Justfile" .
cp -R "$repo/just" .
cp "$repo/scripts/update-review.py" scripts/
touch scripts/github-auth.sh
echo '{"root":"root","nodes":{"root":{"inputs":{}}}}' >flake.lock
cat >"$tmp/bin/sudo" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == -n ]]; then
    exit "${TEST_CACHED_SUDO_STATUS:-0}"
fi
[[ "$*" == -v ]] || exit 2
echo 'sudo -v' >>"$TRACE"
exit "${TEST_SUDO_STATUS:-0}"
EOF
cat >"$tmp/bin/just" <<'EOF'
#!/usr/bin/env bash
case "$1" in
    switch | gc-old)
        [[ "$2" == --non-interactive ]] || exit 2
        echo "$1" >>"$TRACE"
        echo "ran $1" >&2
        if [[ $1 == "${FAIL_STAGE:-}" ]]; then exit 29; fi ;;
    cachix-push-all) echo "$1" >>"$TRACE"; echo "ran $1" ;;
    forgejo-support-warning) ;;
    *) exec "$REAL_JUST" "$@" ;;
esac
EOF
cat >"$tmp/bin/nix" <<'EOF'
#!/usr/bin/env bash
echo update >>"$TRACE"
if [[ $(cat flake.nix) == broken ]]; then echo 'broken flake'; exit 19; fi
EOF
cat >scripts/local-package-maint.sh <<'EOF'
#!/usr/bin/env bash
set -eu
if [[ $1 == packages ]]; then printf 'ok\nt3code\n'; exit; fi
[[ ${NIXCFG_SKIP_UNCHANGED:-0} == 1 ]]
echo 'Authorization: Bearer fixture-secret'
echo "checked package $2"
if [[ -n ${RUN_ONLY_TOKEN:-} ]]; then echo "diagnostic value: $RUN_ONLY_TOKEN"; fi
if [[ $2 == ok ]]; then echo 'warning: fixture package advisory'; fi
echo "$2" >>"$TRACE"
if [[ $2 == t3code ]]; then
    case "$(cat pkgs/t3code/default.nix)" in
        broken) echo 'original hash error'; exit 1 ;;
        diagnostic*) echo 'retry found a renamed release asset'; exit 1 ;;
        fixed) echo 'package build passed' ;;
        *) exit 2 ;;
    esac
fi
EOF
cat >"$tmp/bin/codex" <<'PY'
#!/usr/bin/env python3
import json, subprocess, sys, time
from pathlib import Path
prompt = sys.stdin.read()
(Path(__file__).resolve().parents[1] / "codex-calls").open("a").write(prompt.splitlines()[0] + "\n")
assert not sys.stdin.isatty() and 'approval_policy="never"' in sys.argv
logs = Path(".git/update-logs")
log = (logs / "output.log").read_text()
assert "fixture-secret" not in log
if "Review this upgrade run" in prompt:
    if "broken flake" in log:
        assert not list((logs / "pkgs").glob("*.log"))
    else:
        assert "warning: fixture package advisory" in (logs / "pkgs/ok.log").read_text()
        assert "checked package t3code" in (logs / "pkgs/t3code.log").read_text()
        assert "fixture-secret" not in (logs / "pkgs/t3code.log").read_text()
        assert "transient-upgrade-secret" not in (logs / "pkgs/t3code.log").read_text()
    if "ran gc-old" in log:
        assert "ran switch" in log and "ran cachix-push-all" in log
scenario = Path("scenario").read_text().strip()
if scenario == "timeout":
    import fcntl
    job = Path.cwd().parent
    Path("pkgs/t3code/default.nix").write_text("would apply after silence\n")
    with (job / "process.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        # A surviving child would keep the lock even after the worker died.
        child = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(10)"], pass_fds=(lock.fileno(),))
        print("about to fall silent", flush=True)
        child.wait()
if scenario == "follow":
    marker = f"review running {Path.cwd().parent.name}"
    print(marker, flush=True)
    terminal = Path(__file__).resolve().parents[1] / "terminal.log"
    for _ in range(500):
        if marker in terminal.read_text(): break
        time.sleep(.01)
    else: raise SystemExit("progress did not reach the terminal while the review was running")
    for _ in range(8):
        print("progress", flush=True)
        time.sleep(.2)
    print("review finishing", file=sys.stderr, flush=True)
target = Path("pkgs/t3code/default.nix")
outcome = "fixed" if scenario == "timeout" else "clean"
if "broken flake" in log:
    Path("flake.nix").write_text("valid\n")
    outcome = "fixed"
elif "original hash error" in log and scenario != "unresolved":
    target.write_text("fixed\n")
    outcome = "fixed"
elif "original hash error" in log or "ran switch" in log and "ran gc-old" not in log:
    outcome = "unresolved"
Path(sys.argv[sys.argv.index("--output-last-message")+1]).write_text(json.dumps({"outcome":outcome,"summary":"fixture"}))
PY
chmod +x "$tmp/bin/"* scripts/local-package-maint.sh
git init -q
echo repair >scenario
echo valid >flake.nix
echo broken >pkgs/t3code/default.nix
git add .
git -c core.hooksPath=/dev/null -c user.name=test -c user.email=test@localhost commit -qm fixture
if "$REAL_JUST" fix >"$tmp/terminal.log" 2>&1; then exit 1; fi
rg -q 'No completed upgrade' "$tmp/terminal.log"

status=0
TEST_SUDO_STATUS=17 "$REAL_JUST" upgrade >"$tmp/terminal.log" 2>&1 || status=$?
[[ $status == 17 && $(cat "$TRACE") == 'sudo -v' ]]
if rg -q '^real[[:space:]]' "$tmp/terminal.log"; then exit 1; fi
for recipe in switch gc-old; do
    status=0
    TEST_CACHED_SUDO_STATUS=23 "$REAL_JUST" "$recipe" --non-interactive >"$tmp/terminal.log" 2>&1 || status=$?
    [[ $status == 23 ]]
done
run_recipe() {
    status=0
    "$REAL_JUST" "$@" >"$tmp/terminal.log" 2>&1 || status=$?
    mapfile -t jobs < <(sed -nE 's,^Codex: (/tmp/just-fix\.[a-zA-Z0-9_]+)/status$,\1,p' "$tmp/terminal.log")
    logs+=("${jobs[@]}")
}
: >"$TRACE"
RUN_ONLY_TOKEN=transient-upgrade-secret run_recipe upgrade
[[ $status == 1 && ! -e "$tmp/codex-calls" ]]
[[ $(cat "$TRACE") == $'sudo -v\nupdate\nok\nt3code' ]]
rg -q '^real[[:space:]]' "$tmp/terminal.log"
git -c core.hooksPath=/dev/null worktree add --quiet --detach "$tmp/other" HEAD
if (cd "$tmp/other" && "$REAL_JUST" fix) >"$tmp/terminal.log" 2>&1; then exit 1; fi
rg -q 'No completed upgrade' "$tmp/terminal.log"
run_recipe fix
[[ $status == 0 && $(cat pkgs/t3code/default.nix) == fixed ]]
rg -q '^Codex applied:' "$tmp/terminal.log"
[[ $(cat "$TRACE") == $'sudo -v\nupdate\nok\nt3code' ]]

: >"$TRACE"
run_recipe upgrade
[[ $status == 0 && $(wc -l <"$tmp/codex-calls") == 1 ]]
[[ $(cat "$TRACE") == $'sudo -v\nupdate\nok\nt3code\nswitch\ncachix-push-all\ngc-old' ]]
run_recipe fix
[[ $status == 0 ]]
rg -q '^Codex clean:' "$tmp/terminal.log"

: >"$TRACE"
FAIL_STAGE=switch run_recipe upgrade
[[ $status == 29 && $(wc -l <"$tmp/codex-calls") == 2 ]]
[[ $(tail -n1 "$TRACE") == switch ]]
run_recipe fix
[[ $status == 1 ]]
rg -q '^Codex unresolved:' "$tmp/terminal.log"
rg -q 'Review this upgrade run \(exit 29\)' "$tmp/codex-calls"

# A manual edit between the upgrade and the fix must survive the review.
echo broken >pkgs/t3code/default.nix
run_recipe upgrade
[[ $status == 1 ]]
echo 'my manual edit' >pkgs/t3code/default.nix
run_recipe fix
[[ $status == 1 && $(cat pkgs/t3code/default.nix) == 'my manual edit' ]]
rg -q '^Codex conflict:' "$tmp/terminal.log"

echo broken >flake.nix
: >"$TRACE"
run_recipe upgrade
[[ $status == 19 && $(cat "$TRACE") == $'sudo -v\nupdate' ]]
run_recipe fix
[[ $status == 0 && $(cat flake.nix) == valid ]]

echo follow >scenario
echo valid >flake.nix
echo fixed >pkgs/t3code/default.nix
git add .
git -c core.hooksPath=/dev/null -c user.name=test -c user.email=test@localhost commit -qm follow
for recipe in update pkgs fix; do
    args=("$recipe" --follow)
    if [[ $recipe == fix ]]; then
        run_recipe upgrade
        [[ $status == 0 ]]
        args=(fix)
    fi
    NIXCFG_REVIEW_WAIT_SECONDS=1 "$REAL_JUST" "${args[@]}" >"$tmp/terminal.log" 2>&1
    mapfile -t jobs < <(sed -nE 's,^Codex: (/tmp/just-(pkgs|update|fix)\.[a-zA-Z0-9_]+)/status$,\1,p' "$tmp/terminal.log")
    logs+=("${jobs[@]}")
    [[ $(rg -c '^review running ' "$tmp/terminal.log") == 1 ]]
    [[ $(rg -c '^review finishing$' "$tmp/terminal.log") == 1 ]]
    [[ $(rg -c '^Codex clean: fixture$' "$tmp/terminal.log") == 1 ]]
done

echo timeout >scenario
git add scenario
git -c core.hooksPath=/dev/null -c user.name=test -c user.email=test@localhost commit -qm timeout
for recipe in update pkgs fix; do
    : >"$TRACE"
    args=("$recipe" --follow)
    expected_status=0
    if [[ $recipe == fix ]]; then
        run_recipe upgrade
        [[ $status == 0 ]]
        : >"$TRACE"
        args=(fix)
        expected_status=124
    fi
    status=0
    output=$(NIXCFG_REVIEW_WAIT_SECONDS=1 "$REAL_JUST" "${args[@]}" 2>&1) || status=$?
    job=$(sed -nE 's,^Codex: (/tmp/just-(pkgs|update|fix)\.[a-zA-Z0-9_]+)/status$,\1,p' <<<"$output")
    [[ -d "$job" ]]
    logs+=("$job")
    [[ $status == "$expected_status" && $output == *"about to fall silent"* && $output == *"No review output for 1s"* ]]
    [[ $(head -1 "$job/status") == timed-out ]]
    if [[ $recipe == fix ]]; then [[ ! -s "$TRACE" ]]; fi
    python3 -c 'import fcntl, sys; lock = open(sys.argv[1]); fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB); lock.close()' "$job/process.lock"
    [[ ! -e "$job/review.json" && $(cat pkgs/t3code/default.nix) == fixed ]]
done
echo 'Upgrade logging and on-demand fixes passed.'

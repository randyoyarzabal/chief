#!/usr/bin/env bash
# Copyright (C) 2025 Randy E. Oyarzabal <github@randyoyarzabal.com>
########################################################################
# Chief Test Suite - Release Tooling Tests (libs/dev)
#
# Exercises the dev-only release plugin end to end against a scratch copy of the
# project: a local bare repository stands in for GitHub and a stub `gh` records
# pull requests, checks, merges and releases. Nothing touches the real checkout,
# the real remote, or the user's config.
#
# Covers:
#   - the dev-tools gate (dev branch + CHIEF_CFG_DEV_TOOLS) and that main never loads it
#   - --next validation (required, format, newer than the release)
#   - dry run and status change nothing
#   - a full publish: release on main, tag, GitHub release, next -dev cycle on dev
#   - re-running after success, and resuming after a failed step
#   - the retarget hint in chief.release_status: its printed commands, run as-is, work
#   - the step-progress helper's plain output
########################################################################

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMP_DIR="${TMPDIR:-/tmp}/chief-release-tests-$$"

TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

cleanup() { [[ -n "${CHIEF_TEST_KEEP:-}" ]] || rm -rf "$TEMP_DIR"; }  # CHIEF_TEST_KEEP=1 keeps the scratch dir
trap cleanup EXIT

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[PASS]${NC} $1"; PASSED_TESTS=$((PASSED_TESTS + 1)); }
log_error()   { echo -e "${RED}[FAIL]${NC} $1"; FAILED_TESTS=$((FAILED_TESTS + 1)); }

check() { # <label> <command...>
    local label="$1"; shift
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if "$@"; then log_success "$label"; else log_error "$label"; fi
}

contains()     { grep -qF -- "$2" "$1"; }
not_contains() { ! grep -qF -- "$2" "$1"; }

# Isolated git config: no signing, fixed identity, nothing from the user's ~/.gitconfig.
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL="$TEMP_DIR/gitconfig"

# Build: remote.git (bare "GitHub"), work/ (Chief checkout on dev), bin/gh (stub).
# The scratch project is normalized to a synthetic version so tests never depend on the real one.
setup() {
    local start="v9.8.0-dev"
    rm -rf "$TEMP_DIR"; mkdir -p "$TEMP_DIR/bin" "$TEMP_DIR/gh"
    printf '[user]\n\tname = Release Test\n\temail = release-test@example.com\n[commit]\n\tgpgsign = false\n[tag]\n\tgpgsign = false\n[init]\n\tdefaultBranch = main\n' > "$GIT_CONFIG_GLOBAL"

    local work="$TEMP_DIR/work"
    mkdir -p "$work"
    (cd "$PROJECT_ROOT" && tar --exclude=.git -cf - .) | (cd "$work" && tar -xf -)

    local current stable
    current="$(grep -o 'CHIEF_VERSION="[^"]*"' "$work/VERSION" | cut -d'"' -f2)"
    stable="${start%-dev}"
    # Version text everywhere except badge lines (badges are set by meaning below), so this
    # works whether the repo is in dev form or already holds a release commit.
    sed -i.bak "/img\.shields\.io\/badge\//!s/${current//./\\.}/${start}/g" "$work/VERSION" "$work/README.md" "$work/docs/index.md"
    sed -i.bak \
        -e "s|Download%20Release-v[0-9][0-9.]*\(--dev\)\{0,1\}-|Download%20Release-v9.7.0-|g" \
        -e "s|Stable-v[0-9][0-9.]*\(--dev\)\{0,1\}-|Stable-v9.7.0-|g" \
        -e "s|Dev%20Branch-v[0-9][0-9.]*\(--dev\)\{0,1\}-|Dev%20Branch-${start//-/--}-|g" \
        "$work/README.md"
    sed -i.bak "s|Download-Release%20v[0-9][0-9.]*\(--dev\)\{0,1\}-|Download-Release%20v9.7.0-|g" "$work/docs/index.md"
    rm -f "$work/release-notes/"*-dev.md
    printf '# Chief %s Release Notes\n\n## What'"'"'s New\n\n- test release\n' "$start" > "$work/release-notes/${start}.md"
    find "$work" -name "*.bak" -delete

    git -C "$work" init -q -b main
    git -C "$work" add -A
    git -C "$work" commit -q -m "base"
    git init -q --bare "$TEMP_DIR/remote.git"
    git -C "$work" remote add origin "$TEMP_DIR/remote.git"
    git -C "$work" push -q origin main
    git -C "$work" checkout -q -b dev
    git -C "$work" push -q -u origin dev

    # Config for the scratch Chief
    cp "$PROJECT_ROOT/templates/chief_config_template.sh" "$TEMP_DIR/config.sh"
    sed -i.bak 's/^CHIEF_CFG_DEV_TOOLS=.*/CHIEF_CFG_DEV_TOOLS=true/' "$TEMP_DIR/config.sh"

    # gh stub: state lives in $TEMP_DIR/gh; every call is logged.
    cat > "$TEMP_DIR/bin/gh" <<'STUB'
#!/usr/bin/env bash
S="$GH_STUB_DIR"; echo "gh $*" >> "$S/calls.log"
case "$1 $2" in
  "auth status") exit 0 ;;
  "pr list")   [[ -f "$S/pr_open" ]] && echo "1 https://github.com/test/chief/pull/1"; exit 0 ;;
  "pr create") touch "$S/pr_open"; echo "https://github.com/test/chief/pull/1"; exit 0 ;;
  "pr checks") printf 'test\tpass\t1m\thttps://example.com/run/1\n'; exit 0 ;;
  "pr merge")
    if [[ -f "$S/fail_merge_once" ]]; then rm -f "$S/fail_merge_once"; echo "merge blocked (stub)" >&2; exit 1; fi
    tmp="$S/merge-clone"; rm -rf "$tmp"
    git clone -q "$GH_STUB_REMOTE" "$tmp" && git -C "$tmp" checkout -q main &&
      git -C "$tmp" merge -q --no-ff -m "Merge pull request #1 from test/dev" origin/dev &&
      git -C "$tmp" push -q origin main || exit 1
    rm -f "$S/pr_open"; exit 0 ;;
  "release view") [[ -f "$S/release_$3" ]] && echo "https://github.com/test/chief/releases/tag/$3" && exit 0; exit 1 ;;
  "release create") touch "$S/release_$3"; echo "https://github.com/test/chief/releases/tag/$3"; exit 0 ;;
esac
echo "gh stub: unhandled: $*" >&2; exit 1
STUB
    chmod +x "$TEMP_DIR/bin/gh"
}

# Run a release command in the scratch Chief. Output -> $TEMP_DIR/out.log
run_chief() { # <cmd...>
    local work="$TEMP_DIR/work"
    PATH="$TEMP_DIR/bin:$PATH" GH_STUB_DIR="$TEMP_DIR/gh" GH_STUB_REMOTE="$TEMP_DIR/remote.git" \
    CHIEF_PATH="$work" CHIEF_CONFIG="$TEMP_DIR/config.sh" CHIEF_STEPS_PLAIN=1 \
    CHIEF_RELEASE_REPO="test/chief" CHIEF_RELEASE_CI_INTERVAL=1 CHIEF_RELEASE_TEST_CMD="true" \
    bash -c '
        source "$CHIEF_PATH/VERSION"
        source "$CHIEF_CONFIG"
        source "$CHIEF_PATH/libs/core/chief_library.sh" >/dev/null 2>&1
        __chief_load_dev_tools
        "$@"
    ' _ "$@" </dev/null >"$TEMP_DIR/out.log" 2>&1
}

remote_file() { git -C "$TEMP_DIR/remote.git" show "$1" 2>/dev/null; }
remote_version() { remote_file "$1:VERSION" | grep -o 'CHIEF_VERSION="[^"]*"' | cut -d'"' -f2; }
show_out() { sed 's/^/    | /' "$TEMP_DIR/out.log" | tail -${1:-25}; }

test_steps_helper() {
    log_info "step-progress helper (plain output)"
    CHIEF_PATH="$PROJECT_ROOT" CHIEF_CONFIG=/dev/null CHIEF_STEPS_PLAIN=1 bash -c '
        source "$CHIEF_PATH/VERSION"; source "$CHIEF_PATH/libs/core/chief_library.sh" >/dev/null 2>&1
        __chief_steps_begin "T" "One" "Two" "Three" "Four"
        __chief_steps_start; __chief_steps_done "ok"
        __chief_steps_exec true && __chief_steps_done
        __chief_steps_start; __chief_steps_skip "already"
        __chief_steps_exec false || __chief_steps_fail "nope" "hint line"
        __chief_steps_end "Done" "summary line"
    ' >"$TEMP_DIR/out.log" 2>&1
    check "done step prints ✓ with detail" contains "$TEMP_DIR/out.log" "  ✓ One (ok)"
    check "exec step prints ✓"              contains "$TEMP_DIR/out.log" "  ✓ Two"
    check "skipped step prints ↷"           contains "$TEMP_DIR/out.log" "  ↷ Three (already)"
    check "failed step prints ✗ and hint"   contains "$TEMP_DIR/out.log" "  ✗ Four: nope"
    check "summary printed"                 contains "$TEMP_DIR/out.log" "summary line"
    echo ""
}

# Live (terminal) mode: a step command that writes straight to /dev/tty must not shift the
# redrawn list (it used to duplicate the first line). Runs under a real pseudo-terminal.
test_steps_live_redraw() {
    log_info "step-progress helper (live redraw under a terminal)"
    if ! command -v python3 >/dev/null 2>&1; then
        echo "    python3 not installed; skipping"; echo ""; return 0
    fi
    # Narrow (55 columns), no UTF-8 locale, a prompt to answer, long lines, and a step that
    # writes straight to /dev/tty: the conditions that used to duplicate lines.
    cat > "$TEMP_DIR/live-steps.sh" <<LIVE
export CHIEF_PATH="$PROJECT_ROOT" CHIEF_CONFIG=/dev/null TERM=xterm-256color
unset LANG LC_ALL LC_CTYPE COLUMNS
source "\$CHIEF_PATH/VERSION"; source "\$CHIEF_PATH/libs/core/chief_library.sh" >/dev/null 2>&1
set -m
__chief_steps_begin "Live" "First" "Second" "Commit \"Release v9.8.0\" and push dev" "Open pull request dev → main" "Last"
__chief_steps_start; __chief_steps_done "ok, with a fairly long detail that does not fit"
__chief_steps_exec bash -c 'sleep 0.3; echo stray-tty-write > /dev/tty; sleep 0.3'; __chief_steps_done "ran"
__chief_steps_start
__chief_steps_ask "Commit \"Release v9.8.0\" and push dev to origin?" "    Changes:\n       M README.md\n       M VERSION" && __chief_steps_done "answered"
__chief_steps_start; __chief_steps_done "test/chief#1 with a long repository name"
__chief_steps_start; __chief_steps_done
__chief_steps_end
LIVE
    python3 - "$BASH" "$TEMP_DIR/live-steps.sh" > "$TEMP_DIR/out.log" 2>&1 <<'PY'
import fcntl, os, pty, re, select, struct, sys, termios, time
W = 55
pid, fd = pty.fork()
if pid == 0:
    os.execv(sys.argv[1], [sys.argv[1], "--norc", "-i", sys.argv[2]])
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 24, W, 0, 0))
buf, t0, sent = b"", time.time(), False
while time.time() - t0 < 25:
    r, _, _ = select.select([fd], [], [], 0.2)
    if r:
        try:
            d = os.read(fd, 65536)
        except OSError:
            break
        if not d:
            break
        buf += d
        if not sent and b"[y/N]" in buf:
            time.sleep(0.3); os.write(fd, b"y\n"); sent = True
    elif os.waitpid(pid, os.WNOHANG)[0]:
        break
# Replay on a W-column virtual screen: wrap, newline, CR, cursor-up, clear-to-end.
lines, row, col, wrapped = [], 0, 0, False
def put(ch):
    global row, col, wrapped
    if col >= W:
        row, col, wrapped = row + 1, 0, True
    while len(lines) <= row:
        lines.append("")
    l = lines[row].ljust(col)
    lines[row] = l[:col] + ch + l[col + 1:]
    col += 1
for t in re.split(r"(\x1b\[[0-9;]*[A-Za-z]|\r\n|\r|\n)", buf.decode("utf-8", "replace")):
    if not t:
        continue
    if t in ("\n", "\r\n"):
        row, col = row + 1, 0
    elif t == "\r":
        col = 0
    elif t.startswith("\x1b["):
        m = re.match(r"\x1b\[(\d*)([A-Za-z])", t)
        if m and m.group(2) == "A":
            row = max(0, row - int(m.group(1) or 1))
        elif m and m.group(2) == "J":
            del lines[row + 1:]
            if row < len(lines):
                lines[row] = lines[row][:col]
    else:
        for ch in t:
            put(ch)
print("PROMPT_SEEN" if sent else "PROMPT_NOT_SEEN")
print("A_LINE_WRAPPED" if wrapped else "NO_LINE_WRAPPED")
for l in lines:
    if l.strip():
        print(l)
PY
    check "prompt showed [y/N] and was answered" contains "$TEMP_DIR/out.log" "PROMPT_SEEN"
    check "live list shows every step once"   [ "$(grep -c '✓ First' "$TEMP_DIR/out.log")" -eq 1 ]
    check "answered step completed once"      [ "$(grep -c '✓ Commit' "$TEMP_DIR/out.log")" -eq 1 ]
    check "live list finished all steps"      contains "$TEMP_DIR/out.log" "  ✓ Last"
    check "no line wider than the terminal"   contains "$TEMP_DIR/out.log" "NO_LINE_WRAPPED"
    check "prompt cleared after the answer"   not_contains "$TEMP_DIR/out.log" "[y/N]"
    check "step output kept off the screen"   not_contains "$TEMP_DIR/out.log" "stray-tty-write"
    echo ""
}

test_gate() {
    log_info "dev-tools gate"
    local work="$TEMP_DIR/work" state
    gate() { # <switch> -> prints state and whether chief.release_publish is defined
        CHIEF_PATH="$work" CHIEF_CONFIG=/dev/null CHIEF_CFG_VERBOSE=false bash -c '
            source "$CHIEF_PATH/VERSION"; source "$CHIEF_PATH/libs/core/chief_library.sh" >/dev/null 2>&1
            CHIEF_CFG_DEV_TOOLS='"$1"'; __chief_load_dev_tools
            echo "$(__chief_dev_tools_state) $(type -t chief.release_publish || echo none)"'
    }
    state="$(gate true)";  check "dev + switch on: active and loaded" [ "$state" == "active function" ]
    state="$(gate false)"; check "dev + switch off: not loaded"       [ "$state" == "off none" ]
    git -C "$work" checkout -q main
    state="$(gate true)";  check "main + switch on: never loaded"     [ "$state" == "branch none" ]
    git -C "$work" checkout -q dev
    check "release archives exclude libs/dev" grep -q '^libs/dev export-ignore' "$PROJECT_ROOT/.gitattributes"
    echo ""
}

test_next_validation() {
    log_info "--next validation"
    local before; before="$(git -C "$TEMP_DIR/work" rev-parse HEAD)"
    run_chief chief.release_publish --yes
    check "missing --next fails"                [ $? -ne 0 ]
    check "missing --next lists candidates"     contains "$TEMP_DIR/out.log" "chief.release_publish --next v9.8.1"
    run_chief chief.release_publish --next v9.8.0 --yes
    check "--next equal to the release fails"   [ $? -ne 0 ]
    run_chief chief.release_publish --next 9.9 --yes
    check "--next without v fails"              [ $? -ne 0 ]
    check "nothing committed by failed runs"    [ "$(git -C "$TEMP_DIR/work" rev-parse HEAD)" == "$before" ]
    check "no gh calls by failed runs"          [ ! -s "$TEMP_DIR/gh/calls.log" ]
    echo ""
}

test_dry_run_and_status() {
    log_info "dry run and status change nothing"
    local before; before="$(git -C "$TEMP_DIR/work" rev-parse HEAD) $(git -C "$TEMP_DIR/work" status --porcelain)"
    run_chief chief.release_publish --next v9.8.1 --dry-run
    check "dry run exits 0"                       [ $? -eq 0 ] || show_out
    check "dry run marks steps as would"          contains "$TEMP_DIR/out.log" "○ Would: Merge into main"
    check "dry run says nothing changed"          contains "$TEMP_DIR/out.log" "Nothing was changed"
    run_chief chief.release_status
    check "status exits 0"                        [ $? -eq 0 ] || show_out
    check "status shows pending steps"            contains "$TEMP_DIR/out.log" "· Run the test suite"
    check "status suggests the publish command"   contains "$TEMP_DIR/out.log" "chief.release_publish --next v9.9.0"
    check "working tree unchanged"                [ "$(git -C "$TEMP_DIR/work" rev-parse HEAD) $(git -C "$TEMP_DIR/work" status --porcelain)" == "$before" ]
    check "no release created by dry run/status"  not_contains "$TEMP_DIR/gh/calls.log" "release create"
    echo ""
}

test_publish_with_resume() {
    log_info "publish: fails at merge, then resumes"
    touch "$TEMP_DIR/gh/fail_merge_once"
    run_chief chief.release_publish --next v9.8.1 --yes
    check "first run stops at the merge"          [ $? -ne 0 ]
    check "failed step is shown"                  contains "$TEMP_DIR/out.log" "✗ Merge into main: merge failed"
    check "release commit already on remote dev"  [ "$(remote_version dev)" == "v9.8.0" ]
    check "main not released yet"                 [ "$(remote_version main)" != "v9.8.0" ]

    run_chief chief.release_publish --next v9.8.1 --yes
    check "re-run completes"                      [ $? -eq 0 ] || show_out 40
    check "re-run skips finished steps"           contains "$TEMP_DIR/out.log" "↷ Commit \"Release v9.8.0\" and push dev"
    check "re-run reuses the open pull request"   contains "$TEMP_DIR/out.log" "↷ Open pull request dev → main (#1 already open)"
    check "main is on v9.8.0"                     [ "$(remote_version main)" == "v9.8.0" ]
    check "tag v9.8.0 pushed"                     bash -c "git -C '$TEMP_DIR/remote.git' rev-parse -q --verify refs/tags/v9.8.0 >/dev/null"
    check "GitHub release created"                [ -f "$TEMP_DIR/gh/release_v9.8.0" ]
    check "release notes renamed on main"         bash -c "git -C '$TEMP_DIR/remote.git' cat-file -e main:release-notes/v9.8.0.md"
    check "dev is on v9.8.1-dev"                  [ "$(remote_version dev)" == "v9.8.1-dev" ]
    check "next release notes created on dev"     bash -c "git -C '$TEMP_DIR/remote.git' cat-file -e dev:release-notes/v9.8.1-dev.md"
    check "dev badge shows next dev version"      bash -c "git -C '$TEMP_DIR/remote.git' show dev:README.md | grep -qF 'Dev%20Branch-v9.8.1--dev'"
    check "stable badge shows the release"        bash -c "git -C '$TEMP_DIR/remote.git' show dev:README.md | grep -qF 'Download%20Release-v9.8.0-'"
    check "summary lists the release"             contains "$TEMP_DIR/out.log" "Released Chief v9.8.0"
    check "config not touched without --track"   not_contains "$TEMP_DIR/config.sh" 'CHIEF_CFG_UPDATE_BRANCH="dev"'
    echo ""
}

test_rerun_after_success() {
    log_info "re-run after success is a no-op"
    local before; before="$(git -C "$TEMP_DIR/remote.git" rev-parse dev main)"
    run_chief chief.release_publish --yes
    check "re-run without --next exits 0"         [ $? -eq 0 ] || show_out
    check "only the checks ran; every other step skipped" [ "$(grep -c '  ✓ ' "$TEMP_DIR/out.log")" -eq 1 ] && contains "$TEMP_DIR/out.log" "  ✓ Checks"
    check "remote unchanged"                      [ "$(git -C "$TEMP_DIR/remote.git" rev-parse dev main)" == "$before" ]
    run_chief chief.release_status
    check "status reports the cycle complete"     contains "$TEMP_DIR/out.log" "Release v9.8.0 is complete; dev is on v9.8.1-dev."
    echo ""
}

test_retarget_hint() {
    log_info "retarget hint: switch the cycle from v9.8.1 to v9.9.0, then release it"
    local work="$TEMP_DIR/work"
    # Some work on the cycle, including release notes we must not lose
    echo "- retarget marker note" >> "$work/release-notes/v9.8.1-dev.md"
    git -C "$work" commit -qam "work in progress" && git -C "$work" push -q origin dev

    run_chief chief.release_status
    check "status shows the retarget hint"        contains "$TEMP_DIR/out.log" "Change the version this cycle releases (e.g. v9.8.1 → v9.9.0)"
    # Run the hint's commands exactly as printed
    sed -n '/Change the version this cycle releases/,$p' "$TEMP_DIR/out.log" | sed -n 's/^    //p' > "$TEMP_DIR/retarget.sh"
    check "hint has the four commands"            [ "$(wc -l < "$TEMP_DIR/retarget.sh" | tr -d ' ')" -eq 4 ]
    (set -e; source "$TEMP_DIR/retarget.sh") >/dev/null 2>&1
    check "hint commands ran cleanly"             [ $? -eq 0 ]
    check "dev is now v9.9.0-dev"                 [ "$(remote_version dev)" == "v9.9.0-dev" ]
    check "notes renamed with content kept"       bash -c "git -C '$TEMP_DIR/remote.git' show dev:release-notes/v9.9.0-dev.md | grep -qF 'retarget marker note'"
    check "dev badge retargeted"                  bash -c "git -C '$TEMP_DIR/remote.git' show dev:README.md | grep -qF 'Dev%20Branch-v9.9.0--dev'"
    check "stable badge untouched"                bash -c "git -C '$TEMP_DIR/remote.git' show dev:README.md | grep -qF 'Download%20Release-v9.8.0-'"

    run_chief chief.release_publish --next v9.9.1 --yes
    check "publish after retarget completes"      [ $? -eq 0 ] || show_out 30
    check "main released as v9.9.0"               [ "$(remote_version main)" == "v9.9.0" ]
    check "release notes kept the cycle's notes"  bash -c "git -C '$TEMP_DIR/remote.git' show main:release-notes/v9.9.0.md | grep -qF 'retarget marker note'"
    check "GitHub release v9.9.0 created"         [ -f "$TEMP_DIR/gh/release_v9.9.0" ]
    check "dev moved on to v9.9.1-dev"            [ "$(remote_version dev)" == "v9.9.1-dev" ]
    echo ""
}

main() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}        RELEASE TOOLING TESTS${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    if ! command -v git >/dev/null 2>&1; then
        echo "git not installed; skipping"; return 0
    fi
    setup
    test_steps_helper
    test_steps_live_redraw
    test_gate
    test_next_validation
    test_dry_run_and_status
    test_publish_with_resume
    test_rerun_after_success
    test_retarget_hint

    echo -e "${CYAN}========================================${NC}"
    echo -e "${BLUE}Total Tests:${NC} $TOTAL_TESTS"
    echo -e "${GREEN}Passed:${NC} $PASSED_TESTS"
    [[ $FAILED_TESTS -gt 0 ]] && echo -e "${RED}Failed:${NC} $FAILED_TESTS"
    echo ""
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${GREEN}🎉 ALL RELEASE TOOLING TESTS PASSED!${NC}"; return 0
    else
        echo -e "${RED}❌ $FAILED_TESTS RELEASE TOOLING TEST(S) FAILED${NC}"; return 1
    fi
}

case "${1:-}" in
    -h|--help) echo "Usage: $0   Runs the dev-only release tooling end to end on a scratch copy."; exit 0 ;;
esac
main

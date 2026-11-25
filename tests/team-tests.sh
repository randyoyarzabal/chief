#!/usr/bin/env bash
# Copyright (C) 2025 Randy E. Oyarzabal <github@randyoyarzabal.com>
########################################################################
# Chief Test Suite - team mode and onboarding
#
# A shared plugins repo (a local bare git repo standing in for a git server,
# with the plugins folder deep inside it) holding team and personal settings,
# profiles and secrets. Covers: layered settings, profiles running before
# plugins and once, chief.on_startup, chief.host_is, CHIEF_CFG_USER checks,
# layered secrets, chief.plugins-repo and install.sh --repo.
# Everything runs in a scratch HOME; nothing touches the user's setup.
########################################################################

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASSED=0
FAILED=0
SKIPPED=0
pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; FAILED=$((FAILED + 1)); }
skip() { echo -e "${YELLOW}[SKIP]${NC} $1"; SKIPPED=$((SKIPPED + 1)); }
check() { if [[ "$2" == 0 ]]; then pass "$1"; else fail "$1${3:+ (got: $3)}"; fi; }

WORK="$(mktemp -d)"
export GNUPGHOME="$WORK/gnupg"
mkdir -p "$GNUPGHOME" && chmod 700 "$GNUPGHOME"
cleanup() {
  command -v gpgconf >/dev/null 2>&1 && gpgconf --kill gpg-agent >/dev/null 2>&1
  rm -rf "$WORK"
}
trap cleanup EXIT

echo -e "${BLUE}[INFO]${NC} Team mode tests (bash ${BASH_VERSION})"

GIT=(git -c user.name=Test -c user.email=test@example.com -c init.defaultBranch=main)
FOLDER="path/to/plugins"

# --- The shared repo ---------------------------------------------------
BARE="$WORK/common.git"
"${GIT[@]}" init -q --bare "$BARE"
SEED="$WORK/seed"
"${GIT[@]}" clone -q "$BARE" "$SEED" 2>/dev/null
mkdir -p "$SEED/$FOLDER/users/alice"
D="$SEED/$FOLDER"
cat > "$D/.chief_shared-config.sh" <<'EOF'
CHIEF_CFG_HINTS=true
CHIEF_CFG_BANNER=false
CHIEF_CFG_PLUGINS_PATH=/somewhere/else
EOF
printf 'CHIEF_CFG_BANNER=true\nCHIEF_CFG_BANNER_INDICATORS=""\n' > "$D/users/alice/config.sh"
cat > "$D/.chief_shared-profile.sh" <<'EOF'
export TEAM_VAR=team
if chief.host_is '*'; then export HOST_VAR=matched; fi
PROFILE_RUNS=$(( ${PROFILE_RUNS:-0} + 1 ))
EOF
cat > "$D/users/alice/profile.sh" <<'EOF'
export TEAM_VAR=personal
chief.on_startup 'STARTUP_ORDER="${STARTUP_ORDER:-}on_startup;"'
EOF
printf 'SEEN_AT_LOAD="$TEAM_VAR/${HOST_VAR:-}"\nSTARTUP_ORDER="${STARTUP_ORDER:-}plugin;"\n' > "$D/probe_chief-plugin.sh"
( cd "$SEED" && "${GIT[@]}" add -A && "${GIT[@]}" commit -qm seed && "${GIT[@]}" push -q origin main ) >/dev/null 2>&1

# A host already pointed at the repo (as chief.plugins-repo / install.sh --repo would leave it).
HOMEA="$WORK/home-a"
mkdir -p "$HOMEA"
"${GIT[@]}" clone -q "$BARE" "$HOMEA/chief_plugins" 2>/dev/null
write_cfg() { # <home> [user]
  cat > "$1/.chief_config.sh" <<EOF
CHIEF_CFG_BANNER=false
CHIEF_CFG_HINTS=false
CHIEF_CFG_SSH_LOAD_KEYS=false
CHIEF_CFG_AUTOCHECK_UPDATES=false
CHIEF_CFG_PLUGINS_TYPE="remote"
CHIEF_CFG_PLUGINS_GIT_REPO="$BARE"
CHIEF_CFG_PLUGINS_GIT_BRANCH="main"
CHIEF_CFG_PLUGINS_GIT_PATH="$FOLDER"
CHIEF_CFG_PLUGINS_PATH="$1/chief_plugins"
CHIEF_CFG_PLUGINS_GIT_AUTOUPDATE=false
CHIEF_CFG_USER="${2-alice}"
EOF
}
write_cfg "$HOMEA"

# Start Chief on a host. Usage: start <home> <-c|-ic> <code after start-up> [env...]
start() {
  local home="$1" mode="$2" code="$3"; shift 3
  env -i PATH="$PATH" TERM=dumb NO_COLOR=1 HOME="$home" USER=alice GNUPGHOME="$GNUPGHOME" \
    CHIEF_PATH="$PROJECT_ROOT" CHIEF_CONFIG="$home/.chief_config.sh" "$@" \
    "$BASH" --norc --noprofile "$mode" 'source "$CHIEF_PATH/chief.sh" >/dev/null 2>"$HOME/startup.err"; '"$code" </dev/null 2>&1
}

# --- Layered settings and profiles --------------------------------------
out="$(start "$HOMEA" -c 'echo "banner=$CHIEF_CFG_BANNER hints=$CHIEF_CFG_HINTS path=$CHIEF_CFG_PLUGINS_PATH layers=[$CHIEF_CONFIG_LAYERS]"')"
check "Settings: host < team < personal (personal banner wins, team hints apply)" \
  "$( [[ "$out" == *"banner=true hints=true"* && "$out" == *"layers=[local team personal]"* ]]; echo $?)" "$out"
check "Settings: the repo can't redirect where it is (PLUGINS_PATH stays local)" \
  "$( [[ "$out" == *"path=$HOMEA/chief_plugins "* ]]; echo $?)" "$out"

out="$(start "$HOMEA" -c 'echo "seen=$SEEN_AT_LOAD runs=$PROFILE_RUNS order=$STARTUP_ORDER profile=[$CHIEF_PROFILE_LAYERS]"; __chief_load_library >/dev/null 2>&1; echo "after-reload runs=$PROFILE_RUNS"')"
check "Profile: team then personal run before plugins load (plugin saw personal/matched)" \
  "$( [[ "$out" == *"seen=personal/matched"* && "$out" == *"profile=[team personal]"* ]]; echo $?)" "$out"
check "Profile: chief.on_startup runs after plugins, at the end of start-up" \
  "$( [[ "$out" == *"order=plugin;on_startup;"* ]]; echo $?)" "$out"
check "Profile: runs once; chief.reload doesn't re-run it" \
  "$( [[ "$out" == *"runs=1 "* && "$out" == *"after-reload runs=1"* ]]; echo $?)" "$out"

out="$(start "$HOMEA" -c 'chief.on_startup "echo ran-now"')"
check "chief.on_startup after start-up runs the command right away" "$( [[ "$out" == *"ran-now"* ]]; echo $?)" "$out"

# --- chief.host_is -------------------------------------------------------
out="$(start "$HOMEA" -c '
  chief.host_is my-laptop && echo A
  chief.host_is "my-*" && echo B
  chief.host_is "alice@my-laptop" && echo C
  chief.host_is "deploy@*" || echo D
  chief.host_is other "*-laptop" && echo E
  chief.host_is other || echo F
  if ! chief.host_is other "deploy@*"; then echo G; fi
  if ! chief.host_is other my-laptop; then echo X; fi' CHIEF_HOST=my-laptop)"
check "chief.host_is: name, wildcard, user@host, several patterns, no match, ! negation" \
  "$( [[ "$(tr -d '\n' <<<"$out")" == "ABCDEFG" ]]; echo $?)" "$out"

# --- CHIEF_CFG_USER is required in a team repo (one with users/) -------
HOMEB="$WORK/home-b"; mkdir -p "$HOMEB"
"${GIT[@]}" clone -q "$BARE" "$HOMEB/chief_plugins" 2>/dev/null
write_cfg "$HOMEB" ""
start "$HOMEB" -ic 'echo "layers=[$CHIEF_CONFIG_LAYERS] profile=[$CHIEF_PROFILE_LAYERS]" > "$HOME/out"' >/dev/null
out="$(cat "$HOMEB/out" "$HOMEB/startup.err" 2>/dev/null)"
check "User unset: team layers still load, personal ones don't, and a warning says how to fix it" \
  "$( [[ "$out" == *"layers=[local team]"* && "$out" == *"profile=[team]"* && "$out" == *"CHIEF_CFG_USER isn't set"*"chief.config-set user"* ]]; echo $?)" "$out"
write_cfg "$HOMEB" "nobody"
start "$HOMEB" -ic 'true' >/dev/null
out="$(cat "$HOMEB/startup.err" 2>/dev/null)"
check "User with no folder in the repo: a note suggests a typo or creating one" \
  "$( [[ "$out" == *"No personal folder for 'nobody'"* ]]; echo $?)" "$out"
out="$(start "$HOMEA" -c 'chief.status')"
check "chief.status: shows the user and the layers in use" \
  "$( [[ "$out" == *"User: alice · settings: local team personal · profile: team personal"* ]]; echo $?)" "$out"

# --- chief.config-set notes a setting the shared layers override --------
out="$(start "$HOMEA" -c 'chief.config-set -y hints false')"
check "config-set: says when the team settings also set it (and take precedence)" \
  "$( [[ "$out" == *"also set in the shared repo's team settings"* ]]; echo $?)" "$out"

# --- Layered secrets ---------------------------------------------------
if command -v gpg >/dev/null 2>&1; then
  printf 'teampass\n' > "$WORK/team.pass"; printf 'mypass\n' > "$WORK/my.pass"
  enc() { printf '%s\n' "$2" | gpg --batch --yes --armor --passphrase-file "$3" --symmetric --cipher-algo AES256 -o "$1" 2>/dev/null; }
  HA="$HOMEA/chief_plugins/$FOLDER"
  enc "$HA/.chief_shared-secrets" 'export S_TEAM=1; export S_WHO=team' "$WORK/team.pass"
  enc "$HA/users/alice/secrets" 'export S_MINE=1; export S_WHO=personal' "$WORK/my.pass"
  enc "$HOMEA/.chief_user-secrets" 'export S_HOST=1' "$WORK/my.pass"
  # Saved passwords (file store) so loading doesn't prompt; the team file gets the wrong one first.
  save() { start "$HOMEA" -c "__chief_secrets_store_put '$1' file <<<'$2'" CHIEF_SECRETS_NO_KEYCHAIN=1 CHIEF_SECRETS_STORE_DIR="$WORK/store" >/dev/null; }
  save "$HA/users/alice/secrets" mypass; save "$HOMEA/.chief_user-secrets" mypass; save "$HA/.chief_shared-secrets" wrongpass
  out="$(start "$HOMEA" -c 'chief.secrets_file-load --quiet; echo "rc=$? team=${S_TEAM:-} mine=${S_MINE:-} host=${S_HOST:-}"' CHIEF_SECRETS_NO_KEYCHAIN=1 CHIEF_SECRETS_STORE_DIR="$WORK/store")"
  check "Secrets: a failing team file doesn't stop personal and host secrets (rc=1, says which)" \
    "$( [[ "$out" == *"rc=1 team= mine=1 host=1"* && "$out" == *"Skipped the team secrets"* ]]; echo $?)" "$out"
  save "$HA/.chief_shared-secrets" teampass
  out="$(start "$HOMEA" -c 'chief.secrets_file-load --quiet; echo "rc=$? team=$S_TEAM mine=$S_MINE host=$S_HOST who=$S_WHO"; __chief_banner_secrets' CHIEF_SECRETS_NO_KEYCHAIN=1 CHIEF_SECRETS_STORE_DIR="$WORK/store")"
  check "Secrets: no file name loads team AND personal AND host; personal overrides team" \
    "$( [[ "$out" == *"rc=0 team=1 mine=1 host=1 who=personal"* && "$out" == *"secrets: loaded (3)"* ]]; echo $?)" "$out"
  out="$(start "$HOMEA" -c 'chief.secrets_file-load --personal --quiet; echo "team=${S_TEAM:-} mine=${S_MINE:-}"' CHIEF_SECRETS_NO_KEYCHAIN=1 CHIEF_SECRETS_STORE_DIR="$WORK/store")"
  check "Secrets: --personal loads just yours" "$( [[ "$out" == *"team= mine=1"* ]]; echo $?)" "$out"
  out="$(start "$HOMEA" -c 'chief.secrets_file-edit')"
  check "Secrets: with several files and no terminal, edit asks for --team/--personal/--local" \
    "$( [[ "$out" == *"Pass --team, --personal, --local or a path"* ]]; echo $?)" "$out"

  # Creating personal secrets on a host for a new user: lands in users/<user>/secrets, encrypted,
  # with no plaintext left in the repo folder.
  printf '#!/bin/sh\nprintf "export NEW_ONE=1\\n" > "$1"\n' > "$WORK/fake-editor.sh"; chmod +x "$WORK/fake-editor.sh"
  write_cfg "$HOMEA" "newbie"
  out="$(start "$HOMEA" -c 'chief.secrets_file-edit --personal' EDITOR="$WORK/fake-editor.sh" CHIEF_SECRETS_PASSWORD_FILE="$WORK/my.pass")"
  nf="$HA/users/newbie/secrets"
  check "Secrets: --personal creates users/<user>/secrets, encrypted, with a password reminder" \
    "$( [[ -f "$nf" ]] && head -1 "$nf" | grep -q 'BEGIN PGP' && [[ "$out" == *"long, unique password"* ]]; echo $?)" "$out"
  check "Secrets: no plaintext copy is left in the repo folder" \
    "$( ! grep -rq 'NEW_ONE' "$HA/users/newbie" 2>/dev/null; echo $?)"
  write_cfg "$HOMEA"
else
  skip "Layered secrets tests (gpg not installed)"
fi

# --- Editing shared files: closing the editor without changes --------------
# (No terminal here, so a commit offer would only show its question; it must not appear at all.)
printf '#!/bin/sh\nprintf "export ADDED=1\\n" >> "$1"\n' > "$WORK/append-editor.sh"; chmod +x "$WORK/append-editor.sh"
HAP="$HOMEA/chief_plugins/$FOLDER"
write_cfg "$HOMEA" "bob"
out="$(start "$HOMEA" -c 'chief.shared-profile --personal' EDITOR=true)"
check "shared-profile: an untouched new personal profile isn't kept (no users/bob, no commit offer)" \
  "$( [[ ! -e "$HAP/users/bob" && "$out" == *"wasn't kept"* && "$out" != *"Not pushed"* ]]; echo $?)" "$out"
out="$(start "$HOMEA" -c 'chief.shared-config --personal' EDITOR=true)"
check "shared-config: same for an untouched new personal settings file" \
  "$( [[ ! -e "$HAP/users/bob" && "$out" == *"wasn't kept"* && "$out" != *"Not pushed"* ]]; echo $?)" "$out"
out="$(start "$HOMEA" -c 'chief.shared-profile --personal' EDITOR="$WORK/append-editor.sh")"
check "shared-profile: an edited new profile is kept and offered for commit (declined: no terminal)" \
  "$( grep -q 'ADDED=1' "$HAP/users/bob/profile.sh" && [[ "$out" == *"Not pushed"* ]]; echo $?)" "$out"
rm -rf "$HAP/users/bob"
write_cfg "$HOMEA"
sum="$(cksum < "$HAP/.chief_shared-profile.sh")"
out="$(start "$HOMEA" -c 'chief.shared-profile' EDITOR=true)"
check "shared-profile: closing an existing profile without changes doesn't offer a commit" \
  "$( [[ "$(cksum < "$HAP/.chief_shared-profile.sh")" == "$sum" && "$out" != *"Not pushed"* ]]; echo $?)" "$out"
printf '# local tweak\n' >> "$HAP/.chief_shared-profile.sh"
out="$(start "$HOMEA" -c 'chief.shared-profile' EDITOR=true)"
check "shared-profile: earlier unpushed changes get a how-to-share note, not a question" \
  "$( [[ "$out" == *"earlier changes that aren't pushed"* && "$out" != *"Not pushed"* ]]; echo $?)" "$out"
git -C "$HOMEA/chief_plugins" checkout -q -- "$FOLDER/.chief_shared-profile.sh"
if command -v gpg >/dev/null 2>&1; then
  sum="$(cksum < "$HAP/users/alice/secrets")"
  out="$(start "$HOMEA" -c 'chief.secrets_file-edit --personal' EDITOR=true CHIEF_SECRETS_PASSWORD_FILE="$WORK/my.pass")"
  check "Secrets: closing the editor without changes leaves the file as it was (no re-encrypt, no commit offer)" \
    "$( [[ "$(cksum < "$HAP/users/alice/secrets")" == "$sum" && "$out" == *"No changes"* && "$out" != *"Not pushed"* ]]; echo $?)" "$out"
fi

# --personal in a repo without users/ warns that it would make it a team repo (and keeps nothing).
mv "$HAP/users" "$WORK/users.aside"
write_cfg "$HOMEA" "bob"
out="$(start "$HOMEA" -c 'chief.shared-profile --personal' EDITOR=true)"
check "shared-profile --personal: the repo's first users/ gets a team-repo note, and nothing is kept" \
  "$( [[ "$out" == *"makes it a team repo"* && ! -e "$HAP/users" ]]; echo $?)" "$out"
mv "$WORK/users.aside" "$HAP/users"
write_cfg "$HOMEA"

# --- chief.plugins-repo (a host that already has Chief) ------------------
HOMEC="$WORK/home-c"; mkdir -p "$HOMEC"
printf 'CHIEF_CFG_BANNER=false\nCHIEF_CFG_HINTS=false\nCHIEF_CFG_PLUGINS_TYPE="local"\nCHIEF_CFG_PLUGINS_PATH=""\n#CHIEF_CFG_USER=""\n' > "$HOMEC/.chief_config.sh"
out="$(start "$HOMEC" -c "chief.plugins-repo '$BARE' --path $FOLDER")"
cfg="$(cat "$HOMEC/.chief_config.sh")"
check "plugins-repo: without --user (no terminal) it still sets up, and warns that this is a team repo" \
  "$( [[ -d "$HOMEC/chief_plugins/.git" && "$out" == *"This is a team repo"*"chief.config-set user"* ]] && ! grep -q '^CHIEF_CFG_USER="[^"]' <<<"$cfg"; echo $?)" "$out"
out="$(start "$HOMEC" -c "chief.plugins-repo '$BARE' --path $FOLDER/ --user alice; echo \"layers=[\$CHIEF_CONFIG_LAYERS]\"")"
cfg="$(cat "$HOMEC/.chief_config.sh")"
check "plugins-repo: clones the repo and points the config at the deep folder, as the user" \
  "$( [[ -d "$HOMEC/chief_plugins/.git" && "$cfg" == *"CHIEF_CFG_PLUGINS_TYPE=\"remote\""* && "$cfg" == *"CHIEF_CFG_PLUGINS_GIT_PATH=\"$FOLDER\""* && "$cfg" == *"CHIEF_CFG_USER=\"alice\""* && "$cfg" == *"CHIEF_CFG_PLUGINS_GIT_REPO=\"$BARE\""* ]]; echo $?)" "$cfg"
check "plugins-repo: reports what the repo holds and applies the shared settings right away" \
  "$( [[ "$out" == *"Found: team settings, team profile"*"your settings, your profile"* && "$out" == *"layers=[local team personal]"* ]]; echo $?)" "$out"
out="$(start "$HOMEC" -c "chief.plugins-repo '$WORK/other.git' --user alice")"
check "plugins-repo: refuses to reuse a folder that's a clone of another repo" \
  "$( [[ "$out" == *"already a clone of"* ]]; echo $?)" "$out"

# --- A repo only you use (no users/ folder): never asks for a user -------
PBARE="$WORK/personal.git"
"${GIT[@]}" init -q --bare "$PBARE"
PSEED="$WORK/pseed"; "${GIT[@]}" clone -q "$PBARE" "$PSEED" 2>/dev/null
mkdir -p "$PSEED/$FOLDER"
printf 'export MINE=1\n' > "$PSEED/$FOLDER/.chief_shared-profile.sh"
( cd "$PSEED" && "${GIT[@]}" add -A && "${GIT[@]}" commit -qm seed && "${GIT[@]}" push -q origin main ) >/dev/null 2>&1
HOMEP="$WORK/home-p"; mkdir -p "$HOMEP"
"${GIT[@]}" clone -q "$PBARE" "$HOMEP/chief_plugins" 2>/dev/null
write_cfg "$HOMEP" ""
sed -i.bak "s|$BARE|$PBARE|" "$HOMEP/.chief_config.sh"
start "$HOMEP" -ic 'echo "mine=${MINE:-} team=$(__chief_team_mode && echo yes || echo no)" > "$HOME/out"; chief.status >> "$HOME/out"' >/dev/null
out="$(cat "$HOMEP/out" "$HOMEP/startup.err" 2>/dev/null)"
check "Personal repo (no users/): its profile runs, no user warning, status has no User line" \
  "$( [[ "$out" == *"mine=1 team=no"* && "$out" != *"CHIEF_CFG_USER"* && "$out" != *"User:"* ]]; echo $?)" "$out"

# --- install.sh --repo (a brand-new host) --------------------------------
HOMED0="$WORK/home-d0"; mkdir -p "$HOMED0"; touch "$HOMED0/.bash_profile"
out="$(env -i PATH="$PATH" HOME="$HOMED0" USER=alice TERM=dumb "$BASH" "$PROJECT_ROOT/tools/install.sh" --local --path "$HOMED0/.chief" --config "$HOMED0/.chief_config.sh" --repo "$BARE" --repo-path "$FOLDER" </dev/null 2>&1)"
cfg="$(cat "$HOMED0/.chief_config.sh" 2>/dev/null)"
check "install.sh --repo without --user (no terminal): installs, and warns that this is a team repo" \
  "$( [[ -d "$HOMED0/.chief" && -d "$HOMED0/chief_plugins/.git" && "$out" == *"This is a team repo"* ]] && ! grep -q '^CHIEF_CFG_USER="[^"]' <<<"$cfg"; echo $?)" "$(grep -iE 'team repo|error' <<<"$out")"
HOMED="$WORK/home-d"; mkdir -p "$HOMED"; touch "$HOMED/.bash_profile"
out="$(env -i PATH="$PATH" HOME="$HOMED" USER=alice TERM=dumb "$BASH" "$PROJECT_ROOT/tools/install.sh" --local --path "$HOMED/.chief" --config "$HOMED/.chief_config.sh" --repo "$BARE" --repo-path "$FOLDER" --user alice </dev/null 2>&1)"
cfg="$(cat "$HOMED/.chief_config.sh" 2>/dev/null)"
check "install.sh --repo: installs Chief, clones the repo and writes the repo settings and user" \
  "$( [[ -d "$HOMED/.chief" && -d "$HOMED/chief_plugins/.git" && "$cfg" == *"CHIEF_CFG_PLUGINS_GIT_PATH=\"$FOLDER\""* && "$cfg" == *"CHIEF_CFG_USER=\"alice\""* && "$cfg" == *"CHIEF_CFG_PLUGINS_TYPE=\"remote\""* ]]; echo $?)" "$(tail -5 <<<"$out")"
check "install.sh --repo: says what it found in the repo" \
  "$( [[ "$out" == *"Found team settings, team profile"* ]]; echo $?)" "$(grep -i found <<<"$out")"
out="$(env -i PATH="$PATH" TERM=dumb NO_COLOR=1 HOME="$HOMED" USER=alice CHIEF_PATH="$HOMED/.chief" CHIEF_CONFIG="$HOMED/.chief_config.sh" "$BASH" --norc --noprofile -c 'source "$CHIEF_PATH/chief.sh" >/dev/null 2>&1; echo "seen=$SEEN_AT_LOAD layers=[$CHIEF_CONFIG_LAYERS]"' </dev/null 2>&1)"
check "install.sh --repo: the new host's first shell gets the shared settings, profile and plugins" \
  "$( [[ "$out" == *"seen=personal/matched layers=[local team personal]"* ]]; echo $?)" "$out"

echo ""
echo "Team mode tests: ${PASSED} passed, ${FAILED} failed, ${SKIPPED} skipped"
[[ $FAILED -eq 0 ]]

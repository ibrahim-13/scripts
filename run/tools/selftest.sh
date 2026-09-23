#!/usr/bin/env bash
# selftest.sh — smoke tests. Run with `run selftest`; exit 0 = everything passed.
# Installs nothing: DRY_RUN=1 throughout, sudo/ssh are never reached (ssh is faked).
# Real-tree checks: syntax, every command listed/indexed, header lint, every command bundles and parses.
# Behaviour checks: a relocated COPY of the tree with throw-away fixture commands under cmd/t/, so the
# tests do not depend on which real commands exist.
set -u
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/loader.sh"
RUN=$RUN_ROOT/bin/run
export DRY_RUN=1; unset RUN_FORCE RUN_ROLE RUN_YES RUN_CONFIRMED
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0 fail=0
ok()  { ((pass++)); printf '  \e[32mok\e[0m   %s\n' "$1"; }
bad() { ((fail++)); printf '  \e[31mFAIL\e[0m %s\n       %s\n' "$1" "${2:-}"; }
skip(){ printf '  \e[33mskip\e[0m %s (%s)\n' "$1" "$2"; }
strip(){ sed 's/\x1b\[[0-9;]*m//g'; }
# Commands get stdin from /dev/null: Fedora's bash sources ~/.bashrc for `bash -c` when stdin is a
# socket and SHLVL<2, which `env -i` makes possible; that would pollute the output.
expect(){ local d=$1 g=$2; shift 2; local out; out=$("$@" 2>&1 </dev/null | strip); [[ $out == $g ]] && ok "$d" || bad "$d" "got: ${out:0:300}"; }
expect_rc(){ local d=$1 rc=$2; shift 2; "$@" >/dev/null 2>&1 </dev/null; local got=$?; [[ $got == "$rc" ]] && ok "$d" || bad "$d" "exit $got, wanted $rc"; }
# pty_run KEYS CMD -> run CMD with a pseudo-terminal, feeding KEYS (printf format) as typed input.
pty_run() {
  local keys=$1 cmd=$2
  if command -v script >/dev/null; then
    { sleep 0.3; printf "$keys"; sleep 0.4; } | script -qefc "$cmd" /dev/null >/dev/null 2>&1
  else
    python3 - "$cmd" "$(printf "$keys")" <<'PY' >/dev/null 2>&1
import os, pty, sys, time, select
cmd, keys = sys.argv[1], sys.argv[2].encode()
pid, fd = pty.fork()
if pid == 0:
    os.execvp("bash", ["bash", "-c", cmd])
def drain(t):
    end = time.time() + t
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.05)
        if r:
            try: os.read(fd, 65536)
            except OSError: return
drain(0.3)
os.write(fd, keys)                # one write, like a terminal does (keeps escape sequences intact)
drain(0.6); os.waitpid(pid, 0)
PY
  fi
}
HAVE_PTY=; { command -v script >/dev/null || command -v python3 >/dev/null; } && HAVE_PTY=1

echo "syntax"
for f in "$RUN" "$RUN_ROOT"/lib/*.sh "$RUN_ROOT"/tools/*.sh "$RUN_ROOT"/completions/run.bash "$RUN_ROOT"/cmd/*/*.sh; do
  bash -n "$f" 2>"$TMP/err" && ok "bash -n ${f#"$RUN_ROOT/"}" || bad "bash -n ${f#"$RUN_ROOT/"}" "$(<"$TMP/err")"
done
for f in "$RUN_ROOT"/cmd/*/*.sh; do [[ -x $f ]] && ok "executable ${f#"$RUN_ROOT/"}" || bad "executable ${f#"$RUN_ROOT/"}" "chmod +x"; done

echo "real tree"
expect "run root is this tree"            "$RUN_ROOT"  "$RUN" root
expect "run help (no args) prints usage"  "usage: run*" "$RUN" help
expect "run --help prints usage"          "usage: run*" "$RUN" --help
expect_rc "unknown command exits 1"       1            "$RUN" no/such
expect "unknown command says so"          "*unknown command*" "$RUN" no/such
expect "search finds a library function"  "*fn*pkg_install*install packages*" "$RUN" search pkg_install
LIST=$("$RUN" list 2>&1 </dev/null | strip)
IDX=$("$RUN_ROOT/tools/index.sh" --rebuild)
expect "index rows have 6 columns"        "" awk -F'\t' 'NF!=6' "$IDX"
expect "per-distro fn__ hidden from index" "" grep -P '^fn\t[^\t]*__' "$IDX"
expect "private _fn hidden from index"    "" grep -P '^fn\t_' "$IDX"
NCMD=0
for f in "$RUN_ROOT"/cmd/*/*.sh; do
  id=${f#"$RUN_ROOT/cmd/"}; id=${id%.sh}; ((NCMD++))
  [[ $LIST == *"$id "* ]] && ok "listed: $id" || bad "listed: $id"
  [[ -n $(_run_header_field "$f" summary) ]] && ok "has @summary: $id" || bad "has @summary: $id"
  for lib in $(_run_header_field "$f" needs); do [[ -f $RUN_ROOT/lib/$lib.sh ]] && ok "$id: @needs $lib exists" || bad "$id: @needs $lib exists"; done
  declared=" $(_run_header_field "$f" steps | tr '\n' ' ') "
  while read -r s; do [[ $declared == *" $s "* ]] && ok "$id: run_cmd $s is in @steps" || bad "$id: run_cmd $s missing from @steps"
  done < <(grep -oE '^[^#]*\brun_cmd[[:space:]]+[A-Za-z0-9_./-]+' "$f" | sed -E 's/.*run_cmd[[:space:]]+//')
  for s in $declared; do [[ -f $RUN_ROOT/cmd/$s.sh ]] && ok "$id: @steps $s exists" || bad "$id: @steps $s has no file"; done
  if "$RUN" bundle "$id" >"$TMP/b.sh" 2>"$TMP/err" && bash -n "$TMP/b.sh" 2>>"$TMP/err"; then ok "bundle parses: $id"; else bad "bundle parses: $id" "$(<"$TMP/err")"; fi
done
comp() { bash -c "source '$1' 2>/dev/null; COMP_WORDS=($2); COMP_CWORD=\$(( \${#COMP_WORDS[@]} - 1 )); COMPREPLY=(); _run 2>/dev/null; printf '%s\n' \"\${COMPREPLY[@]}\""; }
expect "completion root comes from the file, not PATH" "$RUN_ROOT" env -i PATH=/usr/bin:/bin bash -c "source '$RUN_ROOT/completions/run.bash' 2>/dev/null; _run_root"
expect "completion of an empty word offers every command" "$NCMD" bash -c "$(declare -f comp); comp '$RUN_ROOT/completions/run.bash' 'run \"\"' | wc -l"

echo "libraries"
L=$RUN_LIB/loader.sh
expect "use resolves @needs chain (pkg -> os -> core)" "3" bash -c "source '$L'; use pkg; declare -F pkg_install os_dispatch die | wc -l"
expect "use is idempotent"                "1" bash -c "source '$L'; use core; use core core; echo \$__RUN_LIB_core"
expect_rc "use of unknown lib fails"       1  bash -c "source '$L'; use nope"
expect "os_dispatch picks the family"     "[[]sudo[]] apt-get install curl" bash -c "source '$L'; use pkg; sudo(){ echo \"[sudo] \$*\"; }; OS_ID=ubuntu OS_LIKE=debian OS_FAMILY=apt OS_ROLE=vm; unset DRY_RUN; pkg_install curl"
expect "RUN_YES adds the manager's yes flag" "[[]sudo[]] apt-get install -y curl" bash -c "source '$L'; use pkg; sudo(){ echo \"[sudo] \$*\"; }; OS_ID=ubuntu OS_FAMILY=apt OS_ROLE=vm RUN_YES=1; unset DRY_RUN; pkg_install curl"
expect "os_dispatch prefers fn__<id>"     "fedora-special" bash -c "source '$L'; use pkg; pkg_install__fedora(){ echo fedora-special; }; OS_ID=fedora OS_FAMILY=dnf OS_ROLE=vm pkg_install x"
expect "os_dispatch unknown family dies"  "*no implementation for gentoo*Define pkg_install__unknown*" bash -c "source '$L'; use pkg; OS_ID=gentoo OS_FAMILY=unknown OS_ROLE=vm pkg_install x"
expect "pkg_install_for picks this family's list" "*would run: sudo dnf install a b*" bash -c "source '$L'; use pkg; OS_ID=fedora OS_FAMILY=dnf OS_ROLE=vm; pkg_install_for 'apt:x' 'dnf:a b'"
expect "os_require_family refuses"        "*for apt systems*" bash -c "source '$L'; use os; OS_ID=fedora OS_FAMILY=dnf OS_ROLE=vm; os_require_family apt"
expect "die -c sets the exit code"        "7" bash -c "source '$L'; use core; (die -c 7 msg 2>/dev/null); echo \$?"
expect "dry prints instead of running"    "*would run: rm -rf /nope*" bash -c "source '$L'; use core; dry rm -rf /nope"
expect "app_update substitutes {tag} and {ver}, stops under DRY_RUN" "*x: installing v1.2*would run: curl*download/v1.2/x-1.2.tgz*rc=1*" bash -c "source '$L'; use apps; APPS_DIR='$TMP/apps'; gh_latest_tag(){ echo v1.2; }; app_update x o r '$TMP/x.tgz' 'https://h/download/{tag}/x-{ver}.tgz'; echo rc=\$?"
expect "apps_current / apps_mark round trip" "yes" bash -c "source '$L'; use apps; APPS_DIR='$TMP/apps'; unset DRY_RUN; apps_mark x v1; apps_current x v1 && echo yes"
expect "append_once writes once"          "1" bash -c "source '$L'; use fs; unset DRY_RUN; append_once hello '$TMP/f' 2>/dev/null; append_once hello '$TMP/f' 2>/dev/null; grep -c hello '$TMP/f'"
expect "gh_json_field parses pretty JSON" "v9" bash -c "source '$L'; use dl; gh_json_field '{ \"tag_name\": \"v9\", \"x\": 1 }' tag_name"
expect "expand_path rejects command substitution" "*unsafe*" bash -c "source '$L'; use fs; expand_path '\$(rm x)'"

echo "header parsing"
printf '#!/usr/bin/env bash\n# @summary   spaced   value\n\n# @tags a b\nset -e\n# @summary after code\n' > "$TMP/h.sh"
expect "field value trimmed"              "spaced   value" bash -c "source '$L'; _run_header_field '$TMP/h.sh' summary"
expect "blank line inside header ok"      "a b"            bash -c "source '$L'; _run_header_field '$TMP/h.sh' tags"
expect "missing field is empty"           ""               bash -c "source '$L'; _run_header_field '$TMP/h.sh' roles"

echo "fixtures (relocated copy)"
cp -a "$RUN_ROOT" "$TMP/moved"; rm -rf "$TMP/moved/.cache" "$TMP/moved/.git"
MR=$TMP/moved/bin/run; MC=$TMP/moved/completions/run.bash
mk() {  # mk ID 'EXTRA HEADER LINES' 'BODY' [LIBS]  -> $TMP/moved/cmd/ID.sh
  local id=$1 header=$2 body=$3 libs=${4:-core}; local f="$TMP/moved/cmd/$id.sh"; mkdir -p "${f%/*}"   # two `local`s: see pitfalls
  { printf '#!/usr/bin/env bash\n# @summary test %s\n# @needs %s\n' "$id" "$libs"
    [[ -n $header ]] && printf '%s\n' "$header"
    printf 'set -euo pipefail\nsource "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use %s\n%s\nrun_main "$@"\n' "$libs" "$body"
  } > "$f"; chmod +x "$f"
}
mk t/ok         ''                   'main() { echo "ok-ran $*"; }'
mk t/fail       ''                   'main() { echo fail-ran; return 3; }'
mk t/group      '# @steps t/fail t/ok' 'main() { run_cmd t/fail; run_cmd t/ok; }'
mk t/inner      '# @steps t/ok'      'main() { run_cmd t/ok inner-arg; }'
mk t/outer      '# @steps t/inner'   'main() { run_cmd t/inner; echo outer-done; }'
mk t/undeclared ''                   'main() { run_cmd t/ok; }'
mk t/ask        ''                   'main() { if confirm "inner question"; then echo inner-yes; else echo inner-no; fi; }'
mk t/askgroup   '# @steps t/ask'     'main() { run_cmd t/ask; }'
mk t/vmonly     $'# @roles vm\n# @complete --minimal --with-docker' $'complete_hook() { echo /dev/fixture; }\nmain() { os_require_role vm; log "vmonly args: $*"; pkg_install curl; }' 'core os pkg'
mk t/fullgroup  $'# @roles vm\n# @steps t/vmonly t/ok' 'main() { os_require_role vm; run_cmd t/vmonly "$@"; run_cmd t/ok; log "full done"; }' 'core os'
mk t/bad        '# @steps nope/x'    'main() { :; }'
mk t/badlib     ''                   'main() { :; }' 'core nolib'
MIDX=$("$TMP/moved/tools/index.sh" --rebuild)

echo "dispatcher"
expect "two-word form"                    "*vmonly args: *"           env RUN_ROLE=vm "$MR" t vmonly
expect "one-word form with args"          "*vmonly args: --minimal*would run:*install*curl*" env RUN_ROLE=vm "$MR" t/vmonly --minimal
expect "run help <cmd> shows the header"  "summary*test t/vmonly*roles*vm*complete*--minimal*" "$MR" help t/vmonly
expect "command file is sourceable (main not run)" "main" bash -c "source '$TMP/moved/cmd/t/ok.sh'; declare -F main"

echo "roles"
expect_rc "wrong role refused"            1  env RUN_ROLE=host "$MR" t/vmonly
expect "refusal names the roles"          "*for role(s): vm*detected: host*" env RUN_ROLE=host "$MR" t/vmonly
expect_rc "RUN_FORCE overrides"           0  env RUN_ROLE=host RUN_FORCE=1 "$MR" t/vmonly

echo "completion"
expect "several matches carry descriptions" "*t/ok *- test t/ok*t/outer *- test t/outer*" comp "$MC" 'run t/'
expect "unique match is the bare id"      "t/undeclared"  comp "$MC" 'run t/undecl'
expect "verbs complete"                   "list"          comp "$MC" 'run li'
expect "static @complete flags"           "--minimal
--with-docker"                                            comp "$MC" 'run t/vmonly --'
expect "dynamic complete_hook (with the static words)" "*--minimal*--with-docker*/dev/fixture*" comp "$MC" 'run t/vmonly ""'
expect "--complete protocol via run_main" "*--minimal*--with-docker*/dev/fixture*" "$TMP/moved/cmd/t/vmonly.sh" --complete

echo "bundle"
"$MR" bundle t/vmonly > "$TMP/b.sh"
expect "bundle has no source lines"       "0" bash -c "grep -c '^[[:space:]]*source ' '$TMP/b.sh' || true"
expect "bundle libs in dependency order"  "*lib/core.sh*lib/os.sh*lib/pkg.sh*cmd/t/vmonly.sh*" grep '^# ---- ' "$TMP/b.sh"
expect "bundle runs from / with empty env" "*vmonly args: --with-docker*would run:*install*curl*" bash -c "cd / && env -i PATH=/usr/bin:/bin HOME=/tmp DRY_RUN=1 RUN_ROLE=vm bash -s -- --with-docker < '$TMP/b.sh'"
expect "bundle is sourceable as a library" "[[]sudo[]] apt-get install tmux" env -i PATH=/usr/bin:/bin HOME=/tmp bash -c "sudo(){ echo \"[sudo] \$*\"; }; source '$TMP/b.sh'; OS_ID=debian OS_FAMILY=apt OS_ROLE=vm pkg_install tmux"
expect_rc "bundle of unknown command fails" 1 "$MR" bundle no/such
expect_rc "bundle rejects unknown @steps"  1 "$MR" bundle t/bad
expect "bundle names the unknown step"    "*unknown command 'nope/x'*" "$MR" bundle t/bad
expect "bundle names an unknown @needs library" "*unknown library 'nolib'*" "$MR" bundle t/badlib

echo "remote (fake ssh)"
mkdir -p "$TMP/bin"; printf '#!/usr/bin/env bash\nhost=$1; shift; echo "[ssh $host] $*"; exec env -i PATH=/usr/bin:/bin HOME=/tmp DRY_RUN=1 RUN_ROLE=vm bash -c "$*"\n' > "$TMP/bin/ssh"; chmod +x "$TMP/bin/ssh"
expect "args with spaces survive ssh"     "*[[]ssh myvm[]]*vmonly args: --with-docker arg with space*" env PATH="$TMP/bin:$PATH" "$MR" remote myvm t/vmonly --with-docker "arg with space"
expect "remote forwards the gate and DRY_RUN" "*RUN_CONFIRMED=1 DRY_RUN=1 bash -s*" env PATH="$TMP/bin:$PATH" "$MR" remote myvm t/vmonly

echo "groups"
expect "run help shows steps"             "*steps *t/vmonly t/ok*"  "$MR" help t/fullgroup
expect "group runs steps in order, passes args" "*step: t/vmonly --minimal*vmonly args: --minimal*step: t/ok*ok-ran*full done*" env RUN_ROLE=vm "$MR" t/fullgroup --minimal
expect_rc "group aborts when its role check fails" 1 env RUN_ROLE=host "$MR" t/fullgroup
expect_rc "failing step aborts the group with its status" 3 "$MR" t/group
out=$("$MR" t/group 2>&1 </dev/null | strip); [[ $out == *fail-ran* && $out != *ok-ran* ]] && ok "later steps do not run after a failure" || bad "later steps do not run after a failure" "$out"
expect "nested groups run locally"        "*step: t/inner*step: t/ok inner-arg*ok-ran inner-arg*outer-done*" "$MR" t/outer
"$MR" bundle t/outer > "$TMP/outer.sh"
expect "nested bundle defines inner steps first" "__step_t_ok() (
__step_t_inner() (" grep -o '__step_t_[a-z]*() (' "$TMP/outer.sh"
expect "nested bundle runs from / with empty env" "*ok-ran inner-arg*outer-done*" bash -c "cd / && env -i PATH=/usr/bin:/bin HOME=/tmp RUN_YES=1 bash -s < '$TMP/outer.sh'"
"$MR" bundle t/undeclared > "$TMP/und.sh"
expect "undeclared step fails clearly in a bundle" "*no such command 't/ok'*@steps*" bash -c "cd / && env -i PATH=/usr/bin:/bin HOME=/tmp RUN_YES=1 bash -s < '$TMP/und.sh'"
expect "undeclared step still works locally" "*ok-ran*" "$MR" t/undeclared

echo "relocation"
expect "moved copy resolves its own root (poisoned env ignored)" "$TMP/moved" env RUN_ROOT="$RUN_ROOT" RUN_LIB="$RUN_LIB" RUN_CMD="$RUN_CMD" "$MR" root
expect "moved copy has its own index"     "$TMP/moved/.cache/index.tsv" "$TMP/moved/tools/index.sh"
expect "moved command runs directly"      "*ok-ran direct*" "$TMP/moved/cmd/t/ok.sh" direct
ln -s "$MR" "$TMP/run-link"; expect "symlink to bin/run is followed" "$TMP/moved" "$TMP/run-link" root
expect "moved completion root"            "$TMP/moved" bash -c "source '$MC' 2>/dev/null; _run_root"

echo "picker"
if command -v setsid >/dev/null; then expect "no terminal -> refuses the picker" "*no terminal attached*" setsid -w "$RUN" </dev/null; else skip "no terminal guard" "no setsid"; fi
if [[ -n $HAVE_PTY ]]; then
  grep -P '^cmd\tt/' "$MIDX" | cut -f2,3,4 > "$TMP/list.tsv"
  pty_run 'undecl\r' "'$RUN_ROOT/tools/pick.sh' <'$TMP/list.tsv' >'$TMP/picked'"
  expect "picker: typing filters, Enter picks" "t/undeclared" cat "$TMP/picked"
  pty_run 'group\033[B\r' "'$RUN_ROOT/tools/pick.sh' <'$TMP/list.tsv' >'$TMP/picked2'"
  expect "picker: Down moves selection"    "t/fullgroup" cat "$TMP/picked2"      # 'group' matches t/askgroup, t/fullgroup, t/group (sorted)
  pty_run 'zzz\033' "'$RUN_ROOT/tools/pick.sh' <'$TMP/list.tsv'; echo rc=\$? >'$TMP/rc'"
  expect "picker: Esc cancels with 130"    "rc=130" cat "$TMP/rc"
else skip "picker" "needs script(1) or python3"; fi

echo "confirmation"
expect "DRY_RUN skips the prompt"            "*ok-ran*" "$MR" t/ok
expect "RUN_YES skips the prompt"            "*ok-ran*" env -u DRY_RUN RUN_YES=1 "$MR" t/ok
expect "run -y skips the prompt"             "*ok-ran*" env -u DRY_RUN "$MR" -y t/ok
expect "RUN_YES answers inner confirm with yes" "*inner-yes*" env -u DRY_RUN RUN_YES=1 "$MR" t/ask
if command -v setsid >/dev/null; then
  expect "no terminal -> dies with a hint"   "*no terminal to confirm*RUN_YES*" setsid -w env -u DRY_RUN "$MR" t/ok
  expect_rc "no terminal -> exit 1"          1 setsid -w env -u DRY_RUN "$MR" t/ok
else skip "no-terminal confirmation" "no setsid"; fi
if [[ -n $HAVE_PTY ]]; then
  pty_run 'n\r' "env -u DRY_RUN '$MR' t/ok >'$TMP/c1' 2>&1; echo rc=\$? >>'$TMP/c1'"
  expect "declined -> cancelled with 130"    "*Run t/ok*cancelled*rc=130" cat "$TMP/c1"
  out=$(<"$TMP/c1"); [[ $out != *ok-ran* ]] && ok "declined -> main did not run" || bad "declined -> main did not run" "$out"
  pty_run 'y\r' "env -u DRY_RUN '$MR' t/ok arg1 >'$TMP/c2' 2>&1; echo rc=\$? >>'$TMP/c2'"
  expect "accepted -> runs with its arguments" "*Run t/ok arg1*ok-ran arg1*rc=0" cat "$TMP/c2"
  pty_run 'y\r' "env -u DRY_RUN '$MR' t/outer >'$TMP/c3' 2>&1"
  expect "a group asks exactly once"         "1" bash -c "grep -c 'Run t/' '$TMP/c3'"
  expect "the group prompt lists its steps"  "*group of: t/inner*ok-ran inner-arg*outer-done*" cat "$TMP/c3"
  pty_run 'y\rn\r' "env -u DRY_RUN '$MR' t/askgroup >'$TMP/c5' 2>&1"
  expect "confirmed group: steps still ask their own questions" "*Run t/askgroup*inner question*inner-no*" cat "$TMP/c5"
  expect "...and the gate was asked once"    "1" bash -c "grep -c 'Run t/' '$TMP/c5'"
  pty_run 'n\r' "env -i PATH=/usr/bin:/bin HOME=/tmp bash -s <'$TMP/outer.sh' >'$TMP/c4' 2>&1; echo rc=\$? >>'$TMP/c4'"
  expect "a bundle prompts with injected id and steps" "*t/outer*group of: t/inner*Run t/outer*cancelled*rc=130" cat "$TMP/c4"
else skip "confirmation prompts" "needs script(1) or python3"; fi

echo
printf '%d passed, %d failed\n' "$pass" "$fail"
(( fail == 0 ))

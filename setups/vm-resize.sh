#!/usr/bin/env bash
#
# resize.sh — grow the root (/) LVM filesystem after the VM disk was enlarged.
#
# Flow (from resize.txt):
#   0. Print the qemu-img command for the user to run MANUALLY on the host.
#   1. Parse live lsblk / lvdisplay output to figure out the PV partition and
#      LV path backing /, show them, and ask for confirmation (abort on no).
#   2. lsblk                                  (see current sizes)
#   3. sudo pvresize <parsed PV partition>    -> pvs + vgs afterwards
#   4. sudo lvdisplay                         (volume info)
#   5. sudo lvextend -l +100%FREE <LV path>   -> lvs afterwards
#   6. sudo xfs_growfs /                      -> df -h / afterwards
#   7. lsblk                                  (final check)
#
# Every command asks for confirmation first; the default answer is NO.
# Answering no SKIPS that command and continues with the next step.

set -u

# --- helpers -----------------------------------------------------------------

# Ask before running a command. Default answer: no -> skip.
confirm_run() {
    local cmd="$*"
    local reply
    read -r -p ">>> Run: ${cmd} ? [y/N] " reply
    case "${reply}" in
        [yY]|[yY][eE][sS])
            echo "--- running: ${cmd}"
            eval "${cmd}"
            local rc=$?
            if [ ${rc} -ne 0 ]; then
                echo "!!! command failed (exit ${rc})"
            fi
            return ${rc}
            ;;
        *)
            echo "--- skipped: ${cmd}"
            return 1
            ;;
    esac
}

# Show how sizes look after a step (no confirmation, read-only checks).
show_check() {
    echo
    echo "=== size check: $* ==="
    eval "$*"
    echo "==============================================="
    echo
}

# --- step 0: qemu-img (manual, never executed here) --------------------------

cat <<'EOF'
###############################################################################
# STEP 0 — run this MANUALLY on the HOST (this script will NOT run it),
# then reboot the VM so the guest sees the extended disk:
#
#     sudo qemu-img resize /path/to/vm.qcow2 +20G
#
###############################################################################
EOF
echo

# --- step 1: figure out parameters from command outputs ----------------------

echo "Parsing live system info to find the devices backing / ..."

# Source device of / , e.g. /dev/mapper/systemVG-LVRoot
ROOT_SRC=$(findmnt -no SOURCE /)
if [ -z "${ROOT_SRC}" ]; then
    echo "ERROR: could not determine the source device of / (findmnt)." >&2
    exit 1
fi
ROOT_SRC_REAL=$(readlink -f "${ROOT_SRC}")

# From lsblk: find the row of type 'lvm' mounted at '/' and take its parent
# partition (PKNAME) -> that is the physical volume to pvresize.
# (Matches the sample: systemVG-LVRoot mounted at / sits on vda3.)
PV_PART=$(lsblk -rno NAME,TYPE,MOUNTPOINT,PKNAME \
          | awk '$2 == "lvm" && $3 == "/" { print $4; exit }')
if [ -z "${PV_PART}" ]; then
    echo "ERROR: could not find an LVM volume mounted at / in lsblk output." >&2
    exit 1
fi
PV_DEV="/dev/${PV_PART}"

# From lvdisplay: grab all 'LV Path' lines and pick the one that resolves to
# the same device that is mounted at / -> that is the LV to lvextend.
LV_PATH=""
while read -r path; do
    if [ "$(readlink -f "${path}")" = "${ROOT_SRC_REAL}" ]; then
        LV_PATH="${path}"
        break
    fi
done < <(sudo lvdisplay 2>/dev/null | awk '/LV Path/ { print $3 }')
if [ -z "${LV_PATH}" ]; then
    echo "ERROR: could not match any 'LV Path' from lvdisplay to ${ROOT_SRC}." >&2
    exit 1
fi

echo
echo "Figured-out parameters:"
echo "  root source (findmnt /)  : ${ROOT_SRC}"
echo "  PV partition (from lsblk): ${PV_DEV}"
echo "  LV path (from lvdisplay) : ${LV_PATH}"
echo
echo "Commands that will be offered:"
echo "  sudo pvresize ${PV_DEV}"
echo "  sudo lvextend -l +100%FREE ${LV_PATH}"
echo "  sudo xfs_growfs /"
echo

read -r -p ">>> Do these parameters look correct? [y/N] " reply
case "${reply}" in
    [yY]|[yY][eE][sS]) ;;
    *) echo "Aborting: parameters not confirmed."; exit 1 ;;
esac
echo

# --- step 2: initial size check ----------------------------------------------

confirm_run "lsblk"
echo

# --- step 3: resize the physical volume --------------------------------------

if confirm_run "sudo pvresize ${PV_DEV}"; then
    show_check "sudo pvs; sudo vgs"
fi

# --- step 4: volume info ------------------------------------------------------

confirm_run "sudo lvdisplay"
echo

# --- step 5: extend the logical volume ----------------------------------------

if confirm_run "sudo lvextend -l +100%FREE ${LV_PATH}"; then
    show_check "sudo lvs"
fi

# --- step 6: grow the filesystem ----------------------------------------------

if confirm_run "sudo xfs_growfs /"; then
    show_check "df -h /"
fi

# --- step 7: final check -------------------------------------------------------

confirm_run "lsblk"

echo
echo "Done."

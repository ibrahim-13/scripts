# @summary systemd service helpers (status, start, enable) that honour DRY_RUN
# @needs core
## svc_active UNIT -> 0 if UNIT is running
svc_active()     { systemctl is-active --quiet "$1"; }
## svc_start UNIT -> start UNIT (sudo)
svc_start()      { dry sudo systemctl start "$1"; }
## svc_enable UNIT -> enable UNIT at boot (sudo)
svc_enable()     { dry sudo systemctl enable "$1"; }
## svc_enable_now UNIT -> enable and start UNIT (sudo)
svc_enable_now() { dry sudo systemctl enable --now "$1"; }

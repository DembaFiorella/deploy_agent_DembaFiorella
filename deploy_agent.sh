#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/templates"
cd "$SCRIPT_DIR" || exit 1

PROJECT_DIR=""

info()  { echo "[INFO]  $*"; }
ok()    { echo "[ OK ]  $*"; }
warn()  { echo "[WARN]  $*"; }
err()   { echo "[ERROR] $*" >&2; }

ask_project_name() {
    local input
    read -r -p "Enter project name (creates attendance_tracker_<name>): " input
    if [[ ! "$input" =~ ^[A-Za-z0-9_-]+$ ]]; then
        err "Invalid name. Use only letters, digits, '_' or '-' (no spaces or slashes)."
        return 1
    fi
    NAME="$input"
    PROJECT_DIR_CAND="attendance_tracker_${NAME}"
    return 0
}

ask_count() {
    local prompt="$1" max="$2" n
    read -r -p "$prompt (1-$max): " n
    if [[ ! "$n" =~ ^[0-9]+$ ]] || (( n < 1 || n > max )); then
        err "Please enter a whole number between 1 and $max."
        return 1
    fi
    echo "$n"
}

handle_interrupt() {
    local sig="$1"
    trap '' INT TSTP
    echo
    warn "Deployment interrupted by $sig."
    if [[ -n "$PROJECT_DIR" && -d "$PROJECT_DIR" ]]; then
        local zipfile="${PROJECT_DIR}_archive.zip"
        info "Archiving the incomplete project into $zipfile ..."
        if zip -rq "$zipfile" "$PROJECT_DIR"; then
            ok "Archive created: $SCRIPT_DIR/$zipfile"
            rm -rf "$PROJECT_DIR"
            ok "Removed incomplete directory $PROJECT_DIR."
        else
            err "Could not create the zip archive; leaving $PROJECT_DIR in place."
        fi
    else
        info "Nothing had been created yet, so there is nothing to archive."
    fi
    echo "Session closed cleanly."
    exit 130
}


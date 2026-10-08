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


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

enable_traps()  {
    trap 'handle_interrupt SIGINT'  INT
    trap 'handle_interrupt SIGTSTP' TSTP
}
disable_traps() { trap - INT TSTP; }

run_app() {
    local dir="$1"
    if [[ -z "$dir" ]]; then
        ask_project_name || return 1
        dir="$PROJECT_DIR_CAND"
    fi
    if [[ ! -d "$dir" ]]; then
        err "Project directory '$dir' not found. Deploy it first (--deploy)."
        return 1
    fi
    if [[ ! -f "$dir/attendance_checker.py" ]]; then
        err "'$dir/attendance_checker.py' is missing; the deployment looks incomplete."
        return 1
    fi
    info "Starting the application in $dir ..."
    ( cd "$dir" && python3 attendance_checker.py )
    local rc=$?
    if (( rc == 0 )); then
        ok "Application exited normally."
    else
        warn "Application exited with status $rc."
    fi
    return $rc
}

build_fresh_roster() {
    local count="$1" out="$2" i
    local names=("Alice Johnson" "Bob Smith" "Carol Williams" "David Brown" "Eve Davis"
                 "Frank Miller" "Grace Wilson" "Henry Moore" "Ivy Taylor" "Jack Anderson"
                 "Karen Thomas" "Leo Jackson" "Mia White" "Noah Harris" "Olivia Martin"
                 "Paul Thompson" "Quinn Garcia" "Rita Martinez" "Sam Robinson" "Tina Clark")
    local emails=("alice@example.com" "bob@example.com" "carol@example.com" "david@example.com"
                  "eve@example.com" "frank@example.com" "grace@example.com" "henry@example.com"
                  "ivy@example.com" "jack@example.com" "karen@example.com" "leo@example.com"
                  "mia@example.com" "noah@example.com" "olivia@example.com" "paul@example.com"
                  "quinn@example.com" "rita@example.com" "sam@example.com" "tina@example.com")
    echo "Email,Names,Attendance Count,Absence Count" > "$out"
    for ((i = 0; i < count; i++)); do
        echo "${emails[$i]},${names[$i]},0,0" >> "$out"
    done
}

preflight_checks() {
    info "Running pre-flight checks..."
    local missing=0 tool f
    for tool in python3 zip; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            err "Required tool '$tool' is not installed or not in PATH."
            missing=1
        fi
    done
    if (( missing )); then
        err "Install the missing tool(s) and try again."
        return 1
    fi
    for f in attendance_checker.py assets.csv config.json; do
        if [[ ! -f "$TEMPLATES_DIR/$f" ]]; then
            err "Template '$TEMPLATES_DIR/$f' not found."
            return 1
        fi
    done
    ok "$(python3 --version) and zip found; templates present."
}


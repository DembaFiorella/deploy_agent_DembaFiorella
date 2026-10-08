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

confirm_overwrite() {
    local dir="$1" ans
    if [[ -e "$dir" ]]; then
        warn "Directory '$dir' already exists."
        read -r -p "Overwrite it? This deletes the existing project. (y/N): " ans
        if [[ "$ans" =~ ^[Yy]$ ]]; then
            rm -rf "$dir"
        else
            err "Aborted: '$dir' already exists and was not overwritten."
            return 1
        fi
    fi
    return 0
}

_abort_deploy() {
    disable_traps
    if [[ -n "$PROJECT_DIR" && -d "$PROJECT_DIR" ]]; then
        rm -rf "$PROJECT_DIR"
        warn "Removed incomplete directory $PROJECT_DIR."
    fi
    PROJECT_DIR=""
}

populate_files() {
    local dir="$1" total_rows choice n
    cp "$TEMPLATES_DIR/attendance_checker.py" "$dir/attendance_checker.py"
    cp "$TEMPLATES_DIR/config.json"           "$dir/Helpers/config.json"

    total_rows=$(awk 'END{print NR-1}' "$TEMPLATES_DIR/assets.csv")
    echo "How should the student roster be built?"
    echo "  A) Copy N students from templates/assets.csv (existing history, total_sessions=5)"
    echo "  B) Generate a fresh roster (counts start at 0, total_sessions=1)"
    read -r -p "Choose A or B: " choice
    case "${choice^^}" in
        A)
            n=$(ask_count "How many students to copy" "$total_rows") || { _abort_deploy; return 1; }
            awk -v n="$((n + 1))" 'NR<=n' "$TEMPLATES_DIR/assets.csv" > "$dir/Helpers/assets.csv"
            ok "Copied $n students (plus header) from the template."
            ;;
        B)
            n=$(ask_count "How many students to generate" 20) || { _abort_deploy; return 1; }
            build_fresh_roster "$n" "$dir/Helpers/assets.csv"
            sed -i.bak 's/\("total_sessions":[[:space:]]*\)[0-9][0-9]*/\11/' "$dir/Helpers/config.json"
            rm -f "$dir/Helpers/config.json.bak"
            ok "Generated $n students; set total_sessions to 1."
            ;;
        *)
            err "Invalid choice '$choice'. Expected A or B."
            _abort_deploy
            return 1
            ;;
    esac
}

set_permissions() {
    local dir="$1"
    chmod +x  "$dir/attendance_checker.py"
    chmod 600 "$dir/Helpers/config.json"
    ok "Permissions set:"
    ls -l "$dir/attendance_checker.py" "$dir/Helpers/config.json" | awk '{print "        " $1 "  " $NF}'
}

update_thresholds() {
    local dir="$1" upd warn_v fail_v
    read -r -p "Update the attendance alert thresholds? (y/N): " upd
    if [[ "$upd" =~ ^[Yy]$ ]]; then
        read -r -p "Warning threshold % [75]: " warn_v;  warn_v="${warn_v:-75}"
        read -r -p "Failure threshold % [50]: " fail_v;  fail_v="${fail_v:-50}"
        if [[ ! "$warn_v" =~ ^[0-9]+$ || ! "$fail_v" =~ ^[0-9]+$ ]] \
           || (( warn_v > 100 || fail_v > 100 || fail_v >= warn_v )); then
            warn "Invalid values (need integers 0-100 with failure < warning). Keeping defaults."
        else
            sed -i.bak \
                -e "s/\(\"warning\":[[:space:]]*\)[0-9][0-9]*/\1${warn_v}/" \
                -e "s/\(\"failure\":[[:space:]]*\)[0-9][0-9]*/\1${fail_v}/" \
                "$dir/Helpers/config.json"
            rm -f "$dir/Helpers/config.json.bak"
            chmod 600 "$dir/Helpers/config.json"
            ok "Thresholds updated: warning=${warn_v}, failure=${fail_v}"
        fi
    else
        info "Keeping default thresholds."
    fi
}

deploy() {
    preflight_checks || return 1
    ask_project_name || return 1
    local dir="$PROJECT_DIR_CAND"
    confirm_overwrite "$dir" || return 1

    PROJECT_DIR="$dir"
    enable_traps

    mkdir -p "$dir/Helpers" "$dir/reports" || {
        err "Could not create directories."
        disable_traps; PROJECT_DIR=""
        return 1
    }
    ok "Created $dir/, $dir/Helpers/ and $dir/reports/"

    populate_files "$dir" || return 1
    set_permissions "$dir"
    update_thresholds "$dir"

    disable_traps
    PROJECT_DIR=""
    ok "Deployment of $dir complete."

    info "Verifying deployment by launching the application..."
    run_app "$dir"
}

archive_logs() {
    ask_project_name || return 1
    local dir="$PROJECT_DIR_CAND"
    if [[ ! -d "$dir" ]]; then
        err "Project directory '$dir' not found."
        return 1
    fi

    local ts archived=0
    ts="$(date +%Y%m%d_%H%M%S)"
    local logs=(attendance absent)
    local name src dest_dir dest

    for name in "${logs[@]}"; do
        src="$dir/reports/${name}.log"
        dest_dir="$dir/archives/$name"
        dest="$dest_dir/${name}_${ts}.log"
        if [[ -f "$src" ]]; then
            mkdir -p "$dest_dir" && cp "$src" "$dest" \
                && { ok "Archived ${name}.log -> $dest"; archived=$((archived + 1)); } \
                || err "Failed to archive ${name}.log"
        else
            info "No ${name}.log found in $dir/reports/ - skipping."
        fi
    done

    if (( archived == 0 )); then
        warn "No logs were archived. Run the application first (--run)."
    else
        ok "$archived log file(s) archived."
    fi
    return 0
}

usage() {
    cat <<EOF
Usage: $0 [--deploy | --run | --archive | --help]
  (no option)  Show the interactive menu
  --deploy     Deploy a new attendance tracker project
  --run        Run an already deployed project
  --archive    Archive reports/*.log of a deployed project
EOF
}

menu() {
    while true; do
        echo
        echo "===== Attendance Tracker Deploy Agent ====="
        echo "1) Deploy the application"
        echo "2) Run the application"
        echo "3) Archive the log files"
        echo "4) Exit"
        local opt
        read -r -p "Select an option [1-4]: " opt
        case "$opt" in
            1) deploy ;;
            2) run_app "" ;;
            3) archive_logs ;;
            4) echo "Goodbye."; exit 0 ;;
            *) warn "Invalid option '$opt'." ;;
        esac
    done
}


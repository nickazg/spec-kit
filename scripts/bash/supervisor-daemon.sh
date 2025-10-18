#!/usr/bin/env bash
# Supervisor Daemon - Persistent background process for project monitoring
# Monitors: git state, file drift, constitution compliance
# Communicates via: file-based inbox/outbox messaging
#
# Usage: supervisor-daemon.sh [--verbose]

set -euo pipefail

# Parse command line arguments
VERBOSE=false
for arg in "$@"; do
    case "$arg" in
        --verbose|-v)
            VERBOSE=true
            ;;
    esac
done

# Logging function
log() {
    if $VERBOSE; then
        echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*" >&2
    fi
}

# Get repository root
get_repo_root() {
    if git rev-parse --show-toplevel >/dev/null 2>&1; then
        git rev-parse --show-toplevel
    else
        local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        (cd "$script_dir/../.." && pwd)
    fi
}

REPO_ROOT=$(get_repo_root)
SUPERVISOR_DIR="$REPO_ROOT/.speckit/supervisor"
STATE_FILE="$SUPERVISOR_DIR/state.json"
CONFIG_FILE="$SUPERVISOR_DIR/config.json"
HEARTBEAT_FILE="$SUPERVISOR_DIR/heartbeat"
INBOX_DIR="$SUPERVISOR_DIR/inbox"
OUTBOX_DIR="$SUPERVISOR_DIR/outbox"
OBSERVATIONS_DIR="$SUPERVISOR_DIR/observations"
PID_FILE="$SUPERVISOR_DIR/supervisor.pid"

# Ensure directories exist
mkdir -p "$INBOX_DIR" "$OUTBOX_DIR" "$OBSERVATIONS_DIR"

# Signal handling for graceful shutdown
RUNNING=true

handle_shutdown() {
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] Supervisor shutting down gracefully..." >&2
    RUNNING=false

    # Clean up PID file
    if [[ -f "$PID_FILE" ]]; then
        rm -f "$PID_FILE"
    fi

    exit 0
}

trap handle_shutdown SIGTERM SIGINT

# Initialize or load configuration
init_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" <<'EOF'
{
  "heartbeat_interval": 30,
  "delta_scan_interval": 30,
  "full_scan_interval": 300,
  "max_observations": 100
}
EOF
    fi
}

# Initialize state if needed
init_state() {
    if [[ ! -f "$STATE_FILE" ]]; then
        local current_branch="unknown"
        local git_head="unknown"

        if git rev-parse --abbrev-ref HEAD >/dev/null 2>&1; then
            current_branch=$(git rev-parse --abbrev-ref HEAD)
        fi

        if git rev-parse HEAD >/dev/null 2>&1; then
            git_head=$(git rev-parse --short HEAD)
        fi

        cat > "$STATE_FILE" <<EOF
{
  "pid": $$,
  "started_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "last_heartbeat": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "current_branch": "$current_branch",
  "git_head": "$git_head",
  "constitution_hash": "",
  "last_full_scan": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "last_delta_scan": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "observations": [],
  "processed_messages": []
}
EOF
    fi
}

# Update heartbeat timestamp
update_heartbeat() {
    date +%s > "$HEARTBEAT_FILE"
}

# Monitor git state for changes
monitor_git() {
    local current_branch="unknown"
    local git_head="unknown"

    if git rev-parse --abbrev-ref HEAD >/dev/null 2>&1; then
        current_branch=$(git rev-parse --abbrev-ref HEAD)
    fi

    if git rev-parse HEAD >/dev/null 2>&1; then
        git_head=$(git rev-parse --short HEAD)
    fi

    # Check for uncommitted changes
    if git rev-parse --git-dir >/dev/null 2>&1; then
        if ! git diff --quiet 2>/dev/null; then
            record_observation "git_changes" "warning" "Uncommitted changes detected in working directory"
        fi

        if ! git diff --cached --quiet 2>/dev/null; then
            record_observation "git_staged" "info" "Staged changes ready to commit"
        fi
    fi

    # Update state with current git info
    update_state_field "current_branch" "$current_branch"
    update_state_field "git_head" "$git_head"
}

# Record an observation
record_observation() {
    local obs_type="$1"
    local severity="$2"
    local message="$3"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local obs_id="obs-$(date +%s)-$$"

    # Create observation JSON
    local observation=$(cat <<EOF
{
  "id": "$obs_id",
  "type": "$obs_type",
  "severity": "$severity",
  "message": "$message",
  "timestamp": "$timestamp",
  "resolved": false
}
EOF
)

    # Append to observations in state (simplified - in production would use jq)
    # For now, write to observations/latest.json
    echo "$observation" >> "$OBSERVATIONS_DIR/latest.json"
}

# Update a field in state.json atomically
update_state_field() {
    local field="$1"
    local value="$2"

    # Simple implementation without jq - update last_heartbeat
    if [[ "$field" == "last_heartbeat" ]]; then
        local temp_file="$STATE_FILE.tmp"
        if [[ -f "$STATE_FILE" ]]; then
            # Read existing state and update timestamp
            sed "s/\"last_heartbeat\": \"[^\"]*\"/\"last_heartbeat\": \"$value\"/" "$STATE_FILE" > "$temp_file"
            mv "$temp_file" "$STATE_FILE"
        fi
    fi
}

# Process inbox messages
process_inbox() {
    for msg_file in "$INBOX_DIR"/*.json 2>/dev/null; do
        [[ -f "$msg_file" ]] || continue

        local msg_id=$(basename "$msg_file" .json)
        local response_file="$OUTBOX_DIR/${msg_id}.json"

        # Simple query handling - return observations summary
        cat > "$response_file" <<EOF
{
  "id": "$msg_id",
  "type": "response",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "response": {
    "status": "healthy",
    "observations_count": $(wc -l < "$OBSERVATIONS_DIR/latest.json" 2>/dev/null || echo 0)
  }
}
EOF

        # Mark message as processed
        rm -f "$msg_file"
    done
}

# Detect file drift (files changed without corresponding tasks)
detect_file_drift() {
    local current_branch=""
    if git rev-parse --abbrev-ref HEAD >/dev/null 2>&1; then
        current_branch=$(git rev-parse --abbrev-ref HEAD)
    fi

    # Extract feature number from branch name
    if [[ ! "$current_branch" =~ ^([0-9]{3})- ]]; then
        return 0  # Skip drift detection if not on feature branch
    fi

    local feature_num="${BASH_REMATCH[1]}"
    local feature_dir="$REPO_ROOT/specs/${feature_num}-"*

    # Check if tasks.md exists
    local tasks_file=""
    for dir in $feature_dir; do
        if [[ -f "$dir/tasks.md" ]]; then
            tasks_file="$dir/tasks.md"
            break
        fi
    done

    if [[ -z "$tasks_file" ]]; then
        return 0  # No tasks.md to check against
    fi

    # Get list of modified files from git
    if git rev-parse --git-dir >/dev/null 2>&1; then
        local modified_files=$(git diff --name-only HEAD 2>/dev/null)

        # Check each modified file to see if it's mentioned in tasks.md
        while IFS= read -r file; do
            [[ -z "$file" ]] && continue

            # Skip spec files themselves
            if [[ "$file" =~ ^specs/ ]]; then
                continue
            fi

            # Check if file is mentioned in tasks.md
            if ! grep -q "$file" "$tasks_file" 2>/dev/null; then
                record_observation "file_drift" "warning" "File modified without corresponding task: $file"
            fi
        done <<< "$modified_files"
    fi
}

# Check constitution compliance
check_constitution_compliance() {
    local constitution_file="$REPO_ROOT/constitution.md"

    if [[ ! -f "$constitution_file" ]]; then
        return 0  # No constitution to check
    fi

    # Read constitution and check for common violations
    # This is a simplified check - in production would parse constitution properly

    # Example: Check if constitution requires tests
    if grep -qi "must.*test" "$constitution_file" 2>/dev/null; then
        # Check if current branch has test files
        local current_branch=""
        if git rev-parse --abbrev-ref HEAD >/dev/null 2>&1; then
            current_branch=$(git rev-parse --abbrev-ref HEAD)
        fi

        if [[ "$current_branch" =~ ^([0-9]{3})- ]]; then
            local feature_num="${BASH_REMATCH[1]}"
            local feature_dir="$REPO_ROOT/specs/${feature_num}-"*

            for dir in $feature_dir; do
                if [[ -f "$dir/tasks.md" ]]; then
                    # Check if any test-related tasks exist
                    if ! grep -qi "test" "$dir/tasks.md" 2>/dev/null; then
                        record_observation "constitution_violation" "warning" "Constitution requires tests, but no test tasks found in tasks.md"
                    fi
                fi
            done
        fi
    fi
}

# Perform delta scan (quick, incremental checks)
delta_scan() {
    monitor_git
    detect_file_drift
    update_state_field "last_delta_scan" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}

# Perform full scan (comprehensive checks)
full_scan() {
    delta_scan

    # Check constitution hash if exists
    local constitution_file="$REPO_ROOT/constitution.md"
    if [[ -f "$constitution_file" ]]; then
        local const_hash=$(shasum -a 256 "$constitution_file" | awk '{print $1}')
        update_state_field "constitution_hash" "sha256:$const_hash"

        # Check constitution compliance
        check_constitution_compliance
    fi

    update_state_field "last_full_scan" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}

# Main monitoring loop
main() {
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] Supervisor daemon starting (PID: $$)..." >&2
    log "Verbose mode enabled - detailed logging active"

    # Initialize
    log "Initializing configuration..."
    init_config
    log "Initializing state..."
    init_state
    log "Setting initial heartbeat..."
    update_heartbeat

    # Read config intervals (default to 30s for delta, 300s for full)
    local heartbeat_interval=30
    local delta_scan_interval=30
    local full_scan_interval=300

    local last_delta_scan=$(date +%s)
    local last_full_scan=$(date +%s)

    # Main loop
    while $RUNNING; do
        local now=$(date +%s)

        # Update heartbeat
        log "Updating heartbeat..."
        update_heartbeat
        update_state_field "last_heartbeat" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

        # Process any incoming messages
        log "Processing inbox..."
        process_inbox

        # Perform delta scan if interval elapsed
        if [[ $((now - last_delta_scan)) -ge $delta_scan_interval ]]; then
            log "Performing delta scan..."
            delta_scan
            last_delta_scan=$now
        fi

        # Perform full scan if interval elapsed
        if [[ $((now - last_full_scan)) -ge $full_scan_interval ]]; then
            log "Performing full scan..."
            full_scan
            last_full_scan=$now
        fi

        # Sleep before next iteration
        sleep $heartbeat_interval
    done
}

# Run main loop
main

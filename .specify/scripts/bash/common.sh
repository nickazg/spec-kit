#!/usr/bin/env bash
# Common functions and variables for all scripts

# Get repository root, with fallback for non-git repositories
get_repo_root() {
    if git rev-parse --show-toplevel >/dev/null 2>&1; then
        git rev-parse --show-toplevel
    else
        # Fall back to script location for non-git repos
        local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        (cd "$script_dir/../../.." && pwd)
    fi
}

# Get current branch, with fallback for non-git repositories
get_current_branch() {
    # First check if SPECIFY_FEATURE environment variable is set
    if [[ -n "${SPECIFY_FEATURE:-}" ]]; then
        echo "$SPECIFY_FEATURE"
        return
    fi

    # Then check git if available
    if git rev-parse --abbrev-ref HEAD >/dev/null 2>&1; then
        git rev-parse --abbrev-ref HEAD
        return
    fi

    # For non-git repos, try to find the latest feature directory
    local repo_root=$(get_repo_root)
    local specs_dir="$repo_root/specs"

    if [[ -d "$specs_dir" ]]; then
        local latest_feature=""
        local highest=0

        for dir in "$specs_dir"/*; do
            if [[ -d "$dir" ]]; then
                local dirname=$(basename "$dir")
                if [[ "$dirname" =~ ^([0-9]{3})- ]]; then
                    local number=${BASH_REMATCH[1]}
                    number=$((10#$number))
                    if [[ "$number" -gt "$highest" ]]; then
                        highest=$number
                        latest_feature=$dirname
                    fi
                fi
            fi
        done

        if [[ -n "$latest_feature" ]]; then
            echo "$latest_feature"
            return
        fi
    fi

    echo "main"  # Final fallback
}

# Check if we have git available
has_git() {
    git rev-parse --show-toplevel >/dev/null 2>&1
}

check_feature_branch() {
    local branch="$1"
    local has_git_repo="$2"

    # For non-git repos, we can't enforce branch naming but still provide output
    if [[ "$has_git_repo" != "true" ]]; then
        echo "[specify] Warning: Git repository not detected; skipped branch validation" >&2
        return 0
    fi

    if [[ ! "$branch" =~ ^[0-9]{3}- ]]; then
        echo "ERROR: Not on a feature branch. Current branch: $branch" >&2
        echo "Feature branches should be named like: 001-feature-name" >&2
        return 1
    fi

    return 0
}

get_feature_dir() { echo "$1/specs/$2"; }

# Find feature directory by numeric prefix instead of exact branch match
# This allows multiple branches to work on the same spec (e.g., 004-fix-bug, 004-add-feature)
find_feature_dir_by_prefix() {
    local repo_root="$1"
    local branch_name="$2"
    local specs_dir="$repo_root/specs"

    # Extract numeric prefix from branch (e.g., "004" from "004-whatever")
    if [[ ! "$branch_name" =~ ^([0-9]{3})- ]]; then
        # If branch doesn't have numeric prefix, fall back to exact match
        echo "$specs_dir/$branch_name"
        return
    fi

    local prefix="${BASH_REMATCH[1]}"

    # Search for directories in specs/ that start with this prefix
    local matches=()
    if [[ -d "$specs_dir" ]]; then
        for dir in "$specs_dir"/"$prefix"-*; do
            if [[ -d "$dir" ]]; then
                matches+=("$(basename "$dir")")
            fi
        done
    fi

    # Handle results
    if [[ ${#matches[@]} -eq 0 ]]; then
        # No match found - return the branch name path (will fail later with clear error)
        echo "$specs_dir/$branch_name"
    elif [[ ${#matches[@]} -eq 1 ]]; then
        # Exactly one match - perfect!
        echo "$specs_dir/${matches[0]}"
    else
        # Multiple matches - this shouldn't happen with proper naming convention
        echo "ERROR: Multiple spec directories found with prefix '$prefix': ${matches[*]}" >&2
        echo "Please ensure only one spec directory exists per numeric prefix." >&2
        echo "$specs_dir/$branch_name"  # Return something to avoid breaking the script
    fi
}

get_feature_paths() {
    local repo_root=$(get_repo_root)
    local current_branch=$(get_current_branch)
    local has_git_repo="false"

    if has_git; then
        has_git_repo="true"
    fi

    # Use prefix-based lookup to support multiple branches per spec
    local feature_dir=$(find_feature_dir_by_prefix "$repo_root" "$current_branch")

    cat <<EOF
REPO_ROOT='$repo_root'
CURRENT_BRANCH='$current_branch'
HAS_GIT='$has_git_repo'
FEATURE_DIR='$feature_dir'
FEATURE_SPEC='$feature_dir/spec.md'
IMPL_PLAN='$feature_dir/plan.md'
TASKS='$feature_dir/tasks.md'
RESEARCH='$feature_dir/research.md'
DATA_MODEL='$feature_dir/data-model.md'
QUICKSTART='$feature_dir/quickstart.md'
CONTRACTS_DIR='$feature_dir/contracts'
EOF
}

check_file() { [[ -f "$1" ]] && echo "  ✓ $2" || echo "  ✗ $2"; }
check_dir() { [[ -d "$1" && -n $(ls -A "$1" 2>/dev/null) ]] && echo "  ✓ $2" || echo "  ✗ $2"; }

# Cross-platform file timestamp detection
get_file_mtime() {
    local file="$1"

    # Detect platform and use appropriate stat command
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS
        stat -f %m "$file" 2>/dev/null
    else
        # Linux
        stat -c %Y "$file" 2>/dev/null
    fi
}

# Session lock management for concurrent command execution
# Uses atomic mkdir operation for cross-platform compatibility
acquire_session_lock() {
    local repo_root=$(get_repo_root)
    local lock_dir="$repo_root/.speckit/session.lock"
    local max_wait="${1:-30}"  # Default 30 seconds max wait
    local waited=0

    while ! mkdir "$lock_dir" 2>/dev/null; do
        if [[ $waited -ge $max_wait ]]; then
            echo "ERROR: Could not acquire session lock after ${max_wait}s" >&2
            echo "Another spec-kit command may be running. Please wait or remove $lock_dir if stale." >&2
            return 1
        fi
        sleep 1
        ((waited++))
    done

    # Store PID in lock directory for debugging
    echo $$ > "$lock_dir/pid"
    return 0
}

release_session_lock() {
    local repo_root=$(get_repo_root)
    local lock_dir="$repo_root/.speckit/session.lock"

    if [[ -d "$lock_dir" ]]; then
        rm -rf "$lock_dir"
    fi
}

# Supervisor management functions
# Ensures a background supervisor daemon is running to monitor project state

# Check if supervisor is healthy (PID exists and heartbeat is recent)
is_supervisor_healthy() {
    local repo_root=$(get_repo_root)
    local supervisor_dir="$repo_root/.speckit/supervisor"
    local pid_file="$supervisor_dir/supervisor.pid"
    local heartbeat_file="$supervisor_dir/heartbeat"
    local max_heartbeat_age=60  # 60 seconds

    # Check if PID file exists
    if [[ ! -f "$pid_file" ]]; then
        return 1
    fi

    local pid=$(cat "$pid_file" 2>/dev/null)
    if [[ -z "$pid" ]]; then
        return 1
    fi

    # Check if process is running
    if ! kill -0 "$pid" 2>/dev/null; then
        return 1
    fi

    # Check heartbeat freshness
    if [[ ! -f "$heartbeat_file" ]]; then
        return 1
    fi

    local heartbeat_time=$(cat "$heartbeat_file" 2>/dev/null)
    local current_time=$(date +%s)
    local age=$((current_time - heartbeat_time))

    if [[ $age -gt $max_heartbeat_age ]]; then
        return 1
    fi

    return 0
}

# Ensure supervisor daemon is running, start if not
ensure_supervisor_running() {
    local repo_root=$(get_repo_root)
    local supervisor_dir="$repo_root/.speckit/supervisor"
    local supervisor_script="$repo_root/.specify/scripts/bash/supervisor-daemon.sh"

    # Create supervisor directory if it doesn't exist
    mkdir -p "$supervisor_dir"/{inbox,outbox,observations}

    # Check if supervisor is already healthy
    if is_supervisor_healthy; then
        return 0
    fi

    # Clean up stale PID file if exists
    if [[ -f "$supervisor_dir/supervisor.pid" ]]; then
        rm -f "$supervisor_dir/supervisor.pid"
    fi

    # Start supervisor in background
    if [[ -f "$supervisor_script" ]]; then
        nohup bash "$supervisor_script" > "$supervisor_dir/supervisor.log" 2>&1 &
        local new_pid=$!
        echo "$new_pid" > "$supervisor_dir/supervisor.pid"

        # Wait briefly for supervisor to initialize
        sleep 1

        # Verify it started successfully
        if is_supervisor_healthy; then
            return 0
        else
            echo "Warning: Supervisor may have failed to start. Check $supervisor_dir/supervisor.log" >&2
            return 1
        fi
    else
        # Supervisor script doesn't exist yet - silently skip
        return 0
    fi
}

# Query supervisor via inbox/outbox messaging
query_supervisor() {
    local query_type="$1"
    local query_payload="$2"
    local repo_root=$(get_repo_root)
    local supervisor_dir="$repo_root/.speckit/supervisor"
    local inbox_dir="$supervisor_dir/inbox"
    local outbox_dir="$supervisor_dir/outbox"

    # Generate unique message ID
    local msg_id="msg-$(date +%s)-$$"
    local inbox_file="$inbox_dir/$msg_id.json"
    local outbox_file="$outbox_dir/$msg_id.json"

    # Write query to inbox
    cat > "$inbox_file" <<EOF
{
  "id": "$msg_id",
  "type": "$query_type",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "payload": $query_payload
}
EOF

    # Wait for response (max 5 seconds)
    local waited=0
    while [[ $waited -lt 5 ]]; do
        if [[ -f "$outbox_file" ]]; then
            cat "$outbox_file"
            rm -f "$inbox_file" "$outbox_file"
            return 0
        fi
        sleep 0.5
        ((waited++))
    done

    # Timeout - clean up and return error
    rm -f "$inbox_file"
    echo '{"error": "Supervisor query timeout"}' >&2
    return 1
}


#!/usr/bin/env bash
# Go Router - Intent classification and routing logic for /go command
# Analyzes natural language input and routes to appropriate spec-kit commands

set -euo pipefail

# Get script directory and load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Intent detection keywords
BUG_KEYWORDS="bug|fix|broken|error|crash|fail|issue|problem|wrong|incorrect|invalid"
FEATURE_KEYWORDS="implement|add|create|build|new|feature|support|enable|allow"
STATUS_KEYWORDS="status|what|where|show|list|progress|current|state"
CONTINUATION_KEYWORDS="continue|proceed|next|resume|go"
PIVOT_KEYWORDS="pivot|restructure|refactor|change|switch|migrate|major"
REFINEMENT_KEYWORDS="update|modify|change|edit|adjust|revise|improve"

# Scope estimation keywords
TRIVIAL_KEYWORDS="typo|comment|log|print|message|text|string"
SMALL_KEYWORDS="file|function|method|class|validation|check"
MEDIUM_KEYWORDS="component|module|service|api|endpoint|integration"
LARGE_KEYWORDS="system|architecture|database|auth|infrastructure"
PIVOT_KEYWORDS_SCOPE="pivot|restructure|major|complete|entire|all"

# Classify user intent from natural language input
classify_intent() {
    local user_input="$1"
    local input_lower=$(echo "$user_input" | tr '[:upper:]' '[:lower:]')

    local intent="unknown"
    local confidence=0.0
    local scope="unknown"
    local scope_confidence=0.0
    local routing_decision="show_help"
    local reasoning=""

    # Empty input = continuation
    if [[ -z "$user_input" ]]; then
        intent="continuation"
        confidence=1.0
        scope="n/a"
        scope_confidence=1.0
        routing_decision="continue_workflow"
        reasoning="Empty input interpreted as continuation request"

    # Bug fix detection (highest priority)
    elif echo "$input_lower" | grep -qE "$BUG_KEYWORDS"; then
        intent="bug_fix"
        confidence=0.85
        routing_decision="add_task"
        reasoning="Bug-related keywords detected: $(echo "$input_lower" | grep -oE "$BUG_KEYWORDS" | head -3 | paste -sd, -)"

        # Estimate scope for bug fix
        scope=$(estimate_scope "$input_lower")
        scope_confidence=0.70

    # Feature request detection
    elif echo "$input_lower" | grep -qE "$FEATURE_KEYWORDS"; then
        intent="feature_request"
        confidence=0.80
        reasoning="Feature request keywords detected: $(echo "$input_lower" | grep -oE "$FEATURE_KEYWORDS" | head -3 | paste -sd, -)"

        # Estimate scope for feature
        scope=$(estimate_scope "$input_lower")
        scope_confidence=0.70

        # Route based on scope
        if [[ "$scope" == "trivial" || "$scope" == "small" ]]; then
            routing_decision="add_task"
        else
            routing_decision="new_spec"
        fi

    # Status query detection
    elif echo "$input_lower" | grep -qE "$STATUS_KEYWORDS"; then
        intent="status_query"
        confidence=0.90
        scope="n/a"
        scope_confidence=1.0
        routing_decision="show_status"
        reasoning="Status query keywords detected"

    # Pivot detection
    elif echo "$input_lower" | grep -qE "$PIVOT_KEYWORDS"; then
        intent="pivot"
        confidence=0.75
        scope="pivot"
        scope_confidence=0.80
        routing_decision="archive_and_pivot"
        reasoning="Pivot/major change keywords detected"

    # Refinement detection
    elif echo "$input_lower" | grep -qE "$REFINEMENT_KEYWORDS"; then
        intent="refinement"
        confidence=0.70
        scope="small"
        scope_confidence=0.60
        routing_decision="manual_edit"
        reasoning="Refinement keywords detected - manual edit recommended"

    # Continuation keywords
    elif echo "$input_lower" | grep -qE "$CONTINUATION_KEYWORDS"; then
        intent="continuation"
        confidence=0.85
        scope="n/a"
        scope_confidence=1.0
        routing_decision="continue_workflow"
        reasoning="Continuation keywords detected"

    # Low confidence - unclear intent
    else
        intent="unclear"
        confidence=0.30
        scope="unknown"
        scope_confidence=0.0
        routing_decision="show_help"
        reasoning="No clear intent patterns detected in input"
    fi

    # Output JSON
    cat <<EOF
{
  "intent": "$intent",
  "confidence": $confidence,
  "scope": "$scope",
  "scope_confidence": $scope_confidence,
  "routing_decision": "$routing_decision",
  "reasoning": "$reasoning"
}
EOF
}

# Estimate scope based on keywords and file mentions
estimate_scope() {
    local input_lower="$1"

    # Check for pivot-level scope
    if echo "$input_lower" | grep -qE "$PIVOT_KEYWORDS_SCOPE"; then
        echo "pivot"
        return
    fi

    # Check for trivial scope
    if echo "$input_lower" | grep -qE "$TRIVIAL_KEYWORDS"; then
        echo "trivial"
        return
    fi

    # Check for small scope
    if echo "$input_lower" | grep -qE "$SMALL_KEYWORDS"; then
        echo "small"
        return
    fi

    # Check for large scope
    if echo "$input_lower" | grep -qE "$LARGE_KEYWORDS"; then
        echo "large"
        return
    fi

    # Check for medium scope
    if echo "$input_lower" | grep -qE "$MEDIUM_KEYWORDS"; then
        echo "medium"
        return
    fi

    # Count words as heuristic (long descriptions = larger scope)
    local word_count=$(echo "$input_lower" | wc -w | tr -d ' ')
    if [[ $word_count -lt 5 ]]; then
        echo "small"
    elif [[ $word_count -lt 15 ]]; then
        echo "medium"
    else
        echo "large"
    fi
}

# Add a task to tasks.md
add_task() {
    local user_input="$1"
    local tasks_file="$2"

    # Generate task description from user input
    local task_desc="$user_input"
    local task_id="T999"  # High priority, will be renumbered by user
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Check if tasks.md exists
    if [[ ! -f "$tasks_file" ]]; then
        echo "ERROR: tasks.md not found at $tasks_file" >&2
        echo "Please run /speckit.tasks first to create the task list." >&2
        return 1
    fi

    # Find the right place to insert (after Phase 1 or at the start)
    # For now, append to the end with a marker
    cat >> "$tasks_file" <<EOF

---

## Quick Fix (Added via /go - $timestamp)

- [ ] $task_id [P0] [URGENT] $task_desc

EOF

    echo "✓ Task added to $tasks_file"
    echo ""
    echo "Task: $task_desc"
    echo "Priority: P0 (High Priority)"
    echo ""
    echo "Next steps:"
    echo "  - Run /speckit.implement to execute this task"
    echo "  - Or manually work on the task and mark it [X] when complete"
}

# Determine next workflow step based on file existence
determine_next_step() {
    local feature_dir="$1"

    if [[ ! -f "$feature_dir/spec.md" ]]; then
        echo "specify"
        echo "No specification found. Run /speckit.specify to create one."
        return
    fi

    if [[ ! -f "$feature_dir/plan.md" ]]; then
        echo "plan"
        echo "Specification exists. Run /speckit.plan to create implementation plan."
        return
    fi

    if [[ ! -f "$feature_dir/tasks.md" ]]; then
        echo "tasks"
        echo "Plan exists. Run /speckit.tasks to generate task breakdown."
        return
    fi

    # Check if tasks are incomplete
    local total=$(grep -c "^- \[.\]" "$feature_dir/tasks.md" 2>/dev/null || echo 0)
    local completed=$(grep -c "^- \[X\]" "$feature_dir/tasks.md" 2>/dev/null || echo 0)

    if [[ $completed -lt $total ]]; then
        echo "implement"
        echo "Tasks ready. Run /speckit.implement to start implementation."
        return
    fi

    # All done
    echo "complete"
    echo "All tasks complete! Consider running tests or creating a pull request."
}

# Generate status report
generate_status() {
    local feature_dir="$1"
    local repo_root=$(get_repo_root)

    echo "=== Project Status ==="
    echo ""

    # Git status
    if git rev-parse --git-dir >/dev/null 2>&1; then
        local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
        local commit=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
        echo "Branch: $branch"
        echo "Commit: $commit"

        # Check for uncommitted changes
        if ! git diff --quiet 2>/dev/null; then
            echo "Status: Uncommitted changes present"
        else
            echo "Status: Working directory clean"
        fi
    else
        echo "Branch: Not a git repository"
    fi

    echo ""
    echo "Feature Directory: $feature_dir"

    # Check spec files
    echo ""
    echo "Specification Files:"
    if [[ -f "$feature_dir/spec.md" ]]; then
        echo "  ✓ spec.md"
    else
        echo "  ✗ spec.md (missing)"
    fi

    if [[ -f "$feature_dir/plan.md" ]]; then
        echo "  ✓ plan.md"
    else
        echo "  ✗ plan.md (missing)"
    fi

    if [[ -f "$feature_dir/tasks.md" ]]; then
        echo "  ✓ tasks.md"

        # Count tasks
        local total=$(grep -c "^- \[.\]" "$feature_dir/tasks.md" 2>/dev/null || echo 0)
        local completed=$(grep -c "^- \[X\]" "$feature_dir/tasks.md" 2>/dev/null || echo 0)
        local remaining=$((total - completed))

        echo "    Tasks: $completed/$total complete ($remaining remaining)"
    else
        echo "  ✗ tasks.md (missing)"
    fi

    # Supervisor observations
    echo ""
    local obs_file="$repo_root/.speckit/supervisor/observations/latest.json"
    if [[ -f "$obs_file" ]] && [[ -s "$obs_file" ]]; then
        local obs_count=$(wc -l < "$obs_file" | tr -d ' ')
        echo "Supervisor Observations: $obs_count"
    else
        echo "Supervisor Observations: None"
    fi
}

# Archive current plan for pivot scenarios
archive_plan() {
    local feature_dir="$1"
    local plan_file="$feature_dir/plan.md"

    if [[ ! -f "$plan_file" ]]; then
        echo "No plan.md found to archive."
        return 1
    fi

    # Create archive with timestamp
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local archive_file="$feature_dir/plan_v${timestamp}.md"

    cp "$plan_file" "$archive_file"

    echo "✓ Archived current plan to: plan_v${timestamp}.md"
    echo ""
    echo "Original plan preserved. You can now modify plan.md for your pivot."
}

# Create migration strategy document
create_migration_strategy() {
    local feature_dir="$1"
    local pivot_description="$2"

    local migration_file="$feature_dir/migration.md"

    cat > "$migration_file" <<EOF
# Migration Strategy

**Created**: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
**Pivot Reason**: $pivot_description

## Context

This feature is undergoing a major pivot/restructuring. The original plan has been archived.

## Migration Steps

1. [ ] Review archived plan (see plan_v*.md files)
2. [ ] Identify components that can be preserved
3. [ ] Identify components that need complete rewrite
4. [ ] Update spec.md with new requirements
5. [ ] Update plan.md with new architecture
6. [ ] Regenerate tasks.md with /speckit.tasks
7. [ ] Create data migration scripts (if applicable)
8. [ ] Update tests for new architecture
9. [ ] Document breaking changes

## Preserved Work

List components/code that can be reused:
-

## Deprecated Work

List components/code that will be removed:
-

## Risk Assessment

- **Data Loss Risk**: [Low/Medium/High]
- **Timeline Impact**: [estimate additional time needed]
- **Team Impact**: [who needs to be informed]

## Notes

Add any additional context or concerns about this pivot:

EOF

    echo "✓ Created migration strategy document: migration.md"
    echo ""
    echo "Please fill in the migration steps and risk assessment."
}

# Check for constitution conflicts in pivot scenarios
check_pivot_constitution_conflicts() {
    local repo_root=$(get_repo_root)
    local constitution_file="$repo_root/constitution.md"
    local pivot_description="$1"

    if [[ ! -f "$constitution_file" ]]; then
        return 0  # No constitution to check
    fi

    # Convert pivot description to lowercase for checking
    local pivot_lower=$(echo "$pivot_description" | tr '[:upper:]' '[:lower:]')

    # Check for potential constitution conflicts
    local conflicts=()

    # Example: Check if constitution forbids certain technologies
    if grep -qi "must use.*sql" "$constitution_file" 2>/dev/null; then
        if echo "$pivot_lower" | grep -qE "nosql|mongodb|dynamodb"; then
            conflicts+=("Constitution requires SQL databases, but pivot mentions NoSQL")
        fi
    fi

    # Check if constitution requires specific patterns
    if grep -qi "must.*test" "$constitution_file" 2>/dev/null; then
        conflicts+=("Remember: Constitution requires tests - ensure new architecture includes test strategy")
    fi

    # Display conflicts if any
    if [[ ${#conflicts[@]} -gt 0 ]]; then
        echo ""
        echo "⚠ Constitution Conflict Check:"
        echo ""
        for conflict in "${conflicts[@]}"; do
            echo "  - $conflict"
        done
        echo ""
        echo "Please review constitution.md before proceeding with this pivot."
        echo "You may need to update the constitution or adjust your pivot plan."
        return 1
    fi

    return 0
}

# Handle pivot workflow
handle_pivot() {
    local feature_dir="$1"
    local pivot_description="$2"

    echo "=== PIVOT WORKFLOW ==="
    echo ""
    echo "⚠ WARNING: Major architecture changes detected"
    echo ""
    echo "This will:"
    echo "  1. Archive your current plan.md"
    echo "  2. Create a migration.md strategy document"
    echo "  3. Check for constitution conflicts"
    echo ""

    # Check constitution first
    if ! check_pivot_constitution_conflicts "$pivot_description"; then
        echo ""
        echo "Constitution conflicts detected. Please resolve before proceeding."
        return 1
    fi

    # Archive current plan
    archive_plan "$feature_dir" || return 1

    # Create migration strategy
    create_migration_strategy "$feature_dir" "$pivot_description"

    echo ""
    echo "Next steps:"
    echo "  1. Review and complete migration.md"
    echo "  2. Update spec.md with new requirements"
    echo "  3. Run /speckit.plan to create new architecture plan"
    echo "  4. Run /speckit.tasks to generate new task breakdown"
    echo ""
    echo "Your previous work is preserved in the archived plan file."
}

# Get supervisor observations
get_observations() {
    local repo_root=$(get_repo_root)
    local obs_file="$repo_root/.speckit/supervisor/observations/latest.json"

    if [[ ! -f "$obs_file" ]] || [[ ! -s "$obs_file" ]]; then
        echo "No observations recorded."
        return 0
    fi

    echo "=== Supervisor Observations ==="
    echo ""

    # Simple display (would use jq in production)
    cat "$obs_file"
}

# Main command router
main() {
    local command="${1:-}"
    shift || true

    case "$command" in
        classify)
            classify_intent "$*"
            ;;
        add-task)
            add_task "$1" "$2"
            ;;
        status)
            generate_status "$1"
            ;;
        next-step)
            determine_next_step "$1"
            ;;
        pivot)
            handle_pivot "$1" "$2"
            ;;
        observations)
            get_observations
            ;;
        *)
            echo "Usage: go-router.sh {classify|add-task|status|next-step|pivot|observations} [args...]" >&2
            exit 1
            ;;
    esac
}

# Run main
main "$@"

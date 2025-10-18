---
description: Intelligent workflow entrypoint - analyzes intent, estimates scope, and routes to appropriate commands
scripts:
  sh: scripts/bash/check-prerequisites.sh --json --paths-only
  ps: scripts/powershell/check-prerequisites.ps1 -Json -PathsOnly
---

## User Input

```text
$ARGUMENTS
```

## Phase 1: Initialize Context & Acquire Lock

**Acquire session lock** to prevent concurrent /speckit.go executions:

```bash
# Source common.sh and acquire lock
source scripts/bash/common.sh
acquire_session_lock 10 || exit 1
trap release_session_lock EXIT

# Start supervisor if not running
ensure_supervisor_running
```

Run `{SCRIPT}` from repo root to get REPO_ROOT, BRANCH, and FEATURE_DIR paths.

```bash
eval $({SCRIPT} --json --paths-only)
```

## Phase 2: Gather Project State

Collect contextual information about the current project state:

1. **Git Status** (if available):
   - Run `git status --porcelain` to check for uncommitted changes
   - Run `git rev-parse --abbrev-ref HEAD` to get current branch
   - Run `git rev-parse --short HEAD` to get current commit

2. **Feature State**:
   - Check if FEATURE_DIR exists
   - Check which spec files exist: spec.md, plan.md, tasks.md
   - Read tasks.md if it exists to understand current progress

3. **Supervisor Observations** (if available):
   - Read `.speckit/supervisor/observations/latest.json` for any warnings/errors
   - Check supervisor health with `is_supervisor_healthy` from common.sh

## Phase 3: Classify Intent & Estimate Scope

Use the go-router.sh script to analyze user input and determine intent:

```bash
bash scripts/bash/go-router.sh classify "$USER_INPUT"
```

Expected output (JSON):
```json
{
  "intent": "bug_fix|feature_request|status_query|continuation|pivot|refinement",
  "confidence": 0.85,
  "scope": "trivial|small|medium|large|pivot",
  "scope_confidence": 0.70,
  "routing_decision": "add_task|new_spec|show_status|continue_workflow|archive_and_pivot",
  "reasoning": "Explanation of classification"
}
```

## Phase 4: Display Decision & Get Confirmation

**IMPORTANT**: Before executing any action, display the classification result to the user:

```
Intent detected: Bug Fix
Scope estimate: Small (affects 1-2 files)
Recommended action: Add high-priority task to existing tasks.md

User input: "found bug in auth validation - tokens aren't validated"
Reasoning: Keywords "bug" and "validation" detected, single component mentioned

Proceed with this action? (This will add a P0 task to tasks.md)
```

**Wait for user confirmation** before proceeding. If user says "no", "wait", or "stop", halt execution.

## Phase 5: Execute Routing Decision

Based on the routing decision from Phase 3:

### Route: add_task (Bug Fix - Small/Trivial)
If intent is "bug_fix" and scope is "trivial" or "small":

1. Call go-router.sh to inject task into tasks.md:
   ```bash
   bash scripts/bash/go-router.sh add-task "$USER_INPUT" "$FEATURE_DIR/tasks.md"
   ```

2. Inform user:
   ```
   ✓ Added high-priority task to tasks.md

   Next steps:
   - Run /speckit.implement to execute the fix
   - Or manually work on the task and mark it complete
   ```

### Route: new_spec (Feature Request - Medium+)
If intent is "feature_request" and scope is "medium" or larger:

1. Inform user:
   ```
   This looks like a medium-sized feature request.
   Recommended: Create a proper specification first.

   Run: /speckit.specify to start the specification process
   ```

2. Exit - let the user run /speckit.specify manually

### Route: show_status (Status Query)
If intent is "status_query":

1. Call go-router.sh to generate status report:
   ```bash
   bash scripts/bash/go-router.sh status "$FEATURE_DIR"
   ```

2. Display the status report (current branch, progress, pending tasks, observations)

### Route: continue_workflow (Empty Input / Continuation)
If intent is "continuation" (empty input or "continue"):

1. Determine next logical step based on file existence:
   - No spec.md → Run /speckit.specify
   - spec.md but no plan.md → Run /speckit.plan
   - plan.md but no tasks.md → Run /speckit.tasks
   - tasks.md exists with incomplete tasks → Run /speckit.implement
   - All tasks complete → Suggest running tests or creating PR

2. Display recommendation and execute the next command automatically

### Route: archive_and_pivot (Pivot Scenarios)
If intent is "pivot":

1. **WARNING**: Display warning about potential work loss
2. Call go-router.sh to handle pivot workflow
3. Archive current plan.md with timestamp
4. Create migration.md document
5. Guide user through pivot process

### Route: refinement (Update/Modify Existing Spec)
If intent is "refinement":

1. Inform user:
   ```
   This looks like a request to update an existing specification.

   Please manually edit the relevant files:
   - spec.md for requirements changes
   - plan.md for architecture changes
   - tasks.md for task modifications

   Or run the appropriate /speckit.* command to regenerate.
   ```

## Phase 6: Display Observations (If Any)

After completing the routing action, display any supervisor observations:

```bash
bash scripts/bash/go-router.sh observations
```

If observations exist:
```
⚠ Supervisor Observations:
- [WARNING] Uncommitted changes in working directory
- [INFO] 3 tasks remaining in current feature

Consider addressing these before proceeding.
```

## Special Commands

### Supervisor Status
If user input is "supervisor status" or similar:
```bash
if is_supervisor_healthy; then
    echo "✓ Supervisor is healthy"
    cat .speckit/supervisor/state.json | grep -E "pid|last_heartbeat|current_branch" || true
else
    echo "✗ Supervisor is not running or unhealthy"
    echo "Run any /speckit.* command to start it automatically"
fi
```

## Error Handling

If classification confidence is low (<0.5):
```
I'm not sure I understand what you're asking for.

Your input: "$USER_INPUT"

Did you mean:
1. Report a bug in existing code? (try: "/speckit.go found bug in [component]")
2. Request a new feature? (try: "/speckit.go implement [feature description]")
3. Check project status? (try: "/speckit.go status" or just "/speckit.go")
4. Continue from where you left off? (try: "/speckit.go" with no arguments)

Please clarify your intent or run the appropriate /speckit.* command directly.
```

## Notes

- The /speckit.go command is designed to be flexible and forgiving
- It prioritizes speed for quick bug fixes while maintaining rigor for larger changes
- All routing decisions are explained before execution
- User can always abort and run specific /speckit.* commands manually
- Supervisor observations provide additional context but don't block execution
- The Supervisor agent starts automatically when this command runs

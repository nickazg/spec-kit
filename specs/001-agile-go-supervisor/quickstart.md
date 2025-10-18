# Quickstart: `/go` Command Examples

The `/go` command is an intelligent workflow entrypoint that analyzes your natural language input and routes to the appropriate action. It's designed to make spec-kit extremely agile-friendly.

## What is `/go`?

`/go` understands your intent and:
- Classifies what you're trying to do (bug fix, feature request, status query, etc.)
- Estimates the scope (trivial, small, medium, large, pivot)
- Routes to the right action automatically
- Shows you its decision before executing

## Usage Scenarios

### 1. Quick Bug Fix (Most Common)

**Scenario**: You found a bug while working and want to fix it fast without heavy ceremony.

```bash
/go found bug in auth validation - tokens aren't being validated properly
```

**What happens**:
1. Intent: `bug_fix` detected (keywords: "bug", "validation")
2. Scope: `small` estimated (single component mentioned)
3. Action: Adds high-priority task to existing tasks.md
4. Output:
   ```
   Intent detected: Bug Fix
   Scope estimate: Small (affects 1-2 files)
   Recommended action: Add high-priority task to existing tasks.md

    Added high-priority task to tasks.md

   Next steps:
   - Run /speckit.implement to execute the fix
   - Or manually work on the task and mark it [X] when complete
   ```

### 2. Status Query

**Scenario**: You want to know where you are in the workflow.

```bash
/go status
```

or just:

```bash
/go what's my current status
```

**What happens**:
```
=== Project Status ===

Branch: 001-agile-go-supervisor
Commit: a66af9b
Status: Uncommitted changes present

Feature Directory: /path/to/specs/001-agile-go-supervisor

Specification Files:
   spec.md
   plan.md
   tasks.md
    Tasks: 25/56 complete (31 remaining)

Supervisor Observations: 2
```

### 3. Continuation (Resume Workflow)

**Scenario**: You're not sure what to do next - let `/go` guide you.

```bash
/go
```

or:

```bash
/go continue
```

**What happens**:
1. Checks which spec files exist
2. Determines next logical step
3. Recommends or executes the next command

Example outputs:
- No spec.md ’ "Run /speckit.specify to create specification"
- spec.md but no plan.md ’ "Run /speckit.plan to create implementation plan"
- plan.md but no tasks.md ’ "Run /speckit.tasks to generate tasks"
- tasks.md with incomplete tasks ’ "Run /speckit.implement to continue implementation"

### 4. Feature Request (Small Scope)

**Scenario**: You want to add a small feature to the current spec.

```bash
/go add logging to the auth module
```

**What happens**:
1. Intent: `feature_request` detected
2. Scope: `small` estimated (single module)
3. Action: Adds task to tasks.md

```
Intent detected: Feature Request
Scope estimate: Small
Recommended action: Add task to existing tasks.md

 Task added to tasks.md
```

### 5. Feature Request (Medium/Large Scope)

**Scenario**: You want to add a substantial feature that needs proper planning.

```bash
/go implement user profile editing with avatar upload and privacy settings
```

**What happens**:
1. Intent: `feature_request` detected
2. Scope: `medium` estimated (multiple components, "settings" keyword)
3. Action: Redirects to full spec workflow

```
Intent detected: Feature Request
Scope estimate: Medium
Recommended action: Create proper specification

This looks like a medium-sized feature request.
Recommended: Create a proper specification first.

Run: /speckit.specify to start the specification process
```

### 6. Pivot/Major Restructure

**Scenario**: You need to make major architectural changes.

```bash
/go we need to switch from SQL to NoSQL database
```

**What happens**:
1. Intent: `pivot` detected (keywords: "switch", "database")
2. Scope: `pivot` estimated
3. Action: Guides through archiving and migration workflow

```
Intent detected: Pivot
Scope estimate: Pivot (major architecture change)

=== PIVOT WORKFLOW ===

  WARNING: Major architecture changes detected

This will:
  1. Archive your current plan.md
  2. Create a migration.md strategy document
  3. Check for constitution conflicts

 Archived current plan to: plan_v20251018_143022.md
 Created migration strategy document: migration.md

Next steps:
  1. Review and complete migration.md
  2. Update spec.md with new requirements
  3. Run /speckit.plan to create new architecture plan
  4. Run /speckit.tasks to generate new task breakdown

Your previous work is preserved in the archived plan file.
```

### 7. Supervisor Status Check

**Scenario**: You want to check if the background supervisor is healthy.

```bash
/go supervisor status
```

**What happens**:
```
 Supervisor is healthy
  "pid": 12345,
  "last_heartbeat": "2025-10-18T14:32:15Z",
  "current_branch": "001-agile-go-supervisor"
```

or if unhealthy:
```
 Supervisor is not running or unhealthy
Run any /speckit.* command to start it automatically
```

## Background: How `/go` Works

### Intent Classification

`/go` uses keyword matching to classify your intent:

- **Bug Fix**: bug, fix, broken, error, crash, fail, issue, problem
- **Feature**: implement, add, create, build, new, feature, support
- **Status**: status, what, where, show, list, progress, current
- **Pivot**: pivot, restructure, refactor, change, switch, migrate, major
- **Continuation**: (empty input or continue, proceed, next, resume)

### Scope Estimation

`/go` estimates scope based on:

- **Trivial**: typo, comment, log, print, message, text
- **Small**: file, function, method, class, validation (1-2 files)
- **Medium**: component, module, service, api, endpoint (multiple files)
- **Large**: system, architecture, database, auth, infrastructure
- **Pivot**: Major changes affecting entire architecture

### Routing Decisions

Based on intent + scope:

| Intent | Scope | Action |
|--------|-------|--------|
| Bug Fix | Any | Add P0 task to tasks.md |
| Feature | Trivial/Small | Add task to tasks.md |
| Feature | Medium/Large | Redirect to /speckit.specify |
| Status Query | N/A | Generate and display status report |
| Continuation | N/A | Determine and run next logical step |
| Pivot | Pivot | Archive plan, create migration.md |

## Advanced Tips

### 1. Be Specific for Better Classification

```bash
# Good - clear intent
/go fix login bug - session tokens expire too early

# Less clear - might need clarification
/go something's wrong with auth
```

### 2. Use Keywords for Better Routing

```bash
# Signals "small" scope
/go add validation to user input field

# Signals "large" scope
/go refactor entire authentication system to use OAuth2
```

### 3. Check Supervisor Observations

The supervisor runs in the background monitoring your project. Use `/go` to see any warnings:

```bash
/go status
```

Will show observations like:
- File drift (files modified without tasks)
- Constitution violations
- Uncommitted changes

### 4. Combine with Traditional Commands

`/go` doesn't replace `/speckit.*` commands - it complements them:

```bash
# Use /go for quick decisions and status
/go

# Use specific commands when you know what you want
/speckit.plan

# Use /go for rapid bug fixes mid-workflow
/go found issue in error handling - need to add try-catch
```

## Common Patterns

### Daily Development Flow

1. Start your day:
   ```bash
   /go status
   ```

2. Continue where you left off:
   ```bash
   /go
   ```

3. Quick bug fix during implementation:
   ```bash
   /go bug in calculateTotal - doesn't handle negative numbers
   ```

4. Check supervisor observations:
   ```bash
   /go status
   ```

5. End of day - check progress:
   ```bash
   /go status
   ```

### Feature Development Flow

1. Start new feature:
   ```bash
   /speckit.specify Add user profile editing capability
   ```

2. Continue with plan:
   ```bash
   /go
   ’ Suggests: Run /speckit.plan
   ```

3. Bug found during planning:
   ```bash
   /go typo in spec.md requirements section
   ```

4. Resume:
   ```bash
   /go
   ’ Suggests: Run /speckit.tasks
   ```

## Troubleshooting

### "I'm not sure I understand..."

If `/go` can't classify your intent (confidence < 0.5):

```
I'm not sure I understand what you're asking for.

Did you mean:
1. Report a bug? (try: "/go found bug in [component]")
2. Request a new feature? (try: "/go implement [feature]")
3. Check status? (try: "/go status")
4. Continue workflow? (try: "/go")
```

**Solution**: Rephrase with clearer keywords or use a specific `/speckit.*` command.

### Classification Seems Wrong

Before executing, `/go` shows its decision:

```
Intent detected: Feature Request
Scope estimate: Medium

Proceed with this action? (yes/no)
```

You can abort and use a specific command instead:
```
no

# Then run the correct command manually
/speckit.tasks
```

### Supervisor Not Running

```bash
/go supervisor status
```

If unhealthy, any `/speckit.*` command will auto-restart it:
```bash
/speckit.plan  # This starts the supervisor automatically
```

## Summary

`/go` is your intelligent assistant that:
- Understands natural language intent
- Estimates scope automatically
- Routes to the right action
- Asks for confirmation before executing
- Makes spec-kit workflow more agile and less ceremonious

Use it for:
-  Quick bug fixes
-  Status checks
-  Workflow guidance
-  Rapid task additions
-  Pivot management

Use `/speckit.*` commands directly for:
-  When you know exactly what you want
-  Complex feature specifications
-  Detailed planning sessions
-  Task regeneration
-  Full implementations

Both approaches work together to give you maximum flexibility!

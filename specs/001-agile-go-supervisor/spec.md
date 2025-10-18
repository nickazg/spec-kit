# Feature Specification: Agile-Friendly Go Command & Persistent Supervisor

**Feature Branch**: `001-agile-go-supervisor`
**Created**: 2025-10-18
**Status**: Draft
**Input**: User description: "Implement /go command and persistent supervisor subagent for agile-friendly spec-kit development"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Quick Bug Fix During Development (Priority: P1)

A developer is midway through implementing a feature when they discover a critical bug in existing code. Instead of abandoning their current spec workflow or creating heavy ceremony, they want to quickly address the bug without losing context.

**Why this priority**: This is the most common agile scenario - bugs discovered during development need rapid response without disrupting flow. This delivers immediate value by reducing friction in the development process.

**Independent Test**: Developer can type `/go found bug in auth validation` from any point in the workflow, and the system correctly identifies it as a bug fix, assesses scope, and adds it to the current task list (or creates a minimal spec if complex) without requiring manual navigation through the spec-kit commands.

**Acceptance Scenarios**:

1. **Given** developer is on feature branch `004-user-dashboard` with active tasks.md, **When** they run `/go found bug where tokens aren't validated in middleware`, **Then** system analyzes the input, determines it's a small-scope bug fix, adds a high-priority task to tasks.md, and allows immediate implementation
2. **Given** developer is on feature branch with completed spec, **When** they run `/go there's a critical security bug in the database layer`, **Then** system recognizes high complexity, asks for confirmation to create a new sub-spec or task, and guides them through the appropriate workflow
3. **Given** developer discovers a trivial typo, **When** they run `/go fix typo in user.py line 42`, **Then** system creates a lightweight task without spec overhead and proceeds with fix

---

### User Story 2 - Intelligent Workflow Navigation (Priority: P2)

A developer wants a single entry point to interact with spec-kit that understands their current context and routes them to the right command, eliminating the need to memorize which `/speckit.*` command to use next.

**Why this priority**: Reduces cognitive load and improves developer experience, making spec-kit more accessible. Builds on P1 foundation.

**Independent Test**: Developer can run `/go` with various intents (feature request, status query, continuation) and receive contextually appropriate routing without manual command selection.

**Acceptance Scenarios**:

1. **Given** developer has completed `/speckit.specify` and `/speckit.plan`, **When** they run `/go`, **Then** system recognizes the next logical step is `/speckit.tasks` and executes it with appropriate context
2. **Given** developer types `/go what's my current status`, **When** executed, **Then** system provides a comprehensive report showing current branch, completion progress, pending tasks, and next recommended action
3. **Given** developer wants to add a new feature, **When** they run `/go implement user profile editing`, **Then** system classifies it as a feature request, analyzes scope (medium), and initiates `/speckit.specify` workflow
4. **Given** developer says `/go continue`, **When** executed on a branch with partial implementation, **Then** system resumes from the last incomplete task in tasks.md

---

### User Story 3 - Persistent Project Awareness (Priority: P3)

A developer wants continuous monitoring of their project structure to catch drift, ensure constitution compliance, and maintain alignment between specs and implementation without manual checks.

**Why this priority**: Provides safety net and observability. Depends on P1/P2 working first, enhances quality but isn't blocking for core agile workflows.

**Independent Test**: Supervisor process runs in background, detects when developer creates a file not in tasks.md, and surfaces an observation that `/go` can present to the user.

**Acceptance Scenarios**:

1. **Given** supervisor is running and monitoring project, **When** developer creates a new file `src/auth/oauth.py` not mentioned in any task, **Then** supervisor records a "drift" observation that appears in next `/go` status check
2. **Given** supervisor has detected multiple observations, **When** developer runs `/go`, **Then** system shows recent warnings/info from supervisor before proceeding with user's intent
3. **Given** developer hasn't used spec-kit in a while (supervisor stopped), **When** they run any `/speckit.*` command, **Then** supervisor automatically respawns and begins monitoring without user intervention
4. **Given** supervisor detects a file change that violates constitution principles, **When** `/go` is executed, **Then** system surfaces a warning from supervisor and asks for confirmation before proceeding

---

### User Story 4 - Major Pivot Support (Priority: P4)

A developer realizes midway through a spec that they need to make a fundamental architectural change (e.g., switching from SQL to NoSQL). They need guidance on how to restructure without losing work.

**Why this priority**: Less frequent but high-impact scenario. Requires P1-P3 infrastructure to work effectively.

**Independent Test**: Developer can run `/go we need to pivot to microservices architecture` and receive a guided migration plan with options to archive current work and start fresh spec branch.

**Acceptance Scenarios**:

1. **Given** developer is on branch `003-data-layer` with SQL-based plan, **When** they run `/go need to completely change to NoSQL`, **Then** system recognizes pivot intent, offers to archive current plan, and proposes creating migration strategy document before new spec
2. **Given** developer has significant progress on current spec, **When** pivot is detected, **Then** system warns about work loss, offers to create a comparison document, and provides rollback options
3. **Given** pivot requires breaking constitution principles, **When** detected by `/go`, **Then** system escalates the issue and recommends updating constitution first

---

### Edge Cases

- What happens when supervisor process crashes or becomes unresponsive?
  - Heartbeat detection mechanism identifies stale supervisor within 60 seconds
  - Next `/speckit.*` command or `/go` call auto-respawns supervisor
  - No user intervention required, process is self-healing

- How does system handle multiple terminal sessions on same project?
  - Single supervisor serves all sessions via shared state files
  - Lock file (`.speckit/session.lock`) prevents concurrent writes
  - `/go` detects concurrent sessions and warns user before destructive operations

- What if `/go` misclassifies user intent?
  - System presents its classification and routing decision before execution
  - User can abort and manually use specific `/speckit.*` command
  - Feedback mechanism allows correction (future: ML improvement)

- How does supervisor handle very large projects (1000+ files)?
  - Supervisor uses incremental scanning, focusing on recently changed files
  - Full scan runs every 5 minutes, delta scan every 30 seconds
  - Configurable scan intervals via `.speckit/supervisor/config.json`

- What happens when user is offline (no git)?
  - Supervisor falls back to directory-based feature detection
  - Uses `SPECIFY_FEATURE` environment variable if set
  - `/go` continues to function with reduced git-based context

- How does `/go` handle ambiguous scope (could be small or large)?
  - System errs on side of asking user: "This could be X or Y, which workflow?"
  - Provides clear explanation of tradeoffs for each option
  - Remembers user's past choices for similar patterns (stored in supervisor state)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a `/go` command that accepts natural language input describing bugs, features, status queries, or workflow continuations
- **FR-002**: `/go` command MUST analyze current project context including git branch, feature directory state, existing specs/plans/tasks, and supervisor observations before taking action
- **FR-003**: `/go` command MUST classify user intent into one of: bug fix, feature request, refinement, pivot/restructure, status query, or continuation
- **FR-004**: `/go` command MUST estimate scope complexity as trivial, small, medium, large, or pivot based on file count and architectural impact heuristics
- **FR-005**: `/go` command MUST route to appropriate `/speckit.*` commands based on intent and scope, minimizing ceremony for simple changes
- **FR-006**: System MUST run a persistent supervisor subprocess that monitors project state and maintains synchronization with git changes
- **FR-007**: Supervisor MUST run read-only operations only - all writes must be performed by the main agent session
- **FR-008**: Supervisor MUST maintain heartbeat file updated every 30 seconds to prove liveness
- **FR-009**: Supervisor MUST detect and record observations including: drift (files without tasks), constitution violations, structural inconsistencies
- **FR-010**: All existing `/speckit.*` commands MUST automatically spawn supervisor if not running, ensuring it's always available
- **FR-011**: Supervisor MUST communicate via file-based messaging using inbox/outbox directories under `.speckit/supervisor/`
- **FR-012**: `/go` command MUST consult supervisor state and recent observations before executing routing decisions
- **FR-013**: System MUST support lightweight bug fixes by adding tasks to existing tasks.md without requiring new specs for trivial/small scope issues
- **FR-014**: System MUST detect pivot scenarios and guide users through archiving current work and creating migration plans
- **FR-015**: Supervisor MUST track git HEAD, current branch, constitution hash, and last scan timestamp in state.json
- **FR-016**: System MUST provide self-healing for supervisor - auto-respawn if heartbeat exceeds 60 seconds old
- **FR-017**: `/go` status queries MUST generate reports showing current progress, pending tasks, supervisor observations, and recommended next actions
- **FR-018**: System MUST prevent concurrent write operations via lock file mechanism (`.speckit/session.lock`)
- **FR-019**: Supervisor MUST support graceful shutdown via signal handling (SIGTERM, SIGINT)
- **FR-020**: `/go` command MUST display its classification and routing decision before execution, allowing user abort

### Key Entities

- **Supervisor Process**: Background daemon that monitors project state, records observations, processes queries, and maintains synchronization with git. Key attributes: PID, heartbeat timestamp, current branch, git HEAD, observations list, inbox/outbox message queues.

- **Go Command**: Intelligent router that analyzes context, classifies intent, estimates scope, and executes appropriate workflow. Key attributes: user input, parsed intent, scope estimate, routing decision, supervisor query results.

- **Supervisor State**: Persistent JSON representation of supervisor's knowledge. Key attributes: supervisor metadata (PID, timestamps), project context (branch, git HEAD, constitution hash), observations array, processed message IDs.

- **Observation**: Supervisor-detected anomaly or information. Key attributes: type (drift/warning/info/error), severity, message, affected file/component, timestamp, resolution status.

- **Go Intent**: Classified user intention from `/go` input. Key attributes: intent type (bug/feature/refine/pivot/status/continue), confidence score, extracted entities (file names, component names), original input text.

- **Scope Estimate**: Complexity assessment for requested change. Key attributes: scope level (trivial/small/medium/large/pivot), affected file count estimate, architectural impact flag, confidence score, reasoning.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Developers can fix simple bugs discovered during feature work in under 2 minutes from discovery to task creation (measured: no spec overhead for trivial/small bugs)
- **SC-002**: `/go` correctly classifies user intent with 90%+ accuracy across bug/feature/status/continuation categories (measured via user feedback and command execution success)
- **SC-003**: Supervisor maintains 99.9% uptime during active development sessions (measured: heartbeat stays fresh, auto-respawn works)
- **SC-004**: Supervisor detects file drift within 60 seconds of file creation outside task scope (measured: timestamp difference between file creation and observation)
- **SC-005**: Developers reduce mental load by using `/go` as single entrypoint for 80%+ of their spec-kit interactions (measured: ratio of `/go` usage to direct `/speckit.*` command usage)
- **SC-006**: Pivot scenarios result in zero loss of prior work via automatic archiving (measured: all previous plan.md versions preserved with `_v{N}` suffix)
- **SC-007**: System handles multiple concurrent terminal sessions without data corruption (measured: lock file prevents race conditions, all sessions see consistent state)
- **SC-008**: `/go` status queries return actionable next-step recommendations in 100% of cases (measured: every status response includes "Recommended Next Action" section)
- **SC-009**: Supervisor observations surface in `/go` output within one interaction after being recorded (measured: observation timestamps vs. `/go` execution timestamps)
- **SC-010**: Developers can work offline (no git) with degraded but functional `/go` and supervisor capabilities (measured: fallback to directory-based detection works, no crashes)

## Assumptions

1. **Bash availability**: We assume bash 4.0+ is available for supervisor daemon implementation (spec-kit already requires bash for scripts)
2. **File system performance**: We assume file-based messaging (inbox/outbox) performs adequately for typical project sizes (<10,000 files)
3. **Single primary developer**: While multi-session is supported, we assume a single developer is the primary case (pair programming is secondary)
4. **Git as source of truth**: We assume git (when available) is the authoritative source for branch and feature context
5. **Constitution exists**: We assume developers using this feature have already established a constitution (though not strictly required)
6. **Terminal session duration**: We assume typical development sessions last 1-8 hours, so supervisor lifetime is session-bound
7. **Intent is expressible**: We assume developers can express their intent in brief natural language suitable for classification
8. **File paths are stable**: We assume file paths in tasks.md remain valid between task creation and execution (minimal refactoring mid-spec)
9. **Scope estimation tolerance**: We assume developers accept that scope estimation may occasionally be wrong and can manually override
10. **Observation non-blocking**: We assume supervisor observations are advisory - developers can proceed despite warnings

## Out of Scope

This specification explicitly excludes:

- **Machine learning for intent classification**: Initial version uses rule-based heuristics, ML may be added later
- **Multi-user collaboration**: Concurrent editing by multiple developers with conflict resolution is not supported
- **Cloud synchronization**: Supervisor state is local-only, no cloud backup or sharing across machines
- **IDE integration**: No VSCode/JetBrains plugins, remains CLI-only
- **Rollback/undo**: While pivot scenarios preserve old work, general undo of `/go` actions is not implemented
- **Natural language generation for specs**: `/go` routes to commands but doesn't auto-write specs from prompts
- **Performance optimization**: No caching, indexing, or incremental parsing beyond basic supervisor scanning
- **Webhook/notification integration**: No Slack/email/GitHub notifications from supervisor
- **Custom intent types**: Intent categories are fixed (bug/feature/refine/pivot/status/continue), no user-defined intents
- **Supervisor UI**: No web dashboard or TUI for supervisor monitoring, file-based inspection only

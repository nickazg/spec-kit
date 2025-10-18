# Tasks: Agile-Friendly Go Command & Persistent Supervisor

**Input**: Design documents from `/specs/001-agile-go-supervisor/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: No tests requested in spec - implementation only

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create supervisor runtime directory structure and prepare bash environment

- [X] T001 Create `.speckit/supervisor/` directory structure with subdirectories: inbox/, outbox/, observations/
- [X] T002 [P] Add `.speckit/supervisor/` to `.gitignore` to prevent committing runtime state
- [X] T003 [P] Create `.speckit/session.lock` directory pattern in scripts/bash/common.sh

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core supervisor infrastructure that MUST be complete before /go or user story features

**� CRITICAL**: No user story work can begin until this phase is complete

- [X] T004 Implement `ensure_supervisor_running()` function in scripts/bash/common.sh
- [X] T005 Implement `is_supervisor_healthy()` function in scripts/bash/common.sh (checks PID + heartbeat)
- [X] T006 Implement `query_supervisor()` function in scripts/bash/common.sh (inbox/outbox messaging)
- [X] T007 Create `scripts/bash/supervisor-daemon.sh` with main monitoring loop and heartbeat mechanism
- [X] T008 Add signal handling (SIGTERM/SIGINT) to supervisor-daemon.sh for graceful shutdown
- [X] T009 Implement git monitoring in supervisor-daemon.sh (git rev-parse HEAD, git diff tracking)
- [X] T010 Implement supervisor state persistence in supervisor-daemon.sh (write state.json atomically)
- [X] T011 Integrate `ensure_supervisor_running()` calls into scripts/bash/check-prerequisites.sh
- [X] T012 [P] Integrate `ensure_supervisor_running()` calls into scripts/bash/setup-plan.sh
- [X] T013 [P] Integrate `ensure_supervisor_running()` calls into scripts/bash/create-new-feature.sh

**Checkpoint**: Supervisor auto-spawns on any spec-kit command, heartbeat working, state persists

---

## Phase 3: User Story 1 - Quick Bug Fix During Development (Priority: P1) <� MVP

**Goal**: Enable `/go` to classify bug fix intents, estimate scope, and add tasks to existing tasks.md without heavy spec ceremony

**Independent Test**: Developer runs `/go found bug in auth validation`, system classifies as bug fix, determines scope (small), adds high-priority task to tasks.md

### Implementation for User Story 1

- [X] T014 [US1] Create `templates/commands/go.md` slash command template with Phase 1-6 outline from plan
- [X] T015 [US1] Create `scripts/bash/go-router.sh` with intent classification functions (classify_intent, estimate_scope)
- [X] T016 [US1] Implement bug fix intent detection in go-router.sh (keywords: bug, fix, broken, error)
- [X] T017 [US1] Implement scope estimation heuristics in go-router.sh (trivial/small/medium/large/pivot)
- [X] T018 [US1] Implement task injection logic in go-router.sh (append to existing tasks.md with P0 marker)
- [X] T019 [US1] Add context gathering phase to templates/commands/go.md (read git status, feature state, supervisor observations)
- [X] T020 [US1] Add routing decision tree to templates/commands/go.md for bug fix scenarios
- [X] T021 [US1] Implement decision display before execution in templates/commands/go.md (show classification + allow abort)

**Checkpoint**: `/go` can handle bug fixes - detects intent, estimates scope, adds tasks to tasks.md

---

## Phase 4: User Story 2 - Intelligent Workflow Navigation (Priority: P2)

**Goal**: `/go` understands workflow context and routes to appropriate `/speckit.*` commands for status queries, feature requests, and continuation

**Independent Test**: Developer runs `/go`, `/go status`, `/go implement feature X` and receives correct routing decisions

### Implementation for User Story 2

- [X] T022 [US2] Implement status query intent detection in go-router.sh (patterns: what/where/show/status)
- [X] T023 [US2] Implement continuation intent detection in go-router.sh (empty input or continue/proceed/next)
- [X] T024 [US2] Implement feature request intent detection in go-router.sh (keywords: implement, add, create, build)
- [X] T025 [US2] Implement status report generation in go-router.sh (current branch, progress, pending tasks, observations)
- [X] T026 [US2] Implement workflow state detection in go-router.sh (determine next logical command based on file existence)
- [X] T027 [US2] Add feature request routing to templates/commands/go.md (call /speckit.specify for medium+ scope)
- [X] T028 [US2] Add status query routing to templates/commands/go.md (generate and display report)
- [X] T029 [US2] Add continuation routing to templates/commands/go.md (resume from last incomplete task)

**Checkpoint**: `/go` handles status queries, feature requests, and continuation - full workflow navigation working

---

## Phase 5: User Story 3 - Persistent Project Awareness (Priority: P3)

**Goal**: Supervisor detects file drift, constitution violations, and surfaces observations through `/go`

**Independent Test**: Developer creates file outside task scope, supervisor records drift observation within 60s, `/go` displays it

### Implementation for User Story 3

- [X] T030 [US3] Implement file drift detection in supervisor-daemon.sh (compare git-tracked files against tasks.md)
- [X] T031 [US3] Implement constitution hash tracking in supervisor-daemon.sh (detect constitution.md changes)
- [X] T032 [US3] Implement observation recording in supervisor-daemon.sh (append to observations array in state.json)
- [X] T033 [US3] Implement observation severity classification in supervisor-daemon.sh (info/warning/error/critical)
- [X] T034 [US3] Implement incremental vs full scan logic in supervisor-daemon.sh (delta every 30s, full every 5min)
- [X] T035 [US3] Create default config.json for supervisor in scripts/bash/supervisor-daemon.sh (scan intervals)
- [X] T036 [US3] Implement observation retrieval in go-router.sh (read latest.json from observations/)
- [X] T037 [US3] Add observation display to templates/commands/go.md (show warnings before proceeding with user intent)
- [X] T038 [US3] Implement constitution compliance checking in supervisor-daemon.sh (detect violations, record observations)

**Checkpoint**: Supervisor monitors project, detects drift/violations, `/go` surfaces observations to user

---

## Phase 6: User Story 4 - Major Pivot Support (Priority: P4)

**Goal**: `/go` detects pivot scenarios and guides users through archiving current work and creating migration plans

**Independent Test**: Developer runs `/go we need to change to NoSQL`, system recognizes pivot intent, offers archiving and migration workflow

### Implementation for User Story 4

- [X] T039 [US4] Implement pivot intent detection in go-router.sh (keywords: pivot, restructure, refactor, major change)
- [X] T040 [US4] Implement plan archiving logic in go-router.sh (copy plan.md to plan_v1.md with timestamp)
- [X] T041 [US4] Implement migration strategy creation in go-router.sh (create migration.md document)
- [X] T042 [US4] Add pivot detection to templates/commands/go.md routing decision tree
- [X] T043 [US4] Add pivot workflow guidance to templates/commands/go.md (warn about work loss, offer options)
- [X] T044 [US4] Implement constitution conflict detection for pivots in go-router.sh (check if pivot violates principles)

**Checkpoint**: `/go` handles pivot scenarios - archives work, creates migration plans, preserves history

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories and overall system quality

- [X] T045 [P] Add lock file acquisition to templates/commands/go.md (prevent concurrent writes)
- [X] T046 [P] Add cross-platform compatibility detection to scripts/bash/common.sh (macOS vs Linux stat commands)
- [X] T047 [P] Add JSON parsing fallback to go-router.sh (jq preferred, grep/sed fallback if unavailable)
- [X] T048 Implement inbox message processing loop in supervisor-daemon.sh (handle queries from /go)
- [X] T049 Implement outbox response writing in supervisor-daemon.sh (respond to queries)
- [X] T050 [P] Add refinement intent detection to go-router.sh (keywords: update, modify, change, clarify)
- [X] T051 Add error handling for misclassification to templates/commands/go.md (fallback instructions)
- [X] T052 Add supervisor health check command to templates/commands/go.md (`/go supervisor status`)
- [X] T053 [P] Create default .speckit/supervisor/config.json on first supervisor spawn
- [X] T054 Add verbose mode to supervisor-daemon.sh (optional debug logging to .speckit/supervisor/debug.log)
- [X] T055 Update README.md with `/go` command documentation and usage examples
- [X] T056 Create quickstart.md examples for all `/go` scenarios (bug/feature/status/pivot/continue)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-6)**: All depend on Foundational phase completion
  - US1 (P1) must complete before US2 (P2) for stable /go foundation
  - US2 (P2) must complete before US3 (P3) for observation display
  - US3 (P3) must complete before US4 (P4) for constitution checking
- **Polish (Phase 7)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Foundation for all /go functionality - must complete first
- **User Story 2 (P2)**: Builds on US1 intent classification - depends on T014-T021
- **User Story 3 (P3)**: Requires US2 for observation display - depends on T022-T029
- **User Story 4 (P4)**: Requires US3 for constitution checking - depends on T030-T038

### Within Each User Story

- Templates before scripts (go.md before go-router.sh usage)
- Core functions before integration (classify_intent before routing)
- Detection before action (intent classification before task injection)

### Parallel Opportunities

- Setup tasks T002 and T003 can run in parallel
- Foundational tasks T012 and T013 can run in parallel (different files)
- Polish tasks T045, T046, T047, T050, T053, T054, T055, T056 can run in parallel (independent files)
- Documentation tasks can run while implementation is being tested

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup � Directory structure ready
2. Complete Phase 2: Foundational � Supervisor auto-spawns and monitors
3. Complete Phase 3: User Story 1 � `/go` handles bug fixes
4. **STOP and VALIDATE**: Test bug fix workflow independently
5. Deploy/merge if ready - developers can now use `/go` for rapid bug fixes

### Incremental Delivery

1. Complete Setup + Foundational � Supervisor infrastructure ready
2. Add User Story 1 � Test bug fixes � Deploy (MVP!)
3. Add User Story 2 � Test workflow navigation � Deploy
4. Add User Story 3 � Test drift detection � Deploy
5. Add User Story 4 � Test pivot scenarios � Deploy
6. Each story adds value without breaking previous stories

### Sequential Strategy (Recommended)

1. Team completes Setup + Foundational together
2. Implement US1 (P1) completely - establishes /go command foundation
3. Implement US2 (P2) completely - adds full routing capabilities
4. Implement US3 (P3) completely - activates supervisor monitoring
5. Implement US4 (P4) completely - handles pivot scenarios
6. Complete Polish phase - production-ready

---

## Notes

- [P] tasks = different files, no dependencies, can run in parallel
- [Story] label maps task to specific user story for traceability
- Each user story builds on previous stories (P1 � P2 � P3 � P4)
- No tests requested - validate manually after each user story checkpoint
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Supervisor must be working before /go can query it
- /go command must exist before it can route to other commands

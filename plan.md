# Plan: Bake feature-plan / feature-implement / feature-test Intent into GSD

## 1. Implementation Plan

1. **Enhance discuss-phase with feature-plan's structured requirements gathering** — Add explicit "confirm basics" gate and context-sensitive questioning
2. **Add ASCII flow diagram generation to plan-phase** — Planner agent produces data/system flow diagrams in PLAN.md files
3. **Enrich PLAN.md template with feature-plan's step structure** — Each plan gets scope, approach, validation, tests, and anti-compaction summary sections
4. **Add quality checklist enforcement to gsd-plan-checker** — Verify feature-plan's quality gates (flow diagram, file paths, validation commands, independent testability)
5. **Enhance execute-phase with scope-discipline and hard-stop rules** — Bake Claude-specific guardrails into gsd-executor agent instructions *(parallelizable with 4)*
6. **Add automated smoke testing stage to verify-work** — New step before UAT: run endpoint/API/DB tests like feature-test *(parallelizable with 7)*
7. **Add smoke matrix generation to plan-phase** — Final plan file in each phase is a testing plan with smoke matrix, negative cases, DB verification *(parallelizable with 6)*

## 2. Requirements (confirmed by user)

- **Feature name**: gsd-skill-integration
- **Problem**: Three useful skill behaviors (feature-plan, feature-implement, feature-test) exist as standalone commands but their intent/discipline is not embedded in GSD's workflow, causing inconsistency when users switch between the two approaches
- **Scope**: Merge the *intent and behavior patterns* from the three skills into GSD's existing workflow — NOT add the skills as separate GSD commands
- **Constraints**: Must not break existing GSD workflow or command structure; changes should enhance existing agents/workflows/templates rather than adding new top-level commands

## 3. Design

### What GSD already covers (equivalents exist)

| feature-* skill | GSD equivalent | Gap |
|-----------------|----------------|-----|
| feature-plan Phase 1 (gather requirements) | discuss-phase | discuss-phase focuses on gray areas, not explicit requirement confirmation |
| feature-plan Phase 2 (design) | gsd-phase-researcher + gsd-planner | Planner doesn't produce ASCII flow diagrams or mark parallelizable steps as explicitly |
| feature-plan Phase 3 (write plan) | plan-phase → PLAN.md | PLAN.md uses XML task format; lacks per-step scope/approach/summary sections |
| feature-implement (execute steps) | execute-phase → gsd-executor | **Fully equivalent and more sophisticated** — wave parallelism, checkpoints, atomic commits, deviation handling |
| feature-implement (progress.md) | STATE.md + SUMMARY.md | **Fully equivalent** |
| feature-implement (hard stops) | Checkpoint protocol | Similar but not identical wording |
| feature-test (smoke matrix) | verify-work (UAT) | UAT is manual/conversational; no automated smoke/endpoint testing stage |
| feature-test (DB verification) | gsd-verifier | Verifier checks goal achievement, not DB state |
| feature-test (testing report) | UAT.md + VERIFICATION.md | Different formats, but same intent |

### What's genuinely missing

1. **Explicit requirement confirmation gate** — discuss-phase jumps to gray areas without confirming problem/scope/constraints first
2. **ASCII data flow diagrams** — Plans lack visual system flow; feature-plan requires these in `00-overview.md`
3. **Per-step anti-compaction summaries** — feature-plan's step files have a "Summary" paragraph specifically designed so an agent reading only that summary can continue. GSD's PLAN.md tasks don't have this
4. **Quality checklist enforcement** — feature-plan has a strict checklist before finishing. gsd-plan-checker has dimensions but doesn't check for flow diagrams, independent testability, or validation commands per task
5. **Scope discipline guardrails** — Claude doesn't overthink before coding, but it does tend to over-engineer, gold-plate, and silently deviate from plans. These failure modes aren't codified in gsd-executor
6. **Automated smoke testing** — verify-work goes straight to manual UAT. No curl/API/DB automated testing stage
7. **Smoke matrix in plans** — feature-plan requires a testing file (`0n-testing.md`) as the last step. GSD plans don't include a testing plan

### What we should NOT port

- **`plans/` directory structure** — GSD uses `.planning/phases/` which is more organized
- **progress.md format** — GSD's STATE.md + SUMMARY.md is superior (richer state tracking)
- **TaskCreate/TaskUpdate queue** — GSD's wave-based system with frontmatter is more robust than the Task API approach
- **feature-test's DB safety rules for MCP** — Too specific to one stack; GSD is stack-agnostic

## 4. Data/System Flow

```
User runs /gsd:discuss-phase
  → [NEW] Confirm basics gate (problem, scope, constraints)
  → Gray area identification (existing)
  → Discussion loop (existing)
  → CONTEXT.md written (existing)

User runs /gsd:plan-phase
  → Research (existing)
  → Planner creates PLAN.md files (existing)
    → [NEW] Each plan includes data flow diagram
    → [NEW] Each task includes anti-compaction summary
    → [NEW] Last plan is a smoke test plan
  → Plan checker verifies (existing)
    → [NEW] Quality checklist includes flow diagram, testability, summaries
  → Done

User runs /gsd:execute-phase
  → Wave-based execution (existing)
    → [NEW] Scope discipline rules (no gold-plating, no silent deviation)
    → [NEW] Hard-stop rules codified
  → SUMMARY.md per plan (existing)
  → Verification (existing)

User runs /gsd:verify-work
  → [NEW] Automated smoke testing stage (before UAT)
    → Run smoke matrix from test plan
    → Execute endpoint tests
    → Verify DB state (if applicable)
    → Write automated test results
  → Manual UAT (existing)
  → Diagnose issues (existing)
  → Gap closure (existing)
```

## 5. Key Files to Modify

| File | Change |
|------|--------|
| `get-shit-done/workflows/discuss-phase.md` | Add "confirm basics" step before gray area identification |
| `get-shit-done/agents/gsd-planner.md` | Add instructions for ASCII flow diagrams and anti-compaction summaries |
| `get-shit-done/templates/phase-prompt.md` | Add data flow diagram section, per-task summary field, smoke test plan template |
| `get-shit-done/agents/gsd-plan-checker.md` | Add quality checklist dimensions for flow diagram, testability, summaries |
| `get-shit-done/agents/gsd-executor.md` | Add scope-discipline and hard-stop rules |
| `get-shit-done/workflows/verify-work.md` | Add automated smoke testing step before UAT |
| `get-shit-done/workflows/plan-phase.md` | Minor: ensure smoke test plan is generated as last plan |
| `get-shit-done/references/verification-patterns.md` | Add smoke test patterns |

## 6. Out of Scope

- Adding `/feature-plan`, `/feature-implement`, `/feature-test` as separate GSD commands
- Changing GSD's directory structure (`.planning/phases/`)
- Changing GSD's state management (STATE.md, SUMMARY.md)
- Adding MCP-specific DB verification (GSD is stack-agnostic)
- Modifying the CLI tools (`gsd-tools.cjs`) or test suite
- Changing the wave-based execution model

---

## Step-by-Step Implementation

### Step 1: Enhance discuss-phase with requirement confirmation gate

**Scope:** Add a "confirm basics" step to `discuss-phase.md` that runs before gray area identification, mirroring feature-plan's Phase 1a.

**Approach:** Insert a new step `<step name="confirm_basics">` between `load_prior_context` and `scout_codebase`. This step uses `AskUserQuestion` to confirm: (1) what problem does this phase solve, (2) what's in vs out of scope beyond the roadmap description, (3) any hard constraints. If the user says "the roadmap covers it" or equivalent, skip — this is a gate, not a blocker.

**Files to modify:**
- `get-shit-done/workflows/discuss-phase.md` — Add new step

**Validation:** Run `/gsd:discuss-phase` on a test phase and verify the basics confirmation appears before gray areas.

**Tests:** Existing discuss-phase flow should still work. The new step should be skippable.

**Summary:** Adds explicit requirement confirmation to discuss-phase so that downstream agents receive clearer problem/scope/constraint context, matching feature-plan's "confirm basics (always ask)" pattern. The step is lightweight and skippable to avoid friction for phases where the roadmap description is sufficient.

---

### Step 2: Add ASCII flow diagram and anti-compaction summaries to planner

**Scope:** Modify the gsd-planner agent instructions and the PLAN.md template to include (a) a data/system flow diagram in each plan's overview section, and (b) a `<summary>` field on each task.

**Approach:**

For the flow diagram: Add to the planner agent's instructions that each PLAN.md must include a `## Data Flow` section after the objective, showing an ASCII diagram of inputs → processing → outputs. This mirrors feature-plan's requirement for `00-overview.md` to have an ASCII flow.

For anti-compaction summaries: Add a `<summary>` element to each `<task>` in the XML format. This is a 2-3 sentence paragraph that captures what was done and critical context, specifically designed so an agent reading only this summary can continue work. This mirrors feature-plan's per-step summary requirement.

**Files to modify:**
- `get-shit-done/agents/gsd-planner.md` — Add flow diagram and summary instructions
- `get-shit-done/templates/phase-prompt.md` — Add `## Data Flow` section and `<summary>` element to task XML

**Parallel note:** Can run concurrently with Step 3.

**Validation:** Generate a plan for a test phase and verify it contains a flow diagram and per-task summaries.

**Tests:** Existing plan generation should still work. New sections are additive.

**Summary:** Enriches PLAN.md with visual flow diagrams (reducing cognitive load for executors) and anti-compaction summaries (ensuring context survives session boundaries). These are the two most impactful patterns from feature-plan that GSD's plans currently lack.

---

### Step 3: Add quality checklist enforcement to plan checker

**Scope:** Extend gsd-plan-checker's verification dimensions to include feature-plan's quality checklist items.

**Approach:** Add new verification dimensions to the checker:
- **Flow diagram exists** — Each plan has a `## Data Flow` section with an ASCII diagram
- **Validation commands per task** — Each `<task>` has a `<verify>` element with a concrete command
- **Independent testability** — No task depends on "finishing the whole thing" to be verified
- **Anti-compaction summaries** — Each task has a `<summary>` element
- **File paths explicit** — Each task has a `<files>` element with concrete paths

These map directly to feature-plan's quality checklist.

**Files to modify:**
- `get-shit-done/agents/gsd-plan-checker.md` — Add new verification dimensions

**Parallel note:** Can run concurrently with Step 2.

**Validation:** Run plan-checker on a plan missing flow diagrams and verify it flags the issue.

**Tests:** Existing checker dimensions should still pass. New dimensions are additive.

**Summary:** Closes the feedback loop on Steps 1-2 by ensuring the planner's new outputs are verified. Without this, the flow diagram and summary additions would be best-effort rather than enforced.

---

### Step 4: Add scope-discipline and hard-stop rules to executor

**Scope:** Codify Claude-specific guardrails and hard-stop conditions in the gsd-executor agent.

**Approach:** Add to gsd-executor's agent instructions:

**Scope discipline (Claude-specific):** Claude's actual failure modes during execution are not overthinking — it's the opposite. Claude tends to:
- **Gold-plate**: Add error handling, type annotations, comments, or "improvements" beyond what the task specifies
- **Silently deviate**: "Improve" the plan's approach without flagging it as a deviation. A better implementation is still a deviation if the plan said something different
- **Scope creep across tasks**: Start work from a future task while executing the current one because it "makes sense while we're here"
- **Over-abstract**: Create helpers, utilities, or abstractions for one-time operations

The guardrail: "Implement exactly what the task says. If you see a better approach, log it as a deviation in SUMMARY.md — do not silently adopt it. One task = one logical patch. Three similar lines of code is better than a premature abstraction."

**Hard-stop rules (explicit codification):**
- A task cannot be validated with any available command → STOP, report in SUMMARY.md
- A requirement blocks safe implementation → STOP, report
- A decision requires user input not captured in CONTEXT.md → STOP, report
- The plan is wrong or incomplete → STOP, do not silently deviate

GSD already has checkpoint protocol and deviation rules, but these are at the plan level. The hard-stop rules here are at the task level within the executor.

**Files to modify:**
- `get-shit-done/agents/gsd-executor.md` — Add scope-discipline and hard-stop sections

**Parallel note:** Can run concurrently with Steps 2 and 3.

**Validation:** Review executor behavior on a task that requires user input — should stop rather than guess. Review that executor doesn't add unrequested error handling or abstractions.

**Tests:** Existing execution flow should be unaffected. Rules are guardrails, not changes to execution logic.

**Summary:** Brings the right guardrails for Claude Opus 4.6 into GSD's executor. Unlike GPT models which need anti-stall prompting, Claude's failure mode is doing *too much* — over-engineering, gold-plating, and silently deviating from plans. The hard-stops prevent silent deviation, and the scope discipline keeps each task surgical.

---

### Step 5: Add smoke test plan generation to plan-phase

**Scope:** Ensure the planner generates a testing/smoke plan as the last plan in each phase, mirroring feature-plan's `0n-testing.md` requirement.

**Approach:** Add to the planner's instructions that the final plan in a phase should be a smoke/validation plan with:
- Smoke test matrix (happy path, error cases, edge cases)
- Negative cases (auth failures, invalid inputs, bad state)
- Validation commands for each test
- Environment requirements (services, env vars, test data)

This plan would have `type: validation` in its frontmatter and be placed in the last wave (depends on all other plans). It's consumed by verify-work's automated testing stage (Step 6).

The smoke plan uses the same PLAN.md XML task format but tasks are test executions rather than implementations.

**Files to modify:**
- `get-shit-done/agents/gsd-planner.md` — Add smoke test plan generation instructions
- `get-shit-done/templates/phase-prompt.md` — Add `type: validation` example

**Parallel note:** Can run concurrently with Step 6.

**Validation:** Generate plans for a test phase and verify the last plan is a smoke test plan.

**Tests:** Existing plan generation should still work. Smoke plan is additive (new final plan).

**Summary:** Bridges the planning and testing stages by having the planner produce a concrete test plan that verify-work can execute automatically. This is feature-plan's most distinctive contribution — thinking about testing *during* planning, not after.

---

### Step 6: Add automated smoke testing to verify-work

**Scope:** Add an automated smoke testing stage to `verify-work.md` that runs before manual UAT, consuming the smoke test plan from Step 5.

**Approach:** Insert a new step `<step name="automated_smoke">` between `find_summaries` and `extract_tests` in verify-work. This step:

1. Looks for a `type: validation` plan in the phase directory
2. If found, reads the smoke test matrix
3. Executes each test (curl commands, script runs, build checks, etc.)
4. Records results in a structured format
5. Writes an automated test section to UAT.md before the manual tests
6. If any automated tests fail → flags them as known issues before UAT begins

This mirrors feature-test's execution steps (build matrix → execute → verify → report) but integrated into GSD's existing verify-work flow rather than as a separate command.

**Key difference from feature-test:** GSD is stack-agnostic, so we don't mandate PostgreSQL MCP verification. Instead, the smoke plan specifies whatever verification is appropriate (could be DB queries, API calls, file checks, etc.) and the automated step executes whatever the plan says.

**Files to modify:**
- `get-shit-done/workflows/verify-work.md` — Add automated smoke step

**Parallel note:** Can run concurrently with Step 5.

**Validation:** Run verify-work on a phase that has a smoke test plan and verify automated tests execute before UAT.

**Tests:** Phases without smoke test plans should skip the automated stage and go straight to UAT (backward compatible).

**Summary:** Fills the biggest gap between GSD and feature-test: automated testing before manual UAT. This catches obvious regressions before the user spends time on manual testing, significantly improving the feedback loop efficiency.

---

### Step 7: Update references and documentation

**Scope:** Update verification-patterns.md with smoke test patterns, and ensure all new behaviors are documented in reference materials.

**Approach:**
- Add smoke test patterns to `get-shit-done/references/verification-patterns.md`
- Add scope-discipline reference to `get-shit-done/references/checkpoints.md` (or create a lightweight execution-rules.md)
- Update the phase-prompt template's example to show the new fields

**Files to modify:**
- `get-shit-done/references/verification-patterns.md` — Add smoke test patterns
- `get-shit-done/templates/phase-prompt.md` — Update example to show flow diagram, summaries, smoke plan

**Validation:** Read reference files and verify new patterns are documented.

**Summary:** Ensures the new behaviors are discoverable and documented for users who read GSD's reference materials.

---

## Testing Plan

### Smoke test matrix

| # | Case | What to verify | Expected |
|---|------|----------------|----------|
| 1 | discuss-phase basics gate | Run `/gsd:discuss-phase` on a phase | Basics confirmation appears before gray areas |
| 2 | Basics gate skip | Say "roadmap covers it" at basics gate | Proceeds to gray areas without blocking |
| 3 | Plan flow diagram | Run `/gsd:plan-phase` on a phase | PLAN.md contains `## Data Flow` with ASCII diagram |
| 4 | Plan task summaries | Run `/gsd:plan-phase` on a phase | Each `<task>` has a `<summary>` element |
| 5 | Smoke test plan | Run `/gsd:plan-phase` on a phase | Last plan has `type: validation` frontmatter |
| 6 | Plan checker enforcement | Submit a plan without flow diagram | Checker flags missing flow diagram |
| 7 | Executor scope discipline | Execute a plan with simple tasks | No gold-plating, no unrequested abstractions, deviations logged |
| 8 | Automated smoke in verify | Run `/gsd:verify-work` on phase with smoke plan | Automated tests run before UAT |
| 9 | No smoke plan fallback | Run `/gsd:verify-work` on phase without smoke plan | Goes straight to UAT (backward compat) |
| 10 | Full pipeline | Run discuss → plan → execute → verify | All new behaviors present throughout |

### Negative cases

- discuss-phase without roadmap → existing error handling should still work
- Plan checker on pre-existing plans (no flow diagram) → should flag but not block existing workflows
- verify-work on phase with no SUMMARY.md → existing error handling unchanged

### Validation commands

```bash
# Run existing test suite to verify no regressions
npm test

# Manual: run discuss-phase and verify basics gate
# Manual: run plan-phase and verify new plan sections
# Manual: run verify-work and verify automated smoke stage
```

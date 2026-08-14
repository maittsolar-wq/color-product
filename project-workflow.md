# AI-First Product Development Workflow

**Document ID:** WF-PRODUCT-001  
**Version:** 1.0  
**Status:** Active  
**Purpose:** Master execution guide for running the same product workflow across different ChatGPT/Claude/Codex conversations.

---

## 1. Core Rule

A new AI chat must **never rely on the phrase “Continue Step X” alone** unless the prior project context is already available.

In a fresh chat, always provide:
1. This `project-workflow.md`.
2. All approved artifacts from previous steps.
3. Any new confirmed decisions from boss/user.

The AI must read prior artifacts before executing the requested step.

---

## 2. Source of Truth Order

When information conflicts, use this priority:

1. Latest explicit boss/user decision.
2. Approved project artifact from the latest relevant step.
3. Earlier project artifacts.
4. AI assumptions.
5. Competitor patterns.

AI assumptions must never override confirmed decisions.

---

## 3. Global AI Rules

For every step:

1. Read all required previous artifacts.
2. Do not ask again for information already present.
3. Preserve confirmed decisions.
4. Do not silently change prior decisions.
5. If information is missing:
   - continue with a reasonable assumption;
   - label it as ASSUMPTION;
   - list it under Open Questions / Product Decisions if material.
6. Generate only the artifact required by the current step.
7. Do not skip ahead.
8. Use stable IDs for traceability.
9. Keep output suitable for version control in Markdown/YAML/JSON.
10. At the end of every artifact, include:
    - AI Execution Instructions for that step;
    - Next Step Handoff;
    - Required inputs for the next step;
    - Required output filename.

---

# 4. STEP 1 — Product Brief

## Trigger
Boss gives:
- idea;
- rough request;
- app concept;
- high-level product objective.

## Minimum User Input
Example:

> Boss request: Build a casual coloring app for adults and children who want to color in their free time without needing art knowledge.

Optional:
- Platform
- Target market
- Deadline
- Team
- Monetization
- Reference app

## AI Role
Senior Product Manager + Senior Business Analyst.

## Required Output
`product-brief.md`

## Step 1 Must Produce
- Product Overview
- Vision
- Mission
- Problem Statement
- Target Audience
- User Needs
- JTBD
- Value Proposition
- Product Principles
- Core Experience
- High-level Flow
- Initial MVP Direction
- Out of Scope
- Monetization Direction
- Content Strategy
- UX Direction
- Business Objectives
- Metrics
- Risks
- Assumptions
- Confirmed vs Assumptions
- Open Questions
- Product Decisions
- Success Definition
- Positioning
- North Star

---

# 5. STEP 2 — Competitor Analysis

## Trigger
User says:
> Continue Step 2.

## Required Input
- `product-brief.md`
- Competitor/reference app if available.

## AI Role
Senior Product / Competitor Analyst + Senior Product Manager + BA.

## Required Output
`competitor-analysis.md`

## Step 2 Must Produce
- Competitor Snapshot
- Product Positioning
- Architecture
- Screens / Navigation
- Core User Flows
- Feature Breakdown
- Core Interaction / Editor
- Content Strategy
- Monetization
- Retention Mechanisms
- UX Patterns
- Strengths
- Weaknesses
- User complaints / opportunities
- What to learn
- What not to copy
- Competitor → Our Product mapping
- MVP benchmark
- Differentiation opportunities
- Product Decisions

---

# 6. STEP 3 — MVP Scope & Feature Prioritization

## Trigger
User says:
> Continue Step 3.

## Required Input
- `product-brief.md`
- `competitor-analysis.md`
- New boss decisions if any.

## AI Role
Senior Product Manager + Senior BA + Scope Owner.

## Required Output
`mvp-scope.md`

## Step 3 Must Produce
- MVP Goal
- Product Strategy
- Module Breakdown
- Feature IDs
- Must / Should / Could / Won't
- Content Scope
- Core Interaction Scope
- Monetization Scope
- Critical User Journeys
- Version 1.1
- Future Roadmap
- Product Decisions
- Scope Guardrails
- Definition of MVP Complete

---

# 7. STEP 4 — Information Architecture & User Flow

## Trigger
User says:
> Continue Step 4.

## Required Input
- `product-brief.md`
- `competitor-analysis.md`
- `mvp-scope.md`
- Latest confirmed decisions.

## AI Role
Senior Product Architect + Senior BA + UX Flow Designer.

## Required Output
`information-architecture-user-flow.md`

## Step 4 Must Produce

### A. Official Screen Inventory
Every screen gets a stable ID:

- `SCR-ENTRY-001`
- `SCR-HOME-001`
- `SCR-CATEGORY-001`
- `SCR-PREVIEW-001`
- `SCR-EDITOR-001`
- etc.

For each screen:
- Name
- Purpose
- Entry points
- Exit points
- Related module
- Related feature IDs

### B. Navigation Architecture
Define:
- Root navigation
- Tab navigation
- Push/modal navigation
- Back behavior
- Deep-link behavior if applicable

### C. Primary User Flows
Examples:
- First Coloring
- Browse Category
- Resume Coloring
- Complete Drawing

### D. Alternative / Exception Flows
Examples:
- Locked content
- Premium flow
- Ad unlock flow
- Empty state
- Error state
- Offline state
- Missing asset
- Purchase failure
- Restore purchase

### E. Traceability Mapping
Map:

`Module → Feature ID → Screen ID → Flow ID`

### F. Flow IDs
Examples:
- `FLOW-COLOR-001`
- `FLOW-RESUME-001`
- `FLOW-PREMIUM-001`

### Step 4 Must NOT Do
- Do not create final visual UI.
- Do not choose exact typography/colors.
- Do not write detailed database schema.
- Do not generate full test cases.
- Do not write implementation code.

---

# 8. STEP 5 — Requirement Catalog & Acceptance Criteria

## Trigger
User says:
> Continue Step 5.

## Required Input
All approved artifacts from Steps 1–4.

## AI Role
Senior Business Analyst.

## Required Output
`requirements.md`

## Must Produce
- Functional Requirements
- Business Rules
- Non-functional Requirements
- Requirement IDs
- Acceptance Criteria
- Preconditions
- Postconditions
- Edge cases
- Error behavior
- Traceability to Feature IDs / Screen IDs / Flow IDs

Recommended ID formats:
- `REQ-HOME-001`
- `REQ-EDITOR-001`
- `BR-MON-001`
- `NFR-PERF-001`

---

# 9. STEP 6 — UI Prototype / Design Specification

## Trigger
User says:
> Continue Step 6.

## Required Input
Artifacts from Steps 1–5.

## AI Role
Senior Product Designer / UX Designer.

## Required Output
One or both:
- HTML prototype folder
- `ui-spec.md`

## Must Produce
- Screen layout
- Component inventory
- Component IDs
- Interaction states
- Loading / empty / error states
- Responsive behavior
- UX copy
- Accessibility notes
- Traceability to Screen IDs / Requirement IDs

HTML should include identifiers such as:
- `data-screen-id`
- `data-component-id`
- `data-requirement`
- `data-testid`

---

# 10. STEP 7 — Detailed Functional / Data / API Specification

## Trigger
User says:
> Continue Step 7.

## Required Input
Approved Steps 1–6.

## AI Role
Senior BA + Solution Analyst.

## Required Outputs
Depending on project:
- `functional-spec.md`
- `data-model.md` or JSON schema
- `api-spec.md`
- asset/content schemas

Must preserve traceability.

---

# 11. STEP 8 — Test Strategy & Test Case Generation

## Trigger
User says:
> Continue Step 8.

## Required Input
Requirements, flows, specs, UI prototype.

## AI Role
QA Lead + Senior Tester.

## Required Outputs
- `test-strategy.md`
- `test-cases.md`
- automation candidate list

Must cover:
- Functional
- Negative
- Edge
- UI
- Content
- Performance
- Monetization
- Persistence
- Offline
- Regression

Test IDs:
- `TC-EDITOR-001`
- `TC-PREMIUM-001`

---

# 12. STEP 9 — Automation Test Generation

## Trigger
User says:
> Continue Step 9.

## Required Input
Approved test cases + application identifiers.

## AI Role
QA Automation Engineer.

## Required Output
Automation scripts, e.g.:
- Maestro YAML
- Playwright for HTML prototype
- API tests where applicable

Must map:
`TC ID → Automation file`

---

# 13. STEP 10 — Build QA / Bug Analysis

## Trigger
User provides APK/build + test evidence and says:
> Continue Step 10.

## Required Input
- Build/APK
- Requirements
- Test cases
- Automation results
- Logs
- Screenshots/videos where available

## AI Role
QA Lead + Product QA Analyst.

## Required Outputs
- `test-report.md`
- bug reports
- regression scope

Bug IDs:
- `BUG-EDITOR-001`

Each bug must map:
`BUG → TC → REQ → SCR/FLOW`

---

# 14. New Chat Usage

In a completely new conversation, do **not** only write:

> Continue Step 4.

Instead provide/upload:
- `project-workflow.md`
- `product-brief.md`
- `competitor-analysis.md`
- `mvp-scope.md`

Then write:

> Follow `project-workflow.md`. Read all uploaded approved artifacts and continue Step 4. Preserve all confirmed decisions. Do not ask again for information already present.

That is enough.

---

# 15. Change Management Rule

Whenever boss changes something:

Example:

> Boss update: Android only, US market, no login, Ads + Subscription.

AI must:
1. Record it as CONFIRMED.
2. Identify which existing artifacts are impacted.
3. Update the earliest relevant source-of-truth artifact first.
4. Propagate the impact forward.
5. Never silently overwrite unrelated decisions.

---

# 16. Artifact Naming Convention

Recommended structure:

```text
00-product/
  product-brief.md
  competitor-analysis.md
  mvp-scope.md

01-architecture/
  information-architecture-user-flow.md

02-requirements/
  requirements.md

03-design/
  ui-spec.md
  prototype/

04-spec/
  functional-spec.md
  data-model.md
  api-spec.md

05-test/
  test-strategy.md
  test-cases.md
  maestro/

06-build/
  latest.apk

07-test-results/
  test-report.md
  screenshots/
  logs/

08-bugs/
  BUG-*.md
```

---

# 17. Minimal Command Pattern

Same chat with context:
> Continue Step X.

New chat:
> Follow `project-workflow.md`. Read all uploaded approved artifacts and continue Step X.

New boss decision:
> Boss update: [new confirmed decisions]. Apply impact analysis first, then continue Step X.

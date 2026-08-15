# COLOR PRODUCT — CURRENT SOURCE OF TRUTH

This package contains only the latest approved/synchronized project artifacts.

## Important

- Do NOT mix these files with older downloaded copies such as `(1)`, `(2)`, `(3)`.
- Use this folder as the project root in VS Code / Claude Code.
- Step 6 uses the latest Hi-Fi HTML version.
- Steps 7, 8, 9 and 10 are the synchronized versions created after the Hi-Fi Step 6 update.
- Step 1–5 remain unchanged because the Hi-Fi design did not change the approved BA baseline.

## Source-of-Truth Priority

1. Latest explicit boss/user decision
2. Latest approved relevant artifact in this package
3. Older approved artifact
4. AI assumption
5. Competitor pattern

AI must never silently change a confirmed decision.

## Current Project Structure

```text
COLOR-PRODUCT-LATEST/
├── project-workflow.md
├── SOURCE-OF-TRUTH.md
├── 00-product/
│   ├── product-brief.md
│   ├── competitor-analysis.md
│   └── mvp-scope.md
├── 01-architecture/
│   └── information-architecture-user-flow.md
├── 02-requirements/
│   └── requirements.md
├── 03-design/
│   ├── ui-spec.md
│   ├── design-system.md
│   ├── design-decisions.md
│   └── prototype/
├── 04-spec/
│   ├── functional-spec.md
│   ├── data-model.md
│   ├── api-spec.md
│   └── step7-impact-analysis.md
├── 05-test/
│   ├── test-strategy.md
│   ├── test-cases.md
│   ├── automation-candidates.md
│   ├── automation-map.md
│   ├── selectors-contract.md
│   ├── automation-runbook.md
│   ├── step8-impact-analysis.md
│   ├── step9-impact-analysis.md
│   ├── maestro/
│   ├── playwright/
│   └── scripts/
├── 06-build/
│   └── README.md
├── 07-test-results/
│   ├── test-report.md
│   ├── qa-checklist.md
│   ├── regression-scope.md
│   ├── build-qa-runbook.md
│   ├── step10-impact-analysis.md
│   └── evidence/
└── 08-bugs/
    └── BUG-TEMPLATE.md
```

## Current Workflow State

- Step 1–5: BA baseline complete; Step 4 (IA) and Step 5 (Requirements) re-synced 2026-08-14 to the Home/Library/Profile re-baseline (see below)
- Step 6: Hi-Fi HTML design baseline created, visual execution still needs refinement/approval. `ui-spec.md` and `design-decisions.md` re-synced 2026-08-14; **prototype HTML/CSS/JS is NOT yet re-synced** — see Re-Baseline Status below
- Step 7: Synced; `functional-spec.md` re-synced 2026-08-14. `data-model.md` assessed — no schema change required
- Step 8: Synced; `test-cases.md` re-synced 2026-08-14
- Step 9: Synced; `selectors-contract.md` and `automation-map.md` re-synced 2026-08-14 (documentation/mapping only — no Maestro/Playwright implementation changes yet)
- Step 10: Prepared and synced; real execution awaits APK/build

## Re-Baseline Status (2026-08-14) — Home / Library / Profile Navigation

**Approved decisions on record** (see `design-decisions.md` DD-010 → DD-015, `information-architecture-user-flow.md` UXD-006 → UXD-008):

- New screens: `SCR-LIBRARY-001` (discovery/browse), `SCR-PROFILE-001` (personal artwork + Settings entry).
- `SCR-CATEGORY-001`, `SCR-PREVIEW-001`, `SCR-WORKS-001` are **Legacy — preserved, not routed** from the approved MVP core flow (not deleted, not renamed).
- Home restructured to repeatable category sections only (Featured/Daily/Continue/icon-grid Categories are Legacy).
- Artwork tap (Home/Library/Profile/Completion) opens Coloring directly — no Preview hop; resume-or-create rule applies.
- Bottom navigation: Home / Library / Profile (was Home / My Works / Settings).
- Completion revised: Share (native share sheet), Save/Download, Back to Home, Recommended for you.
- **Correction (2026-08-15):** Completion's top-left header Back is a *distinct* control from the "Back to Home" primary action button. Header Back → `SCR-EDITOR-001`, reopening the same just-completed artwork with its latest state/progress restored (no new session, status stays `COMPLETED`). "Back to Home" is unchanged → `SCR-HOME-001`. See `information-architecture-user-flow.md` NAV-005 and `requirements.md` REQ-EDITOR-018.
- Favorite/Bookmark confirmed out of MVP; decorative bookmark icon on legacy Preview flagged non-approved.

**Artifacts updated to reflect this baseline:** `information-architecture-user-flow.md`, `requirements.md`, `ui-spec.md`, `design-decisions.md`, `functional-spec.md`, `data-model.md` (assessed, unchanged), `selectors-contract.md`, `test-cases.md`, `automation-map.md`.

**Not yet updated (explicitly deferred, pending a separate implementation pass):** `03-design/prototype/index.html`, `styles.css`, `app.js`, and `05-test/playwright/tests/prototype.spec.js`. Until that pass runs, the prototype reflects the pre-2026-08-14 flow (Home → Category/Preview, My Works/Settings bottom nav) and should not be treated as matching the current approved documentation baseline.

## Library Search — New MVP Feature (2026-08-16)

**Approved decision:** Library Search, previously a Could-Have/V1.1 candidate, is promoted to MVP MUST. New Screen ID `SCR-SEARCH-001` (child of Library, no bottom nav) — see `design-decisions.md` DD-016, `information-architecture-user-flow.md` §5.13/NAV-009/FLOW-LIBRARY-002, `requirements.md` REQ-LIB-007→012, `mvp-scope.md` FE-LIB-005→008.

**Artifacts updated:** `mvp-scope.md`, `information-architecture-user-flow.md`, `requirements.md`, `ui-spec.md`, `design-decisions.md`, `functional-spec.md`, `selectors-contract.md`, `test-cases.md`, `automation-map.md`.

**Implementation:** `03-design/prototype/index.html`/`styles.css`/`app.js` and `05-test/playwright/tests/prototype.spec.js` updated in the same pass (unlike the 2026-08-14 re-baseline, prototype sync was not deferred here).

## Claude Code Rule

When opening this folder in Claude Code:

> Read `SOURCE-OF-TRUTH.md` and `project-workflow.md` first. Then read all relevant approved artifacts before modifying the project. Do not use or infer from older copies outside this folder.

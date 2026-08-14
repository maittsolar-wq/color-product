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

- Step 1–5: BA baseline complete
- Step 6: Hi-Fi HTML design baseline created, visual execution still needs refinement/approval
- Step 7: Synced
- Step 8: Synced
- Step 9: Synced
- Step 10: Prepared and synced; real execution awaits APK/build

## Claude Code Rule

When opening this folder in Claude Code:

> Read `SOURCE-OF-TRUTH.md` and `project-workflow.md` first. Then read all relevant approved artifacts before modifying the project. Do not use or infer from older copies outside this folder.

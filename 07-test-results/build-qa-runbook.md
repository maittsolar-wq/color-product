# Step 10 Runbook — Build QA / Bug Analysis

## Current State
Step 10 is prepared but **not executed** because no real APK/build has been provided.

---

# When the build is ready

Provide:
1. APK/build
2. current Step 1–9 artifacts
3. automation results if already run
4. logs/screenshots/videos
5. version/build info if known

Use this instruction:

> Follow the current project artifacts. Execute Step 10 Build QA / Bug Analysis against this build. Preserve TC/REQ/Screen/Component IDs. Produce test-report.md, BUG files for confirmed product defects, and regression-scope.md.

---

# Recommended execution order

1. Build intake
2. Install
3. Launch
4. Smoke
5. Maestro
6. Content validator
7. Manual Editor QA
8. Persistence QA
9. Monetization if enabled
10. Exploratory UI/UX
11. Bug classification
12. Regression scope
13. Release verdict

---

# Evidence structure

```text
evidence/
├── screenshots/
├── videos/
├── logs/
├── maestro/
├── playwright/
├── content-validator/
└── device-info/
```

---

# Important Rule

Do not call an automation failure a product bug until it is classified.

Possible classifications:
- Product defect
- Automation issue
- Environment issue
- Test data issue
- Requirement ambiguity

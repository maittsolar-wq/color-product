# Step 9 Automation Runbook — Synced Version

## 1. What can run now

### Playwright
Runs against Step 6 Hi‑Fi HTML.

### Content Validator
Runs against content manifest JSON.

## 2. What needs the native build

### Maestro
Requires:
- real Android appId;
- installed APK/build;
- stable test IDs.

Current YAML uses:

`com.example.coloringapp`

Replace it with the real appId.

---

# 3. Run Playwright

Serve the Step 6 prototype:

```bash
cd coloring-step6-hifi/prototype
python -m http.server 8080
```

Then:

```bash
cd coloring-step9-synced/playwright
npm install
npx playwright install
npm test
```

Default URL:
`http://127.0.0.1:8080`

Override:

```bash
BASE_URL=http://localhost:9000 npm test
```

---

# 4. Run Content Validator

```bash
python scripts/validate_content.py scripts/sample-content-manifest.json
```

Expected:
`VALIDATION PASSED`

---

# 5. Run Maestro Smoke

After replacing appId and installing the build:

```bash
maestro test maestro/smoke/smoke-main.yaml
```

Run entire suite:

```bash
maestro test maestro
```

---

# 6. Recommended Native Test Order

1. smoke
2. discovery
3. editor
4. progress
5. works
6. monetization
7. settings

---

# 7. Before Step 10

Collect:

```text
test-results/
├── maestro/
├── playwright/
├── screenshots/
├── logs/
└── device-info/
```

Then Step 10 can map failures:

`Automation → TC → REQ → BUG`

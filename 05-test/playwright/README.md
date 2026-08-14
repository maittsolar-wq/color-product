# Playwright — Hi‑Fi Prototype

Serve Step 6 prototype first:

```bash
cd ../../coloring-step6-hifi/prototype
python -m http.server 8080
```

Then:

```bash
npm install
npx playwright install
npm test
```

These tests validate Step 6 Hi‑Fi HTML behavior only.

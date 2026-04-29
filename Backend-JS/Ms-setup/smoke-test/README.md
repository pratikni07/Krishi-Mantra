# Smoke test

Hits the backend's most-used GET endpoints with a real auth token and reports
whether each one returns a non-error response. Use it to catch contract drift
between the Flutter client and the backend after route changes.

## Run

```sh
API_BASE_URL=https://api.krishimantra.com \
  AUTH_TOKEN=eyJ... \
  TEST_USER_ID=64f...e \
  TEST_PRODUCT_ID=... \
  TEST_REEL_ID=... \
  TEST_CROP_ID=... \
  node smoke-test.js
```

`AUTH_TOKEN` is required. The other `TEST_*` vars are optional — endpoints that
need them are skipped when absent.

Exit code 0 when every endpoint returns a 2xx/3xx/4xx (no 404, no 5xx). Exit
code 1 otherwise.

## What it covers

GET endpoints from each repository file in
`Frontend/krishimantra/lib/data/repositories/`. POST/PUT/DELETE are
intentionally omitted because they require fixtures and side-effect cleanup.

## When to run

- After changing any backend route mount or path rewrite.
- Before merging a PR that touches `api-gateway-service/index.js`.
- As part of the Phase 2 contract-test gate in the implementation plan.

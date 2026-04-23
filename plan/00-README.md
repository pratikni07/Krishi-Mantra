# Krishi-Mantra — Full-Stack Audit & Refactoring Plan

This directory contains a top-to-bottom audit of the Krishi-Mantra platform
(agricultural super-app for Indian farmers) covering every service, every
client, and the infrastructure that ties them together. It is intended as a
durable reference for engineers, tech leads, security reviewers, and anyone
onboarding into the codebase.

The audit is based on the full source tree at the repository root as of
**2026-04-20** (branch `copilot/add-iot-device-for-krishi-mantra`).

---

## What this repo contains

| Plane         | Stack                                           | Count / Scale                                              |
| ------------- | ----------------------------------------------- | ---------------------------------------------------------- |
| Backend (JS)  | Node.js 20 + Express 4 + Mongoose + Redis + RMQ | **8 microservices** (gateway, main, feed, msg, reel, notif, engagement, api) |
| IoT plane     | Go 1.x + MQTT (Mosquitto) + ClickHouse          | 1 service, 4 run-modes (consumer, api, worker, full)       |
| Mobile app    | Flutter 3.6 + GetX + Dio + Hive                 | **30+ screens, 21 controllers, 15 repositories, 140+ API endpoints** |
| Admin panels  | Next.js 14 (admin) + Next.js 15 (marketplace)   | 18 + 6 pages, TypeScript, Tailwind, shadcn/ui              |
| Landing       | Vite + vanilla JS                               | 1 static marketing site                                    |
| Infra         | Docker Compose + Kubernetes manifests           | `microservices` namespace, Prometheus, cert-manager        |
| Localization  | Custom Map-based, 6 languages                   | 100+ keys in [home_localizations.dart](../Frontend/krishimantra/lib/core/utils/home_localizations.dart) |
| Test coverage | Near zero                                       | 12 Go tests in iot-service, 1 placeholder Flutter widget test |

---

## Document map

Read in order for the full picture; jump directly if you know what you need.

| #  | Document | Purpose |
| -- | -------- | ------- |
| 01 | [Architecture Overview](01-architecture-overview.md) | System topology, service inventory, cross-cutting flows (auth, feed, chat, reels, IoT, subscriptions), persistence layer, high-level risks. **Start here.** |
| 02 | [Microservices Deep-Dive](02-microservices-deep-dive.md) | Per-service internals: routes, models, middleware, message queues, critical defects, operational characteristics. |
| 03 | [Frontend Deep-Dive](03-frontend-deep-dive.md) | Flutter mobile app internals (GetX, clean architecture, auth refresh lock, disease detection, localization) + both admin panels + landing. |
| 04 | [Gaps & Improvements](04-gaps-and-improvements.md) | Prioritized backlog (P0/P1/P2/P3) with specific IDs you can reference in tickets. Security, correctness, performance, DX. |
| 05 | [Refactoring Roadmap](05-refactoring-roadmap.md) | Phased execution plan — Phase 0 (pre-launch lockdown) → Phase 4 (backlog) — each item linked back to a §04 ID with a Definition of Done. |
| 06 | [Security & Performance Audit](06-security-performance-audit.md) | Audit-style findings by severity (Critical/High/Medium/Low) covering auth, secrets, input handling, DoS, IoT, latency, mobile perf, observability. |

---

## Reading order by audience

**Executive / product lead** → [§01](01-architecture-overview.md) topology + [§04](04-gaps-and-improvements.md) summary table at bottom. ~20 min.

**New engineer onboarding** → [§01](01-architecture-overview.md) → [§02](02-microservices-deep-dive.md) (skim) → [§03](03-frontend-deep-dive.md) (focus on your plane). ~2 hrs.

**Security reviewer** → [§06](06-security-performance-audit.md) Critical + High tables → [§02](02-microservices-deep-dive.md) for context on flagged services → [§05](05-refactoring-roadmap.md) Phase 0. ~90 min.

**Tech lead planning next quarter** → [§04](04-gaps-and-improvements.md) full read → [§05](05-refactoring-roadmap.md) to sequence → cross-reference [§06](06-security-performance-audit.md) for the must-do items. ~3 hrs.

**On-call / SRE** → [§06](06-security-performance-audit.md) §§6.9 Reliability + 6.10 Observability → [§01](01-architecture-overview.md) persistence diagram. ~45 min.

---

## Headline findings (do not ship to production without addressing)

These are the issues that would most likely cause incidents, data loss, or
legal exposure if the platform reached meaningful scale in its current form.
Each links to the canonical entry in §04 or §06.

1. **Gateway does not verify JWTs** — auth is enforced only by downstream services; any service reachable directly is unauthenticated. (§06 S-01)
2. **Socket.io accepts `userId` from the client without token validation** — any attacker can impersonate any user in chat. (§06 S-02)
3. **Hardcoded API keys / credentials in repo** — Gemini keys and others in [api-service/cricgemini.js](../Backend-JS/api-service/cricgemini.js) and seed scripts. (§06 S-11)
4. **Anonymous MQTT broker in production config** — devices publish without authentication, topics are world-readable. (§06 S-31)
5. **Synchronous FFmpeg in reel-service HTTP handler** — blocks the event loop for seconds per upload; trivial DoS. (§06 P-03)
6. **No refresh-token rotation, long access-token TTL** — stolen token = permanent account access. (§06 S-05)
7. **Near-zero automated test coverage** across backend and mobile; regressions ship silently. (§04 P1-Q1)
8. **No request-level rate limiting at the gateway** — per-service Redis limiters exist but are bypassed by direct routes. (§06 S-26)

See [§05 Phase 0](05-refactoring-roadmap.md) for the one-week lockdown plan that addresses items 1–5.

---

## Conventions used in these docs

- File references use markdown links relative to the repo root, e.g. [main-service/src/app.js](../Backend-JS/main-service/src/app.js).
- Issue IDs are stable: `P0-N` / `P1-N` / … from §04, and `S-NN` / `P-NN` / `R-NN` from §06. §05 references both.
- Severity terms follow common audit practice: **Critical** = exploitable now with low effort; **High** = likely within weeks at current scale; **Medium** = degrades UX or blocks growth; **Low** = hygiene.
- "Current state" describes what the code does on `main` today; "Recommendation" is forward-looking.

---

## What this audit does *not* cover

- Formal threat modelling (STRIDE/LINDDUN) — §06 covers concrete findings, not a full model.
- Load/stress test numbers — no harness exists yet; performance claims are static-analysis based.
- Business-logic correctness of agronomy features (disease detection accuracy, MSP/mandi data validity) — this is an engineering audit, not a domain review.
- Legal/compliance posture (DPDP Act, PCI-DSS for Stripe handling) — flagged where obvious but not a full review.

These are listed as follow-ups in [§05 Phase 4 (Backlog)](05-refactoring-roadmap.md).

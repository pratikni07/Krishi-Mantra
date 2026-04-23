# Krishi AI — Multi-Provider Refactor & Personalized Onboarding

> **Goal:** Replace the current Groq + Gemini hybrid with a **provider-pluggable AI layer** (OpenAI ChatGPT + Google Vertex AI), pick the active one from the **admin panel** with securely-stored credentials, collect a detailed farming profile at signup (with **multi-crop** support), inject it + a ±3-day weather window as system prompt context, and do it all on a **context tree** that keeps per-call token usage low.

Exactly one provider is active at a time (admin-selected). All users are served by that provider. Switching is zero-downtime; old chats keep working.

This folder contains the complete end-to-end implementation plan. Documents are numbered in the recommended reading order. Each doc is self-contained so individual subteams (backend, mobile, infra, admin UI) can pick up their slice.

---

## Index

| # | File | Audience | What it covers |
|---|------|----------|----------------|
| 00 | [00-README.md](00-README.md) | Everyone | This overview + glossary |
| 01 | [01-requirements-and-goals.md](01-requirements-and-goals.md) | PM, Eng leads | Problem statement, success criteria, non-goals, KPIs |
| 02 | [02-current-state-analysis.md](02-current-state-analysis.md) | All engineers | What exists today: services, schemas, prompts, gaps |
| 03 | [03-target-architecture.md](03-target-architecture.md) | Backend, Mobile, Admin UI | Target system diagram, provider registry, admin config source |
| 04 | [04-data-model-changes.md](04-data-model-changes.md) | Backend | Mongo schema diffs (User, FarmProfile, AIChat, WeatherSnapshot, **AiProviderConfig**) |
| 05 | [05-onboarding-and-profile-flow.md](05-onboarding-and-profile-flow.md) | Mobile, Backend | Multi-step signup, multi-crop picker, edit-profile, validation |
| 06 | [06-backend-openai-implementation.md](06-backend-openai-implementation.md) | Backend | Provider interface + OpenAI implementation, routing, streaming, retries |
| 06b | [06b-google-vertex-provider.md](06b-google-vertex-provider.md) | Backend | Google Vertex AI provider module, auth, context-cache, region fallback |
| 07 | [07-context-tree-token-optimization.md](07-context-tree-token-optimization.md) | Backend | **Context tree** design to cut tokens 60–80% (key doc) |
| 08 | [08-weather-integration.md](08-weather-integration.md) | Backend | OpenWeather/Open-Meteo ±3-day window, cache, snapshot model |
| 09 | [09-prompt-engineering.md](09-prompt-engineering.md) | Backend | Layered system prompt templates, multi-lingual, image prompts |
| 10 | [10-frontend-implementation.md](10-frontend-implementation.md) | Mobile | Flutter screens/controllers/repositories, state, routing |
| 11 | [11-migration-rollout-observability.md](11-migration-rollout-observability.md) | Backend, SRE | Feature flag, backfill, cost dashboards, alerting, rollback |
| 12 | [12-task-breakdown-and-estimates.md](12-task-breakdown-and-estimates.md) | PM, Eng | Sprint-by-sprint tasks with owners + estimates |
| 13 | [13-admin-provider-management.md](13-admin-provider-management.md) | Admin-UI, Backend, SRE | Admin panel UI + APIs for choosing provider and storing credentials |

---

## TL;DR — What we're building

### From (today)
- **Chat** → Groq `llama-3.3-70b-versatile`
- **Image analysis** → Google Gemini 2.0-flash (with key rotation)
- Provider + keys hard-coded in service env vars
- Client sends `{lat, lon, temperature, humidity}` per request — stubbed on mobile
- Signup collects `name / firstName / lastName / phoneNo / image` only
- No farm-level profile; AI has no idea what the farmer grows
- System prompt is flat — built per-request, not reused across turns

### To (target)
- **Provider-pluggable AI layer**. Two first-class providers behind one `ProviderInterface`:
  - **OpenAI** (`gpt-4.1-mini` chat, `gpt-4o-mini` vision, `text-embedding-3-small`)
  - **Google Vertex AI** (`gemini-2.5-flash` chat + vision, `text-embedding-005`)
- **Admin panel** chooses which provider is active and stores credentials (API keys for OpenAI, Service-Account JSON / Workload Identity Federation for Vertex). Credentials live in MongoDB **encrypted (AES-256-GCM)**; plaintext never on disk or in logs.
- Switching the active provider is **one click and zero-downtime** — Redis pub/sub invalidates the factory cache, next request uses the new provider.
- Rich `FarmProfile` stored server-side per user: **N crops**, each with sowing date / growth stage / area / variety / irrigation / soil.
- Per-chat, server auto-attaches a **weather snapshot** (D-3 → D+3) from Open-Meteo (OpenWeather fallback).
- **Layered context tree** — a small core prompt + cached profile block + cached recent-chat summary + per-turn delta → 60–80% fewer tokens than a flat rebuild. Caching works with both providers (OpenAI prompt cache + Vertex context cache).
- Response streaming; token usage/cost tracked per user + per message **per provider**.
- Multi-lingual output preserved (13 Indian languages).

---

## Glossary

| Term | Meaning in this plan |
|------|---------------------|
| **Context tree** | Hierarchical system-prompt assembly: `core → user profile → crop block(s) → weather block → chat summary → recent turns → current turn`. Each layer is cached independently so a small change (e.g. new turn) only invalidates the leaf. |
| **Context fingerprint** | `sha1(content)` for each cached layer. Lets us know whether a cached prompt block is still valid. |
| **FarmProfile** | New Mongo collection. One doc per user. Contains an array of `crops[]`, each with its own sowing/growth metadata. |
| **WeatherSnapshot** | Cached `{location, fetchedAt, days[-3..+3]}` document. Reused across all chats for a ~1h TTL per location bucket. |
| **Prompt budget** | Hard token cap per turn. Default **2500 input tokens + 800 output tokens** for chat. |
| **Intent router** | Cheap classifier (regex + optional `gpt-4o-mini` fallback) that picks which layers of the tree to load. A "what's the weather" question doesn't need full crop history. |
| **Daily quota** | Subscription-based per-user cap (currently 5/50/∞ msgs/day). Unchanged. |
| **Provider** | One of the supported AI backends: `openai` \| `vertex`. Selected by admin; only one active at a time. |
| **ProviderInterface** | Common contract (`streamChat`, `chat`, `analyzeImages`, `embed`, `countTokens`) that every provider module implements. Callers never know which one they're using. |
| **AiProviderConfig** | New Mongo collection. Stores provider settings + encrypted credentials + active flag. Single-active constraint enforced by a partial unique index. |
| **ProviderFactory** | Runtime resolver: reads the active `AiProviderConfig` (Redis-cached) and returns the matching provider module. |

---

## Why a "context tree" and not a flat prompt?

Today every turn rebuilds a ~1.5–3 kB system prompt from scratch. With farm profile + 7-day weather + crop calendar, a flat prompt balloons to **6–10 kB per turn**. Across a 20-turn chat, that's cents per chat and a ballooning bill.

The tree solves this by:
1. **Caching stable layers** — profile & crop blocks change weekly, not per-turn.
2. **Prompt-caching on OpenAI** — if a prompt prefix is reused byte-for-byte, OpenAI charges ~½ price and serves it faster. We design the tree so the stable layers come first.
3. **Summarizing old turns** — once a chat exceeds 10 turns, older turns collapse to a 150-token summary maintained by the service, not resent verbatim.
4. **Routing by intent** — weather question? skip crop blocks. Pest question on tomato? load only the tomato block.

Expected impact: **—65% input tokens / —40% output tokens** vs a naive "stuff everything in" rewrite. See [07](07-context-tree-token-optimization.md) for the math and implementation.

---

## What the user asked for (mapped to docs)

| Ask | Covered in |
|-----|-----------|
| "Use ChatGPT API for the AI feature" | 03, 06, 09 |
| "Also add Google Vertex AI" | 03, **06b**, 13 |
| "From admin panel pick the provider and configure credentials" | **13**, 04 (`AiProviderConfig`) |
| "If I enable OpenAI, use OpenAI for all users; if I enable Vertex, use Vertex for all users" | 03 (factory), 13 (activate flow) |
| "End-to-end AI feature handled by chosen provider" (incl. image) | 06, 06b, 09 |
| "At signup take detailed info: crops, age of crop, land, …" | 04, 05 |
| "User can select multiple crops" | 04, 05 |
| "Pass this info as system prompt when using AI feature" | 07, 09 |
| "Weather details of 3 days ago and 3 days ahead" | 08, 09 |
| "Build a tree so token usage is reduced" | **07** |
| "Create detailed implementation plan" | entire `plan/krishi-ai/` |

---

## Status

- **Plan drafted:** 2026-04-21
- **Target kickoff:** sprint after plan review
- **Rough size:** 5 engineer-weeks backend + 3 engineer-weeks mobile + 1 week SRE/infra

See [12-task-breakdown-and-estimates.md](12-task-breakdown-and-estimates.md) for the sprint breakdown.

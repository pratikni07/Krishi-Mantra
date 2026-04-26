# A06 — Today's Action Card: Localization & Tone

The action card is read at 5 AM by farmers who often skim more than read. **Tone is half the product.** This doc nails down the voice, the language matrix, the translation pipeline, and the dialect strategy.

## 1. Tone principles

The card sounds like a trusted neighbor, not a textbook.

| Do | Don't |
|----|------|
| Use the imperative: *"Spray mancozeb today"* | Use passive: *"It is recommended that mancozeb may be sprayed"* |
| Lead with the action verb in the title | Lead with the explanation |
| One short safety note: *"Wear gloves"* | A paragraph of warnings |
| Short sentences (≤ 12 words) | Compound sentences with multiple clauses |
| Local units: acre, bigha, kg, litre, ₹ | metric-only without local equivalents |
| Names of generic actives in lowercase: *mancozeb, urea, NPK* | Brand names: *"Indofil M-45", "DAP by Coromandel"* |
| Number figures: 2.5 g/L, 200 ml/acre | Spelled-out numbers |

### Why no brand names

- Liability — recommending a specific brand can be construed as endorsement.
- Accuracy — labels on counterfeit products are unreliable; generic actives are safer.
- Local supply — what's stocked in Sinnar may not be stocked in Anand.
- The marketplace tab is the right surface for product listings.

## 2. Voice in each language

### English (en) — used as the canonical source
Direct, agronomist-on-radio style.
> *"Spray mancozeb on tomato today. 2.5 g/L. Cover both leaf surfaces. No rain forecast for 48 hours. Wear gloves and a mask."*

### Hindi (hi) — Devanagari
Polite imperative (नियमित आदेश/सुझाव), avoid heavy Sanskritized vocabulary.
> *"आज टमाटर पर मैनकोज़ेब छिड़काव करें। 2.5 ग्राम प्रति लीटर। पत्तियों के दोनों ओर अच्छी तरह छिड़काव करें। 48 घंटे बारिश नहीं है। दस्ताने और मास्क जरूर पहनें।"*

Words to prefer: *करें, छिड़काव, खाद, सिंचाई*. Avoid heavy: *अनुशंसित, प्रयोगाधीन*.

### Marathi (mr) — Devanagari
Closer to spoken register.
> *"आज टोमॅटोवर मॅन्कोझेब फवारणी करा. 2.5 ग्रॅम/लीटर. पाने दोन्ही बाजूंनी झाकून फवारा. पुढील 48 तास पाऊस नाही. हातमोजे + मास्क घाला."*

Words to prefer: *करा, फवारणी, खत, पाणी*. Avoid: *प्रोत्साहन, सुनिश्चित*.

### Bengali (bn), Gujarati (gu), Kannada (kn), Malayalam (ml), Odia (or), Punjabi (pa), Tamil (ta), Telugu (te), Urdu (ur), Assamese (as)
Same imperative-spoken-register principle. Native reviewers (one per language) sign off on the launch set; see §6.

## 3. Translation key shape

Every template carries an i18n key. Rather than translating free-form strings, we structure each action item as a **template** with named placeholders + a few fixed variants:

```js
// CropTaskTemplate.translations
{
  "en": {
    "title": "Spray {chemical} on {crop}",
    "detail": "{dose} {chemical}. Cover both leaf surfaces. {weatherClause}",
    "safetyNote": "Wear gloves and a mask. Do not spray within 7 days of harvest.",
    "weatherClauses": {
      "no_rain_48h": "No rain forecast for 48 hours.",
      "rain_in_36h":  "Rain expected in 36 hours — do this morning."
    }
  },
  "hi": { ... },
  "mr": { ... },
  // ... 13 entries
}
```

The localizer (`services/action-card/localizer.js`) resolves the key by:
1. Looking up `translations[lang]` on the template.
2. If missing, fall back to `translations.en` and warn (`localizer.missing_translation` metric).
3. Substituting `{crop}, {variety}, {chemical}, {dose}` from the template metadata + crop entry.
4. Selecting the matching `weatherClause` based on rationale tags.

We **never** machine-translate at runtime. Every shipped translation is hand-curated.

## 4. Translation pipeline

| Phase | Owner | Output |
|-------|-------|--------|
| Author | Agronomy | EN strings + variable list |
| Translate (1st pass) | NMT (e.g. AI4Bharat IndicTrans) | Draft hi/mr + auto-flagged terms |
| Edit | Native reviewer per language | Final strings + cultural notes |
| Sign-off | PM | `template.translations[lang]` set |
| Smoke | Mobile QA | Render check on real device |

The first three phases happen offline and produce the JSON payload that gets `$set` on the template doc. There's an admin endpoint for editors:

```
PUT /api/admin/templates/:id/translations
body: { lang, title, detail, safetyNote, weatherClauses }
```

Audit-logged like all admin actions.

## 5. Dialect handling (within a language)

Hindi and Marathi (and Telugu, Tamil, Kannada) have meaningful dialect variation between districts. We do **not** model dialect at launch. Instead:

1. Use the **most widely understood standard register** for each language (e.g. standard Hindi as on AIR Krishi, standard Maharashtrian Marathi as on Pune Doordarshan).
2. Avoid Sanskritized or Persianized extremes — both alienate parts of the audience.
3. Test with a 5-farmer focus group per launch language.

Future: if dialect mismatches show up in the `done` vs `skip` data per region (e.g. Vidarbha skips a certain Marathi phrasing more than Sangamner), introduce an optional `dialectKey` per state and pick at render time.

## 6. Launch language matrix

| Lang | Code | Launch? | Rationale |
|------|------|---------|-----------|
| English | en | ✓ | Engineering source-of-truth |
| Hindi | hi | ✓ | Largest user pool, broad reach |
| Marathi | mr | ✓ | Pilot region (Maharashtra) |
| Bengali | bn | Phase 2 (week 4) | West Bengal/Odisha cluster |
| Gujarati | gu | Phase 2 | Surat/Anand farmers |
| Punjabi | pa | Phase 2 | Punjab wheat/rice |
| Telugu | te | Phase 3 (week 6) | AP/Telangana |
| Tamil | ta | Phase 3 | TN |
| Kannada | kn | Phase 3 | Karnataka |
| Malayalam | ml | Phase 4 | Kerala |
| Odia | or | Phase 4 | Odisha |
| Urdu | ur | Phase 4 | Selected districts |
| Assamese | as | Phase 4 | Assam pilot |

Until a phase ships, the card falls back to English with a small banner: *"Marathi version coming soon"*.

## 7. Verb glossary

Master list of action verbs and their preferred phrasings in each launch language.

| verb (key) | en | hi | mr |
|-----------|----|----|----|
| `spray_fungicide` | Spray fungicide | फफूंदनाशक छिड़काव करें | बुरशीनाशक फवारणी करा |
| `spray_insecticide` | Spray insecticide | कीटनाशक छिड़काव करें | कीटकनाशक फवारणी करा |
| `spray_herbicide` | Spray herbicide | खरपतवारनाशक छिड़काव करें | तणनाशक फवारणी करा |
| `fertilize` | Apply fertilizer | खाद डालें | खत द्या |
| `irrigate` | Irrigate | सिंचाई करें | पाणी द्या |
| `scout` | Scout for pests/disease | खेत निरीक्षण करें | शेताची पाहणी करा |
| `weed` | Weed | निराई करें | तण काढा |
| `prune` | Prune | छँटाई करें | छाटणी करा |
| `stake` | Stake / support | सहारा दें | आधार द्या |
| `thin` | Thin seedlings | छंटाई करें (पौधा) | रोपांची विरळणी |
| `harvest_check` | Check for harvest readiness | कटाई की जांच करें | कापणी तपासा |
| `soil_test` | Send for soil testing | मिट्टी जांच करवाएं | माती तपासणी |
| `mulch` | Apply mulch | मल्चिंग करें | आच्छादन (mulching) |

The full table for all 13 languages lives in `Backend-JS/main-service/src/services/action-card/verb-glossary.js` and is the single source of truth for both card titles and the journal screen labels.

## 8. Numbers, units, dates

| Element | Rule | Example |
|---------|------|---------|
| Doses | Plain digits, unit in target lang | `2.5 g/L`, `200 ml/एकड़` |
| Currency | `₹` symbol with digits | `₹450`, `₹35/kg` |
| Date in card header | Localized day + Devanagari/Roman number | `25 एप्रिल`, `२५ एप्रिल` (mr config option) |
| Time windows | Hours/days in target language word | `48 तास`, `7 दिवस`, `48 hours` |
| "today" | Translated word, lowercase | `आज`, `आज`, `today` |

We use **Roman digits** in numbers by default (more universally read), with a per-language override flag if a region's reviewer requests Devanagari numerals.

## 9. Push-notification copy

The morning push uses a short, actionable string:

```
Title: आज तुमच्या शेतात — 2 कामे     (en: "Today on your farm — 2 tasks")
Body:  टोमॅटो: मॅन्कोझेब फवारणी जरूरी
       (en: "Tomato: mancozeb spray needed")
```

Constraints:
- Title ≤ 32 chars (FCM render budget on small phones).
- Body ≤ 90 chars.
- Always lead with the highest-urgency item.
- If 0 pending: skip the push entirely.

`notify.service` resolves the right strings via the same translations matrix.

## 10. Empty-state copy

| State | en | hi | mr |
|-------|----|----|----|
| No FarmProfile | Tell us about your farm to see today's actions. | अपने खेत की जानकारी दें ताकि हम आज के काम सुझा सकें। | तुमच्या शेताची माहिती द्या, आम्ही आजची कामे सांगू. |
| No active crops | Add a crop to get personalised actions. | फसल जोड़ें ताकि व्यक्तिगत सुझाव मिल सके। | पीक जोडा, खास तुमच्यासाठी सुचवू. |
| All done | All tasks done today. Great job! | आज के सभी काम पूरे। बढ़िया! | आजची सर्व कामे झाली. छान! |
| Server error | Couldn't load today's actions. Tap to retry. | आज के काम लोड नहीं हुए। फिर से कोशिश करें। | आजची कामे लोड झाली नाहीत. पुन्हा प्रयत्न करा. |

## 11. Skip-reason chip labels

| Key | en | hi | mr |
|-----|----|----|----|
| `already_done` | Already done | पहले से किया | आधीच केलं |
| `not_needed` | Not needed | जरूरी नहीं | गरज नाही |
| `will_do_later` | Will do later | बाद में करूँगा | नंतर करेन |
| `cant_do` | Can't do today | आज नहीं कर सकते | आज शक्य नाही |

## 12. Edge cases

### Mixed-script user names
Some users sign up with English names and Marathi UI. Address them with **localized greetings**, not their name in their UI's script: *"Today's actions"* not *"Pratik साठी आजची कामे"*.

### Honorifics
Drop them. *"नमस्कार"* in the UI feels formal at 5 AM. The Tone target is "neighbor", not "letter".

### Code-mixing
Real-world Hindi often code-mixes with English ("कल spray करना है"). We **don't** code-mix in the UI — it makes translation pipelines unreliable. We *do* tolerate user input that code-mixes (handled by the AI chat, not the action card).

### Right-to-left (Urdu)
Urdu UI flips. The card layout uses `Directionality` to handle the mirror. Buttons stay in tap-friendly positions; only icons need mirroring (the ↻ refresh icon stays unmirrored — universal symbol).

## 13. Quality bar before each language launch

A language is "launch-ready" only when:
- All 25 launch-day templates have curated `translations[lang]`.
- A native reviewer has signed off on the verb glossary.
- 5-farmer focus group ran the card in that language for one week and didn't flag any item as unintelligible.
- Push-notification body fits FCM character limits when rendered with the longest crop name (`Sugarcane`/`गन्ना`/`ऊस`).
- A QA pass on Android with system text scale = 1.3× shows no truncation.

## 14. Tone audits (post-launch)

Every release the content team:
- Spot-checks 50 random rendered cards across launch languages.
- Reviews the top 10 most-skipped templates per language — high skip rate often correlates with awkward phrasing, not bad agronomy.
- Adjusts wording in `translations[lang]` and re-deploys (no template logic change required).

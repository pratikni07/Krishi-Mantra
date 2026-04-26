const { LANG_NAMES, VERB_GLOSSARY } = require('./verb-glossary');

const VERBS = Object.keys(VERB_GLOSSARY);
const URGENCIES = ['low', 'normal', 'high', 'urgent'];
const BANNED_CHEMICALS = [
  'endosulfan',
  'monocrotophos',
  'phorate',
  'methyl-parathion',
  'methyl parathion',
  'phosphamidon',
  'carbofuran',
];

function langName(code) {
  return LANG_NAMES[code] || LANG_NAMES.en;
}

function buildSystemPrompt(lang) {
  return [
    'You are a senior agronomist advising an Indian farmer in real time.',
    'Output ONE STRICT JSON object only. No prose, no markdown, no fences.',
    'Schema (every field in this exact order):',
    '{',
    `  "items": [`,
    '    {',
    '      "cropEntryId": string (must match one of the cropEntryIds in the user input),',
    `      "verb": one of [${VERBS.join(', ')}],`,
    '      "title": string ≤ 80 chars,',
    '      "detail": string ≤ 60 words explaining the recommendation,',
    '      "chemical"?: string — generic active ONLY, never a brand name,',
    '      "dose"?: string with unit, e.g. "2.5 g/L" or "200 ml/acre",',
    '      "safetyNote"?: string ≤ 25 words on PPE / re-entry / harvest interval,',
    `      "urgency": one of [${URGENCIES.join(', ')}],`,
    '      "rationaleTags": array of short snake_case strings, max 8',
    '    }',
    '  ]',
    '}',
    '',
    'CRITICAL RULES:',
    '- Output 1 to 3 items total. Each item targets exactly one crop.',
    '- If the same crop has multiple urgent issues, surface only the most pressing.',
    `- NEVER recommend a banned chemical: ${BANNED_CHEMICALS.join(', ')}.`,
    '- NEVER use brand names. Generic actives only (e.g. "mancozeb", not "Indofil M-45").',
    '- Doses MUST include a unit (g/L, ml/L, kg/acre, ml/acre).',
    '- If an image shows a clear pest/disease symptom, prioritize that crop.',
    "- Honor today's local weather: don't suggest spraying if heavy rain is forecast in the next 24 hours.",
    "- Honor the activity journal: don't suggest the same verb that was already done within its cooldown window.",
    `- Reply MUST be in: ${langName(lang)} (use that language for title, detail, safetyNote).`,
    '',
    "If you can't produce a confident recommendation, output { \"items\": [] } and nothing else.",
  ].join('\n');
}

function buildUserPayload({ profile, weather, journal, imageContext, farmerInputYesterday }) {
  const crops = (profile.crops || [])
    .filter((c) => c.isActive !== false)
    .map((c) => ({
      cropEntryId: String(c._id),
      name: c.cropName,
      variety: c.variety || null,
      area: c.area || null,
      areaUnit: c.areaUnit || null,
      sowingDate: c.sowingDate ? new Date(c.sowingDate).toISOString().slice(0, 10) : null,
      growthStage: c.growthStage || null,
      irrigationMethod: c.irrigationMethod || null,
      plantingMethod: c.plantingMethod || null,
    }));

  const weather7d = (weather?.days || []).map((d) => ({
    date:
      d.date instanceof Date
        ? d.date.toISOString().slice(0, 10)
        : String(d.date || '').slice(0, 10),
    tempMin: d.tempMin ?? null,
    tempMax: d.tempMax ?? null,
    rainfallMm: d.rainfallMm ?? 0,
    humidityMean: d.humidityMean ?? null,
    label: d.conditionLabel || d.condition || null,
  }));

  const recentActivity = (journal || []).slice(0, 30).map((row) => ({
    crop: row.cropName || '',
    verb: row.verb,
    chemical: row.chemical || null,
    date: row.localDate || (row.occurredAt ? new Date(row.occurredAt).toISOString().slice(0, 10) : null),
    source: row.source,
  }));

  const imageDescriptors = (imageContext?.images || []).map((it, i) => ({
    index: i,
    source: it.source,
    occurredAt: it.occurredAt,
    caption: it.caption || '',
    messageRole: it.messageRole || null,
  }));

  return {
    today: new Date().toISOString().slice(0, 10),
    farm: {
      totalArea: profile.totalArea ?? null,
      areaUnit: profile.totalAreaUnit ?? null,
      ownership: profile.ownership ?? null,
      soils: profile.soilTypes || [],
      irrigation: profile.irrigationSources || [],
      experienceYears: profile.experienceYears ?? null,
      state: profile.address?.state ?? null,
      district: profile.address?.district ?? null,
      village: profile.address?.village ?? null,
    },
    crops,
    weather7d,
    recentActivity,
    farmerInputYesterday: farmerInputYesterday || null,
    imageContext:
      imageDescriptors.length > 0
        ? {
            count: imageDescriptors.length,
            note:
              `${imageDescriptors.length} farmer-shared photos attached as image parts. ` +
              `Order matches the descriptors below; index 0 is the most recent. ` +
              'Look for visible pest, disease, water-stress or nutrient-deficiency signs.',
            descriptors: imageDescriptors,
          }
        : { count: 0, note: 'No images shared in the last 7 days.' },
  };
}

function buildPrompt({
  profile,
  weather,
  journal,
  imageContext,
  farmerInputYesterday,
  lang,
}) {
  const targetLang = lang && LANG_NAMES[lang] ? lang : 'en';
  const system = buildSystemPrompt(targetLang);
  const userPayload = buildUserPayload({
    profile,
    weather,
    journal,
    imageContext,
    farmerInputYesterday,
  });
  return {
    system,
    userJson: userPayload,
    targetLang,
    bannedChemicals: BANNED_CHEMICALS,
    verbs: VERBS,
    urgencies: URGENCIES,
  };
}

module.exports = {
  buildPrompt,
  buildSystemPrompt,
  buildUserPayload,
  BANNED_CHEMICALS,
  VERBS,
  URGENCIES,
};

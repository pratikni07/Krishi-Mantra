const { verbLabel, LANG_NAMES } = require('./verb-glossary');

let logger;
try {
  logger = require('../../utils/logger');
} catch (err) {
  logger = { info: () => {}, warn: () => {}, error: () => {}, debug: () => {} };
}

// Counters that the cron prints periodically; cheap and lock-free.
const missingTranslationCounts = new Map();

function bump(key) {
  missingTranslationCounts.set(key, (missingTranslationCounts.get(key) || 0) + 1);
}

function flushMetrics() {
  const out = {};
  for (const [k, v] of missingTranslationCounts.entries()) out[k] = v;
  missingTranslationCounts.clear();
  return out;
}

/**
 * Substitute {placeholder} tokens in a template string.
 * Unknown placeholders are left as-is so partial data doesn't strip text.
 */
function render(template, vars) {
  if (!template) return '';
  return template.replace(/\{([a-zA-Z0-9_]+)\}/g, (m, key) => {
    if (vars[key] === undefined || vars[key] === null || vars[key] === '') return m;
    return String(vars[key]);
  });
}

/**
 * Pick the right weather clause from the rationaleTags.
 * `weatherClauses` shape: { no_rain_48h: "...", rain_in_36h: "..." }.
 * Returns the first clause whose key appears in rationaleTags, else "".
 */
function pickWeatherClause(weatherClauses, rationaleTags = []) {
  if (!weatherClauses) return '';
  for (const tag of rationaleTags) {
    if (Object.prototype.hasOwnProperty.call(weatherClauses, tag)) {
      return weatherClauses[tag];
    }
  }
  return '';
}

/**
 * Localize a single action item against a target language.
 *
 * Inputs:
 *   item.source            — "template" or "ai" or "weather_alert" or "manual"
 *   item.template          — the CropTaskTemplate (lean) when source === "template"
 *   item.cropName, .cropVariety, .verb, .chemical, .dose, .urgency, .rationaleTags
 *   For source === "ai", title/detail/safetyNote are already localized by the AI call.
 *
 * Returns the same shape with `title`, `detail`, `safetyNote` filled in for the
 * target language, plus `lang`.
 */
function localize(item, lang) {
  const targetLang = lang && LANG_NAMES[lang] ? lang : 'en';

  // AI-fallback items already come back in the user's language.
  if (item.source !== 'template' || !item.template) {
    return {
      ...item,
      title: item.title || '',
      detail: item.detail || '',
      safetyNote: item.safetyNote || '',
      lang: targetLang,
    };
  }

  const tpl = item.template;
  const tx = tpl.translations && (tpl.translations.get
    ? tpl.translations.get(targetLang) || tpl.translations.get('en')
    : tpl.translations[targetLang] || tpl.translations.en);

  if (!tx && targetLang !== 'en') {
    bump(`missing:${tpl.cropName}:${tpl.verb}:${targetLang}`);
    logger.warn?.('localizer.missing_translation', {
      cropName: tpl.cropName,
      verb: tpl.verb,
      lang: targetLang,
    });
  }

  const titleTpl = tx?.title || tpl.titleTemplate;
  const detailTpl = tx?.detail || tpl.detailTemplate;
  const safetyTpl = tx?.safetyNote || tpl.safetyNote;
  const weatherClauses = tx?.weatherClauses || {};

  const vars = {
    crop: item.cropName,
    cropName: item.cropName,
    variety: item.cropVariety || '',
    chemical: item.chemical || tpl.chemical || '',
    dose: item.dose || tpl.dose || '',
    dosePerLitre: item.dose || tpl.dose || '',
    weatherClause: pickWeatherClause(weatherClauses, item.rationaleTags || []),
    verb: verbLabel(tpl.verb, targetLang),
  };

  return {
    ...item,
    title: render(titleTpl || '', vars).trim(),
    detail: render(detailTpl || '', vars).trim(),
    safetyNote: render(safetyTpl || '', vars).trim(),
    lang: targetLang,
  };
}

module.exports = { localize, render, pickWeatherClause, flushMetrics };

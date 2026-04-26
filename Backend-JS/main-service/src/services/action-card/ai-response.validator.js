const { BANNED_CHEMICALS, VERBS, URGENCIES } = require('./ai-prompt.builder');

const DOSE_RE = /\d+(\.\d+)?\s*(g|gm|gms|gram|grams|ml|kg|kgs|l|litre|liter)\s*(\/\s*(L|l|litre|liter|acre|ha|hectare|kg)|\s*(per\s+(L|litre|liter|acre|ha|hectare|kg)))?/i;
const SNAKE_TAG_RE = /^[a-z0-9][a-z0-9_]{0,40}$/;

function stripFences(text) {
  if (!text) return '';
  return String(text)
    .trim()
    .replace(/^```(?:json)?\s*/i, '')
    .replace(/```$/i, '')
    .trim();
}

function safeParseJson(text) {
  if (!text) return null;
  const cleaned = stripFences(text);
  try {
    const obj = JSON.parse(cleaned);
    return obj && typeof obj === 'object' ? obj : null;
  } catch (err) {
    return null;
  }
}

function chemicalIsBanned(chemical) {
  if (!chemical) return false;
  const lower = String(chemical).toLowerCase();
  return BANNED_CHEMICALS.some((b) => lower.includes(b));
}

function looksLikeBrand(chemical) {
  if (!chemical) return false;
  // Heuristic: brand names often have a digit suffix or trailing capital ("M-45")
  // Hard to be perfect; we just flag the obvious shapes.
  return /[A-Z]+[-\s]?\d+/.test(chemical);
}

function validateItem(item, profile) {
  const reasons = [];
  if (!item || typeof item !== 'object') return { ok: false, reasons: ['not_an_object'] };

  const cropEntryId = item.cropEntryId ? String(item.cropEntryId) : null;
  const matchingCrop = (profile?.crops || []).find(
    (c) => String(c._id) === cropEntryId
  );
  if (!matchingCrop) reasons.push('cropEntryId_unknown');

  if (!VERBS.includes(item.verb)) reasons.push('verb_not_in_enum');

  if (!item.title || typeof item.title !== 'string') reasons.push('title_missing');
  else if (item.title.length > 200) reasons.push('title_too_long');

  if (item.detail && (typeof item.detail !== 'string' || item.detail.length > 600)) {
    reasons.push('detail_too_long');
  }

  if (item.chemical) {
    if (typeof item.chemical !== 'string') reasons.push('chemical_not_string');
    else if (chemicalIsBanned(item.chemical)) reasons.push('chemical_banned');
    else if (looksLikeBrand(item.chemical)) reasons.push('chemical_looks_like_brand');
  }

  if (item.dose) {
    if (typeof item.dose !== 'string') reasons.push('dose_not_string');
    else if (!DOSE_RE.test(item.dose)) reasons.push('dose_pattern_invalid');
  }

  if (item.safetyNote && (typeof item.safetyNote !== 'string' || item.safetyNote.length > 200)) {
    reasons.push('safetyNote_too_long');
  }

  if (!URGENCIES.includes(item.urgency)) reasons.push('urgency_not_in_enum');

  if (!Array.isArray(item.rationaleTags)) reasons.push('rationaleTags_not_array');
  else {
    const bad = item.rationaleTags.find(
      (t) => typeof t !== 'string' || !SNAKE_TAG_RE.test(t)
    );
    if (bad) reasons.push('rationaleTags_bad_shape');
    if (item.rationaleTags.length > 8) reasons.push('rationaleTags_too_many');
  }

  if (reasons.length > 0) return { ok: false, reasons };

  return {
    ok: true,
    item: {
      cropEntryId,
      cropName: matchingCrop.cropName,
      cropVariety: matchingCrop.variety || undefined,
      verb: item.verb,
      title: item.title.trim(),
      detail: item.detail ? item.detail.trim() : '',
      chemical: item.chemical ? item.chemical.trim() : undefined,
      dose: item.dose ? item.dose.trim() : undefined,
      safetyNote: item.safetyNote ? item.safetyNote.trim() : undefined,
      urgency: item.urgency,
      rationaleTags: item.rationaleTags.slice(0, 8),
    },
  };
}

/**
 * Parse the model's text response and return a clean array of valid items
 * plus a per-rejection-reason histogram.
 */
function parseAndValidate(rawText, profile) {
  const parsed = safeParseJson(rawText);
  const result = {
    valid: [],
    rejected: [],
    reasonsHistogram: {},
    parseFailed: false,
  };
  if (!parsed) {
    result.parseFailed = true;
    return result;
  }
  const items = Array.isArray(parsed.items) ? parsed.items : [];
  for (const raw of items) {
    const v = validateItem(raw, profile);
    if (v.ok) {
      result.valid.push(v.item);
    } else {
      result.rejected.push({ raw, reasons: v.reasons });
      for (const r of v.reasons) {
        result.reasonsHistogram[r] = (result.reasonsHistogram[r] || 0) + 1;
      }
    }
  }
  // Cap to 3 items max even if model returned more
  if (result.valid.length > 3) {
    result.rejected.push(
      ...result.valid.slice(3).map((it) => ({ raw: it, reasons: ['exceeds_global_cap'] }))
    );
    result.valid = result.valid.slice(0, 3);
  }
  return result;
}

module.exports = {
  parseAndValidate,
  validateItem,
  safeParseJson,
  chemicalIsBanned,
  looksLikeBrand,
  DOSE_RE,
};

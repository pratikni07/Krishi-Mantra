const crypto = require('crypto');

function sha1(input) {
  return crypto.createHash('sha1').update(input).digest('hex');
}

function canonicalJSON(value) {
  if (value === null || typeof value !== 'object') return JSON.stringify(value);
  if (Array.isArray(value)) return '[' + value.map(canonicalJSON).join(',') + ']';
  const keys = Object.keys(value).sort();
  return '{' + keys.map((k) => JSON.stringify(k) + ':' + canonicalJSON(value[k])).join(',') + '}';
}

function round2(n) {
  return typeof n === 'number' ? Math.round(n * 100) / 100 : n;
}

function farmProfile(profile) {
  const coords = profile.location?.coordinates || [];
  const canonical = {
    age: profile.age ?? null,
    gender: profile.gender ?? null,
    language: profile.preferredLanguage || 'en',
    loc: [round2(coords[0]), round2(coords[1])],
    district: profile.address?.district || null,
    state: profile.address?.state || null,
    totalArea: profile.totalArea ?? null,
    totalAreaUnit: profile.totalAreaUnit || null,
    ownership: profile.ownership || null,
    soils: [...(profile.soilTypes || [])].sort(),
    irrig: [...(profile.irrigationSources || [])].sort(),
    exp: profile.experienceYears ?? 0,
    crops: (profile.crops || [])
      .filter((c) => c.isActive !== false)
      .map((c) => ({
        cropId: String(c.cropId || ''),
        variety: c.variety || null,
        area: c.area ?? null,
        areaUnit: c.areaUnit || null,
        sowingDate: c.sowingDate ? new Date(c.sowingDate).toISOString().slice(0, 10) : null,
        growthStage: c.growthStage || null,
        planting: c.plantingMethod || null,
        irrigation: c.irrigationMethod || null,
      }))
      .sort((a, b) => (a.cropId > b.cropId ? 1 : -1)),
  };
  return sha1(canonicalJSON(canonical));
}

module.exports = { sha1, canonicalJSON, round2, farmProfile };

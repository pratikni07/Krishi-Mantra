const FarmProfile = require('../model/FarmProfile');
const UserDetail = require('../model/UserDetail');
const Crop = require('../model/CropCalendar/Crop');
const { asyncHandler } = require('../utils');
const { HTTP_STATUS } = require('../utils/constants');

let redis;
try {
  redis = require('../config/redis');
} catch (err) {
  redis = null;
}
const CROP_SEARCH_TTL_SECONDS = 10 * 60;

const UPSERT_FIELDS = [
  'age',
  'gender',
  'preferredLanguage',
  'location',
  'address',
  'totalArea',
  'totalAreaUnit',
  'ownership',
  'soilTypes',
  'irrigationSources',
  'experienceYears',
  'onboardingStatus',
];

const CROP_FIELDS = [
  'cropId',
  'cropName',
  'variety',
  'area',
  'areaUnit',
  'sowingDate',
  'expectedHarvestDate',
  'growthStage',
  'plantingMethod',
  'irrigationMethod',
  'notes',
  'isActive',
];

function pick(obj, keys) {
  const out = {};
  for (const k of keys) if (obj[k] !== undefined) out[k] = obj[k];
  return out;
}

function getUserId(req) {
  return req.user?.id || req.user?._id || req.user?.userId;
}

async function ensureUserDetailPointer(userId, farmProfileId) {
  const detail = await UserDetail.findOne({ userId });
  if (!detail) return;
  if (String(detail.farmProfile) === String(farmProfileId)) return;
  detail.farmProfile = farmProfileId;
  await detail.save();
}

async function publishProfileUpdate(profile) {
  if (!redis || typeof redis.publish !== 'function') return;
  try {
    await redis.publish('farm-profile.updated', {
      userId: String(profile.userId),
      profileId: String(profile._id),
      profileVersion: profile.profileVersion,
      fingerprint: profile.profileFingerprint,
      onboardingStatus: profile.onboardingStatus,
    });
  } catch (err) {
    // best-effort; cache TTL is the fallback
  }
}

exports.getMyProfile = asyncHandler(async (req, res) => {
  const userId = getUserId(req);
  if (!userId) {
    return res
      .status(HTTP_STATUS.UNAUTHORIZED)
      .json({ success: false, message: 'Authentication required' });
  }
  const profile = await FarmProfile.findOne({ userId }).lean();
  return res.status(HTTP_STATUS.OK).json({ success: true, profile: profile || null });
});

exports.upsertProfile = asyncHandler(async (req, res) => {
  const userId = getUserId(req);
  if (!userId) {
    return res
      .status(HTTP_STATUS.UNAUTHORIZED)
      .json({ success: false, message: 'Authentication required' });
  }

  const updates = pick(req.body || {}, UPSERT_FIELDS);

  let profile = await FarmProfile.findOne({ userId });
  if (!profile) {
    profile = new FarmProfile({ userId, ...updates });
  } else {
    Object.assign(profile, updates);
  }
  await profile.save();
  await ensureUserDetailPointer(userId, profile._id);
  publishProfileUpdate(profile);

  return res
    .status(HTTP_STATUS.OK)
    .json({ success: true, profile: profile.toObject() });
});

exports.patchProfile = asyncHandler(async (req, res) => {
  const userId = getUserId(req);
  if (!userId) {
    return res
      .status(HTTP_STATUS.UNAUTHORIZED)
      .json({ success: false, message: 'Authentication required' });
  }

  const updates = pick(req.body || {}, UPSERT_FIELDS);
  if (Object.keys(updates).length === 0) {
    return res
      .status(HTTP_STATUS.BAD_REQUEST)
      .json({ success: false, message: 'No allowed fields to update' });
  }

  const profile = await FarmProfile.findOne({ userId });
  if (!profile) {
    return res
      .status(HTTP_STATUS.NOT_FOUND)
      .json({ success: false, message: 'Farm profile not found' });
  }
  Object.assign(profile, updates);
  await profile.save();
  publishProfileUpdate(profile);

  return res
    .status(HTTP_STATUS.OK)
    .json({ success: true, profile: profile.toObject() });
});

exports.addCrop = asyncHandler(async (req, res) => {
  const userId = getUserId(req);
  if (!userId) {
    return res
      .status(HTTP_STATUS.UNAUTHORIZED)
      .json({ success: false, message: 'Authentication required' });
  }

  const cropPayload = pick(req.body || {}, CROP_FIELDS);
  if (!cropPayload.cropId || !cropPayload.cropName || !cropPayload.sowingDate || cropPayload.area == null) {
    return res.status(HTTP_STATUS.BAD_REQUEST).json({
      success: false,
      message: 'cropId, cropName, area, and sowingDate are required',
    });
  }

  let profile = await FarmProfile.findOne({ userId });
  if (!profile) {
    profile = new FarmProfile({ userId, crops: [cropPayload] });
  } else {
    profile.crops.push(cropPayload);
  }
  await profile.save();
  await ensureUserDetailPointer(userId, profile._id);
  publishProfileUpdate(profile);

  const added = profile.crops[profile.crops.length - 1];
  return res
    .status(HTTP_STATUS.CREATED)
    .json({ success: true, crop: added.toObject ? added.toObject() : added });
});

exports.updateCrop = asyncHandler(async (req, res) => {
  const userId = getUserId(req);
  const { cropEntryId } = req.params;
  if (!userId) {
    return res
      .status(HTTP_STATUS.UNAUTHORIZED)
      .json({ success: false, message: 'Authentication required' });
  }
  const profile = await FarmProfile.findOne({ userId });
  if (!profile) {
    return res
      .status(HTTP_STATUS.NOT_FOUND)
      .json({ success: false, message: 'Farm profile not found' });
  }
  const crop = profile.crops.id(cropEntryId);
  if (!crop) {
    return res
      .status(HTTP_STATUS.NOT_FOUND)
      .json({ success: false, message: 'Crop entry not found' });
  }

  const patches = pick(req.body || {}, CROP_FIELDS);
  Object.assign(crop, patches);
  await profile.save();
  publishProfileUpdate(profile);
  return res
    .status(HTTP_STATUS.OK)
    .json({ success: true, crop: crop.toObject ? crop.toObject() : crop });
});

exports.searchCrops = asyncHandler(async (req, res) => {
  const q = (req.query.q || '').toString().trim();
  const limit = Number(req.query.limit) || 20;
  const cacheKey = `crop-search:${q.toLowerCase()}:${limit}`;

  if (redis) {
    try {
      const cached = await redis.get(cacheKey);
      if (cached) {
        return res.status(HTTP_STATUS.OK).json({
          success: true,
          cached: true,
          crops: JSON.parse(cached),
        });
      }
    } catch (err) {
      // fall through
    }
  }

  const filter = { status: 'active' };
  if (q) {
    const escaped = q.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    filter.name = new RegExp(escaped, 'i');
  }
  const crops = await Crop.find(filter)
    .select('name scientificName growingPeriod imageUrl seasons')
    .limit(limit)
    .lean();

  if (redis) {
    try {
      await redis.setex(cacheKey, CROP_SEARCH_TTL_SECONDS, JSON.stringify(crops));
    } catch (err) {
      // best-effort
    }
  }

  return res.status(HTTP_STATUS.OK).json({ success: true, cached: false, crops });
});

exports.removeCrop = asyncHandler(async (req, res) => {
  const userId = getUserId(req);
  const { cropEntryId } = req.params;
  if (!userId) {
    return res
      .status(HTTP_STATUS.UNAUTHORIZED)
      .json({ success: false, message: 'Authentication required' });
  }
  const profile = await FarmProfile.findOne({ userId });
  if (!profile) {
    return res
      .status(HTTP_STATUS.NOT_FOUND)
      .json({ success: false, message: 'Farm profile not found' });
  }
  const crop = profile.crops.id(cropEntryId);
  if (!crop) {
    return res
      .status(HTTP_STATUS.NOT_FOUND)
      .json({ success: false, message: 'Crop entry not found' });
  }
  crop.isActive = false;
  await profile.save();
  publishProfileUpdate(profile);
  return res.status(HTTP_STATUS.OK).json({ success: true, cropId: cropEntryId });
});

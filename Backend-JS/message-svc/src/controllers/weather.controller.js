const asyncHandler = require('../utils/asyncHandler');
const WeatherService = require('../services/weather.service');
const logger = require('../utils/logger');

// (file kept; usage stats added in a separate ai-stats controller)

exports.get7Day = asyncHandler(async (req, res) => {
  const lat = parseFloat(req.query.lat);
  const lon = parseFloat(req.query.lon);

  if (!Number.isFinite(lat) || !Number.isFinite(lon)) {
    return res
      .status(400)
      .json({ success: false, code: 'BAD_COORDS', message: 'lat and lon query params are required numbers' });
  }
  if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
    return res
      .status(400)
      .json({ success: false, code: 'BAD_COORDS', message: 'lat/lon out of range' });
  }

  try {
    const snap = await WeatherService.get7Day(lat, lon);
    if (!snap) {
      return res
        .status(503)
        .json({ success: false, code: 'WEATHER_UNAVAILABLE', message: 'Weather data unavailable' });
    }
    return res.status(200).json({
      success: true,
      bucket: snap.bucket,
      location: { lat: snap.lat, lon: snap.lon },
      asOf: snap.asOf,
      provider: snap.provider,
      days: snap.days.map((d) => ({
        date: d.date,
        tempMin: d.tempMin,
        tempMax: d.tempMax,
        humidityMean: d.humidityMean,
        rainfallMm: d.rainfallMm,
        windSpeedKmh: d.windSpeedKmh,
        conditionCode: d.conditionCode,
        condition: d.conditionLabel,
      })),
    });
  } catch (err) {
    logger.error('weather.get7Day failed', { error: err.message });
    return res.status(500).json({ success: false, code: 'WEATHER_ERROR', message: err.message });
  }
});

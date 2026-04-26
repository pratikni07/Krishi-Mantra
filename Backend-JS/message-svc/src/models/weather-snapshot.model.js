const mongoose = require('mongoose');

const dayWxSchema = new mongoose.Schema(
  {
    date: { type: Date, required: true },
    tempMin: Number,
    tempMax: Number,
    humidityMean: Number,
    rainfallMm: Number,
    windSpeedKmh: Number,
    conditionCode: Number,
    conditionLabel: String,
  },
  { _id: false }
);

const snapshotSchema = new mongoose.Schema(
  {
    bucket: { type: String, required: true, unique: true, index: true },
    lat: { type: Number, required: true },
    lon: { type: Number, required: true },
    asOf: { type: Date, required: true },
    days: {
      type: [dayWxSchema],
      validate: {
        validator: (v) => Array.isArray(v) && v.length === 7,
        message: 'days must contain exactly 7 entries (D-3..D+3)',
      },
    },
    provider: { type: String, enum: ['open-meteo', 'openweather'], required: true },
    expiresAt: { type: Date, index: { expires: 0 } },
  },
  { timestamps: true }
);

module.exports = mongoose.model('WeatherSnapshot', snapshotSchema);

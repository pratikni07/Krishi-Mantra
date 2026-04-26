const https = require('https');

const BASE_URL = 'https://api.open-meteo.com/v1/forecast';

// WMO weather-code → (label, broad group)
const WMO_LABELS = {
  0: 'clear',
  1: 'mostly-sunny',
  2: 'partly-cloudy',
  3: 'cloudy',
  45: 'fog',
  48: 'fog',
  51: 'light-drizzle',
  53: 'drizzle',
  55: 'heavy-drizzle',
  61: 'light-rain',
  63: 'rain',
  65: 'heavy-rain',
  71: 'light-snow',
  73: 'snow',
  75: 'heavy-snow',
  80: 'light-showers',
  81: 'showers',
  82: 'heavy-showers',
  95: 'thunderstorm',
  96: 'thunderstorm-hail',
  99: 'thunderstorm-hail',
};

function labelFor(code) {
  return WMO_LABELS[code] || 'unknown';
}

function getJSON(url, { timeoutMs = 10_000 } = {}) {
  return new Promise((resolve, reject) => {
    const req = https.get(url, (res) => {
      let body = '';
      res.on('data', (c) => (body += c));
      res.on('end', () => {
        if (res.statusCode && res.statusCode >= 400) {
          return reject(
            Object.assign(new Error(`open-meteo ${res.statusCode}`), {
              status: res.statusCode,
              body,
            })
          );
        }
        try {
          resolve(JSON.parse(body));
        } catch (err) {
          reject(new Error('open-meteo: invalid JSON response'));
        }
      });
    });
    req.on('error', reject);
    req.setTimeout(timeoutMs, () => {
      req.destroy(new Error('open-meteo: request timeout'));
    });
  });
}

async function fetch(lat, lon) {
  const params = new URLSearchParams({
    latitude: String(lat),
    longitude: String(lon),
    past_days: '3',
    forecast_days: '4',
    daily:
      'temperature_2m_max,temperature_2m_min,precipitation_sum,relative_humidity_2m_mean,wind_speed_10m_max,weather_code',
    timezone: 'auto',
  });

  const url = `${BASE_URL}?${params.toString()}`;
  const data = await getJSON(url);

  if (!data?.daily?.time || data.daily.time.length !== 7) {
    throw new Error(
      `open-meteo returned ${data?.daily?.time?.length ?? 0} days; expected 7 (D-3..D+3)`
    );
  }

  const days = data.daily.time.map((dateStr, i) => ({
    date: new Date(`${dateStr}T00:00:00Z`),
    tempMin: data.daily.temperature_2m_min[i],
    tempMax: data.daily.temperature_2m_max[i],
    humidityMean: data.daily.relative_humidity_2m_mean?.[i] ?? null,
    rainfallMm: data.daily.precipitation_sum[i],
    windSpeedKmh: data.daily.wind_speed_10m_max?.[i] ?? null,
    conditionCode: data.daily.weather_code[i],
    conditionLabel: labelFor(data.daily.weather_code[i]),
  }));

  return { days, provider: 'open-meteo' };
}

module.exports = { fetch, labelFor };

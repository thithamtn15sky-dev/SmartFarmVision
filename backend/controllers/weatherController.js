const { describeWeatherCode, assessPoultryComfort } = require('../constants/poultryComfort');

// Open-Meteo: API thời tiết MIỄN PHÍ, không cần API key, không cần đăng ký.
const GEOCODING_URL = 'https://geocoding-api.open-meteo.com/v1/search';
const FORECAST_URL = 'https://api.open-meteo.com/v1/forecast';

// Thành phố mặc định của trang trại, đổi bằng biến môi trường FARM_CITY nếu cần.
const DEFAULT_CITY = process.env.FARM_CITY || 'Ho Chi Minh';

// Cache ngắn để không gọi lại API cho mỗi lần mở app (thời tiết cập nhật 15 phút/lần).
const CACHE_TTL_MS = 10 * 60 * 1000;
const cache = new Map();

async function fetchJson(url, timeoutMs = 8000) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
        const response = await fetch(url, { signal: controller.signal });
        if (!response.ok) {
            throw new Error(`Dịch vụ thời tiết trả về HTTP ${response.status}`);
        }
        return await response.json();
    } finally {
        clearTimeout(timer);
    }
}

// Bỏ dấu tiếng Việt: bộ geocoding của Open-Meteo khớp tên không dấu chính xác
// hơn nhiều - ví dụ "Đà Lạt" bị trả nhầm thành "Đã Tịch", còn "Da Lat" thì đúng.
function removeVietnameseTones(str) {
    return str
        .normalize('NFD')
        .replace(/[̀-ͯ]/g, '')
        .replace(/đ/g, 'd')
        .replace(/Đ/g, 'D');
}

async function searchPlace(name) {
    const url = `${GEOCODING_URL}?name=${encodeURIComponent(name)}&count=1&language=vi&format=json`;
    const json = await fetchJson(url);
    return (json.results && json.results[0]) || null;
}

// Đổi tên thành phố sang tọa độ (cũng là API miễn phí của Open-Meteo).
async function geocodeCity(city) {
    const ascii = removeVietnameseTones(city);
    // Ưu tiên bản không dấu, nếu không ra kết quả mới thử lại nguyên văn.
    let place = await searchPlace(ascii);
    if (!place && ascii !== city) {
        place = await searchPlace(city);
    }
    if (!place) {
        throw new Error(`Không tìm thấy thành phố "${city}".`);
    }
    return {
        city: place.name,
        country: place.country || null,
        admin: place.admin1 || null,
        latitude: place.latitude,
        longitude: place.longitude,
        timezone: place.timezone || 'auto',
    };
}

// ==========================================
// GET /api/weather/current?city=... hoặc ?lat=&lon=
// ==========================================
exports.getCurrentWeather = async (req, res) => {
    try {
        const { city, lat, lon } = req.query;

        let location;
        if (lat && lon) {
            location = {
                city: city || 'Vị trí trang trại',
                country: null,
                admin: null,
                latitude: Number(lat),
                longitude: Number(lon),
                timezone: 'auto',
            };
            if (isNaN(location.latitude) || isNaN(location.longitude)) {
                return res.status(400).json({ success: false, message: 'lat/lon không hợp lệ.' });
            }
        } else {
            location = await geocodeCity(city || DEFAULT_CITY);
        }

        const cacheKey = `${location.latitude.toFixed(2)},${location.longitude.toFixed(2)}`;
        const cached = cache.get(cacheKey);
        if (cached && Date.now() - cached.at < CACHE_TTL_MS) {
            return res.status(200).json({ success: true, cached: true, data: cached.data });
        }

        const params = new URLSearchParams({
            latitude: location.latitude,
            longitude: location.longitude,
            current: 'temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m,is_day',
            timezone: location.timezone,
        });
        const forecast = await fetchJson(`${FORECAST_URL}?${params.toString()}`);
        const current = forecast.current;
        if (!current) {
            throw new Error('Dịch vụ thời tiết không trả về dữ liệu hiện tại.');
        }

        const weatherCode = current.weather_code ?? 0;
        const { condition, icon } = describeWeatherCode(weatherCode);
        const temperature = current.temperature_2m;
        const humidity = current.relative_humidity_2m;

        const data = {
            location: {
                city: location.city,
                admin: location.admin,
                country: location.country,
                latitude: location.latitude,
                longitude: location.longitude,
            },
            observed_at: current.time,
            temperature,
            feels_like: current.apparent_temperature,
            humidity,
            precipitation: current.precipitation ?? 0,
            wind_speed: current.wind_speed_10m ?? 0,
            weather_code: weatherCode,
            condition,
            icon,
            is_day: current.is_day === 1,
            comfort: assessPoultryComfort({
                temperature,
                humidity,
                precipitation: current.precipitation ?? 0,
                windSpeed: current.wind_speed_10m ?? 0,
                weatherCode,
            }),
            source: 'Open-Meteo (miễn phí, không cần API key)',
        };

        cache.set(cacheKey, { at: Date.now(), data });
        res.status(200).json({ success: true, cached: false, data });
    } catch (error) {
        res.status(502).json({ success: false, message: error.message });
    }
};

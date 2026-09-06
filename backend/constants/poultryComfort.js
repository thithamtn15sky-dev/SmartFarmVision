// Quy đổi thời tiết sang mức độ phù hợp cho chuồng gia cầm.
//
// Dùng chỉ số THI (Temperature-Humidity Index) - chỉ số chuẩn trong chăn nuôi
// để đánh giá stress nhiệt, vì gia cầm không có tuyến mồ hôi nên độ ẩm cao
// làm mất khả năng thải nhiệt dù nhiệt độ chưa quá cao.
//
//   THI = 0.8 x T + RH x (T - 14.4) / 100 + 46.4     (T: °C, RH: %)

const THI_LEVELS = {
  COMFORT: { max: 74, label: 'An toàn', suitable: true },
  ALERT: { max: 79, label: 'Cảnh báo', suitable: false },
  DANGER: { max: 84, label: 'Nguy hiểm', suitable: false },
  EMERGENCY: { max: Infinity, label: 'Khẩn cấp', suitable: false },
};

// Ngưỡng môi trường lý tưởng cho gia cầm trưởng thành.
const IDEAL = {
  tempMin: 18,
  tempMax: 27,
  humidityMin: 50,
  humidityMax: 75,
};

// Bảng mã thời tiết WMO của Open-Meteo -> mô tả tiếng Việt + khóa icon.
const WMO_CODES = {
  0: { condition: 'Trời quang', icon: 'sunny' },
  1: { condition: 'Trời gần quang', icon: 'sunny' },
  2: { condition: 'Trời có mây', icon: 'partly_cloudy' },
  3: { condition: 'Trời nhiều mây', icon: 'cloudy' },
  45: { condition: 'Sương mù', icon: 'fog' },
  48: { condition: 'Sương mù đóng băng', icon: 'fog' },
  51: { condition: 'Mưa phùn nhẹ', icon: 'drizzle' },
  53: { condition: 'Mưa phùn', icon: 'drizzle' },
  55: { condition: 'Mưa phùn dày', icon: 'drizzle' },
  56: { condition: 'Mưa phùn lạnh', icon: 'drizzle' },
  57: { condition: 'Mưa phùn lạnh dày', icon: 'drizzle' },
  61: { condition: 'Mưa nhỏ', icon: 'rain' },
  63: { condition: 'Mưa vừa', icon: 'rain' },
  65: { condition: 'Mưa to', icon: 'heavy_rain' },
  66: { condition: 'Mưa lạnh', icon: 'rain' },
  67: { condition: 'Mưa lạnh nặng hạt', icon: 'heavy_rain' },
  71: { condition: 'Tuyết nhẹ', icon: 'snow' },
  73: { condition: 'Tuyết', icon: 'snow' },
  75: { condition: 'Tuyết dày', icon: 'snow' },
  77: { condition: 'Hạt tuyết', icon: 'snow' },
  80: { condition: 'Mưa rào nhẹ', icon: 'rain' },
  81: { condition: 'Mưa rào', icon: 'rain' },
  82: { condition: 'Mưa rào rất to', icon: 'heavy_rain' },
  85: { condition: 'Mưa tuyết nhẹ', icon: 'snow' },
  86: { condition: 'Mưa tuyết dày', icon: 'snow' },
  95: { condition: 'Dông', icon: 'thunderstorm' },
  96: { condition: 'Dông kèm mưa đá', icon: 'thunderstorm' },
  99: { condition: 'Dông kèm mưa đá lớn', icon: 'thunderstorm' },
};

function describeWeatherCode(code) {
  return WMO_CODES[code] || { condition: 'Không rõ', icon: 'cloudy' };
}

function calcTHI(temperature, humidity) {
  return 0.8 * temperature + (humidity * (temperature - 14.4)) / 100 + 46.4;
}

function classifyTHI(thi) {
  for (const [level, config] of Object.entries(THI_LEVELS)) {
    if (thi < config.max) return { level, ...config };
  }
  return { level: 'EMERGENCY', ...THI_LEVELS.EMERGENCY };
}

// Sinh khuyến nghị cụ thể cho người nuôi dựa trên từng yếu tố môi trường.
function buildAdvices({ temperature, humidity, precipitation, windSpeed, weatherCode, thiLevel }) {
  const advices = [];

  if (thiLevel === 'EMERGENCY' || thiLevel === 'DANGER') {
    advices.push('Bật toàn bộ quạt thông gió và hệ thống làm mát, tránh để đàn dồn góc chuồng.');
    advices.push('Cấp nước mát liên tục, có thể bổ sung điện giải và vitamin C chống stress nhiệt.');
    advices.push('Không vận chuyển, cân hay tiêm phòng vào lúc này - dời sang sáng sớm hoặc chiều tối.');
  } else if (thiLevel === 'ALERT') {
    advices.push('Tăng thông gió và bảo đảm nước uống luôn mát, theo dõi đàn có há mỏ thở gấp không.');
    advices.push('Nên dời việc tiêm phòng, cân đo sang sáng sớm cho đỡ stress.');
  }

  if (temperature > IDEAL.tempMax) {
    advices.push(`Nhiệt độ ${temperature}°C cao hơn ngưỡng lý tưởng (${IDEAL.tempMin}-${IDEAL.tempMax}°C), giãn mật độ nuôi nếu chuồng chật.`);
  } else if (temperature < IDEAL.tempMin) {
    advices.push(`Nhiệt độ ${temperature}°C thấp, cần che chắn gió lùa và sưởi ấm cho gà con.`);
  }

  if (humidity > IDEAL.humidityMax) {
    advices.push(`Độ ẩm ${humidity}% khá cao: thay chất độn chuồng ẩm, đề phòng khí ammonia và bệnh cầu trùng.`);
  } else if (humidity < IDEAL.humidityMin) {
    advices.push(`Độ ẩm ${humidity}% thấp, dễ sinh bụi gây bệnh hô hấp - có thể phun sương tạo ẩm nhẹ.`);
  }

  if (weatherCode >= 95) {
    advices.push('Đang có dông: kiểm tra mái che, hệ thống điện và chắn gió tạt vào chuồng.');
  } else if (precipitation > 0 || (weatherCode >= 61 && weatherCode <= 82)) {
    advices.push('Trời mưa: kiểm tra dột mái, thoát nước quanh chuồng và giữ nền chuồng khô.');
  }

  if (windSpeed > 30) {
    advices.push(`Gió mạnh ${windSpeed} km/h, cần chắn bạt tránh gió lùa trực tiếp vào đàn.`);
  }

  if (advices.length === 0) {
    advices.push('Điều kiện môi trường đang thuận lợi, duy trì thông gió và nước uống sạch như thường lệ.');
  }

  return advices;
}

// Đánh giá tổng thể môi trường cho chuồng.
function assessPoultryComfort({ temperature, humidity, precipitation = 0, windSpeed = 0, weatherCode = 0 }) {
  const thi = calcTHI(temperature, humidity);
  const classification = classifyTHI(thi);

  const headlines = {
    COMFORT: 'Thời tiết phù hợp cho chuồng',
    ALERT: 'Đàn bắt đầu chịu stress nhiệt',
    DANGER: 'Nguy cơ stress nhiệt cao',
    EMERGENCY: 'Cảnh báo khẩn cấp - stress nhiệt nghiêm trọng',
  };

  return {
    thi: Math.round(thi * 10) / 10,
    level: classification.level,
    label: classification.label,
    headline: headlines[classification.level],
    suitable_for_coop: classification.suitable,
    ideal_range: IDEAL,
    advices: buildAdvices({
      temperature,
      humidity,
      precipitation,
      windSpeed,
      weatherCode,
      thiLevel: classification.level,
    }),
  };
}

module.exports = {
  IDEAL,
  describeWeatherCode,
  calcTHI,
  assessPoultryComfort,
};

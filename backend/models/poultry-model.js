const mongoose = require('mongoose');

const poultrySchema = new mongoose.Schema({
    poultryId: { type: String, required: true, unique: true },
    type: { type: String, required: true },
    ageInDays: { type: Number },
    healthStatus: { type: String, default: 'Khỏe mạnh' },
    lastScannedAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Poultry', poultrySchema);
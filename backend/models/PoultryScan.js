const mongoose = require('mongoose');

const predictionSchema = new mongoose.Schema({
  diseaseName: String,
  confidenceScore: Number
}, { _id: false });

const symptomSchema = new mongoose.Schema({
  bodyPart: String,
  condition: String
}, { _id: false });

const adviceSchema = new mongoose.Schema({
  noiDung: String,
  nguon: [String]
}, { _id: false });

const poultryScanSchema = new mongoose.Schema({
  scannedAt: { type: Date, default: Date.now },
  basicInfo: {
    poultryType: String,
    currentStatus: String
  },
  media: {
    imageUrls: [String]
  },
  clinicalFindings: {
    generalDescription: String,
    symptoms: [symptomSchema]
  },
  aiDiagnosis: {
    predictions: [predictionSchema],
    suggestedTreatment: String,
    requiresExpertReview: Boolean,
    // Lời khuyên do model tự viết dựa trên tài liệu BenhGiaCam (RAG),
    // kèm URL nguồn đã được đối chiếu lại với DB nên không có link bịa.
    dieuTri: [adviceSchema],
    phongNgua: [adviceSchema],
    referenceUrls: [String]
  },
  humanVerification: {
    isVerified: Boolean,
    verifiedDisease: String,
    verifiedBy: String
  },
  syncStatus: String,
  flockId: String
});

module.exports = mongoose.model('PoultryScan', poultryScanSchema);

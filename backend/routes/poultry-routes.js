const express = require('express');
const router = express.Router();
const poultryController = require('../controllers/poultry-controller');

// POST /api/poultry/add
router.post('/add', poultryController.createPoultryProfile);

module.exports = router;
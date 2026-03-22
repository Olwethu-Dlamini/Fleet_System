// ============================================
// FILE: src/routes/vehicles.js
// CHANGES: Added POST (create), PUT (update), DELETE (delete/deactivate)
//          All write endpoints require admin role.
// ============================================

const express = require('express');
const router  = express.Router();
const Vehicle = require('../models/Vehicle');
const { verifyToken, adminOnly } = require('../middleware/authMiddleware');
const { body }  = require('express-validator');
const validate  = require('../middleware/validate');

// verifyToken + adminOnly bundled so every write route is self-contained.
// verifyToken populates req.user; adminOnly checks req.user.role === 'admin'.
const requireAdmin = [verifyToken, adminOnly];

// ============================================
// Validation schemas — FOUND-06
// ============================================
const createVehicleValidation = [
  body('vehicle_name')
    .isString().trim().isLength({ min: 2, max: 100 })
    .withMessage('vehicle_name must be 2-100 characters'),
  body('license_plate')
    .isString().trim().notEmpty()
    .withMessage('license_plate is required'),
  body('type')
    .optional().isString().trim().isLength({ max: 50 })
    .withMessage('type must be 50 characters or less'),
  body('capacity')
    .optional().isInt({ min: 1 })
    .withMessage('capacity must be a positive integer'),
];

const updateVehicleValidation = [
  body('vehicle_name')
    .optional().isString().trim().isLength({ min: 2, max: 100 })
    .withMessage('vehicle_name must be 2-100 characters'),
  body('license_plate')
    .optional().isString().trim().notEmpty()
    .withMessage('license_plate cannot be empty'),
  body('status')
    .optional().isIn(['available', 'assigned', 'maintenance', 'inactive'])
    .withMessage('status must be available, assigned, maintenance, or inactive'),
];

// ============================================================
// GET /api/vehicles
// ============================================================
router.get('/', async (req, res) => {
  try {
    const vehicles = await Vehicle.getAllVehicles(req.query.activeOnly === 'true');
    res.json({ success: true, data: vehicles, count: vehicles.length });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// ============================================================
// GET /api/vehicles/:id
// ============================================================
router.get('/:id', async (req, res) => {
  try {
    const vehicle = await Vehicle.getVehicleById(parseInt(req.params.id));
    if (!vehicle) return res.status(404).json({ success: false, error: 'Vehicle not found' });
    res.json({ success: true, data: vehicle });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// ============================================================
// POST /api/vehicles  —  create  (admin only)
// Body: { vehicle_name, license_plate, vehicle_type, capacity_kg?, notes? }
// ============================================================
router.post('/', requireAdmin, createVehicleValidation, validate, async (req, res) => {
  try {
    const { vehicle_name, license_plate, vehicle_type, capacity_kg, notes } = req.body;

    if (!vehicle_name || !license_plate || !vehicle_type) {
      return res.status(400).json({
        success: false,
        message: 'vehicle_name, license_plate, and vehicle_type are required',
      });
    }

    const validTypes = ['van', 'truck', 'car'];
    if (!validTypes.includes(vehicle_type)) {
      return res.status(400).json({
        success: false,
        message: `vehicle_type must be one of: ${validTypes.join(', ')}`,
      });
    }

    const vehicle = await Vehicle.createVehicle({
      vehicle_name,
      license_plate,
      vehicle_type,
      capacity_kg:  capacity_kg ?? null,
      notes:        notes       ?? null,
    });

    res.status(201).json({
      success: true,
      data:    vehicle,
      message: 'Vehicle created successfully',
    });
  } catch (error) {
    if (error.message?.includes('already exists')) {
      return res.status(409).json({ success: false, message: error.message });
    }
    res.status(400).json({ success: false, error: error.message });
  }
});

// ============================================================
// PUT /api/vehicles/:id  —  update  (admin only)
// Body: any subset of { vehicle_name, license_plate, vehicle_type,
//                       capacity_kg, is_active, last_maintenance_date, notes }
// ============================================================
router.put('/:id', requireAdmin, updateVehicleValidation, validate, async (req, res) => {
  try {
    const id = parseInt(req.params.id);

    const existing = await Vehicle.getVehicleById(id);
    if (!existing) {
      return res.status(404).json({ success: false, message: 'Vehicle not found' });
    }

    const updated = await Vehicle.updateVehicle(id, req.body);
    res.json({
      success: true,
      data:    updated,
      message: 'Vehicle updated successfully',
    });
  } catch (error) {
    if (error.message?.includes('already exists')) {
      return res.status(409).json({ success: false, message: error.message });
    }
    res.status(400).json({ success: false, error: error.message });
  }
});

// ============================================================
// DELETE /api/vehicles/:id  —  soft-delete / deactivate  (admin only)
// If vehicle has assignments → sets is_active = 0 (preserves history).
// If no assignments → physically removes the row.
// ============================================================
router.delete('/:id', requireAdmin, async (req, res) => {
  try {
    const id     = parseInt(req.params.id);
    const result = await Vehicle.deleteVehicle(id);
    res.json({ success: true, ...result });
  } catch (error) {
    if (error.message?.includes('not found')) {
      return res.status(404).json({ success: false, message: error.message });
    }
    res.status(500).json({ success: false, error: error.message });
  }
});

module.exports = router;
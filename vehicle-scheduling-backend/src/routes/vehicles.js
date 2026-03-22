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

/**
 * @swagger
 * /vehicles:
 *   get:
 *     tags: [Vehicles]
 *     summary: List all vehicles
 *     description: Returns all vehicles. Pass activeOnly=true to exclude deactivated vehicles.
 *     parameters:
 *       - in: query
 *         name: activeOnly
 *         schema:
 *           type: string
 *           enum: ['true', 'false']
 *         description: If 'true', returns only active vehicles
 *     responses:
 *       200:
 *         description: Vehicle list retrieved
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Vehicle'
 *                 count:
 *                   type: integer
 *                   example: 5
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
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

/**
 * @swagger
 * /vehicles/{id}:
 *   get:
 *     tags: [Vehicles]
 *     summary: Get a vehicle by ID
 *     description: Returns a single vehicle record by its ID.
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: Vehicle ID
 *     responses:
 *       200:
 *         description: Vehicle found
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   $ref: '#/components/schemas/Vehicle'
 *       404:
 *         description: Vehicle not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
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

/**
 * @swagger
 * /vehicles:
 *   post:
 *     tags: [Vehicles]
 *     summary: Create a vehicle (admin only)
 *     description: Creates a new vehicle record. Requires admin role. License plate must be unique.
 *     security:
 *       - ApiKeyAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [vehicle_name, license_plate, vehicle_type]
 *             properties:
 *               vehicle_name:
 *                 type: string
 *                 example: Ford Transit 001
 *               license_plate:
 *                 type: string
 *                 example: GP 123 ABC
 *               vehicle_type:
 *                 type: string
 *                 enum: [van, truck, car]
 *                 example: van
 *               capacity_kg:
 *                 type: number
 *                 example: 1000
 *               notes:
 *                 type: string
 *                 example: Requires 95 unleaded
 *     responses:
 *       201:
 *         description: Vehicle created
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   $ref: '#/components/schemas/Vehicle'
 *                 message:
 *                   type: string
 *                   example: Vehicle created successfully
 *       400:
 *         description: Validation error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       403:
 *         description: Admin role required
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       409:
 *         description: License plate already exists
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
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

/**
 * @swagger
 * /vehicles/{id}:
 *   put:
 *     tags: [Vehicles]
 *     summary: Update a vehicle (admin only)
 *     description: Updates vehicle fields. Only provided fields are changed. Requires admin role.
 *     security:
 *       - ApiKeyAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: Vehicle ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               vehicle_name:
 *                 type: string
 *                 example: Ford Transit 001 (Updated)
 *               license_plate:
 *                 type: string
 *                 example: GP 999 XYZ
 *               status:
 *                 type: string
 *                 enum: [available, assigned, maintenance, inactive]
 *               is_active:
 *                 type: boolean
 *                 example: true
 *     responses:
 *       200:
 *         description: Vehicle updated
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   $ref: '#/components/schemas/Vehicle'
 *                 message:
 *                   type: string
 *                   example: Vehicle updated successfully
 *       400:
 *         description: Validation error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       403:
 *         description: Admin role required
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       404:
 *         description: Vehicle not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       409:
 *         description: License plate already exists
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
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

/**
 * @swagger
 * /vehicles/{id}:
 *   delete:
 *     tags: [Vehicles]
 *     summary: Delete or deactivate a vehicle (admin only)
 *     description: If the vehicle has existing assignments, it is soft-deleted (is_active=0) to preserve history. If no assignments exist, the row is physically removed. Requires admin role.
 *     security:
 *       - ApiKeyAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: Vehicle ID
 *     responses:
 *       200:
 *         description: Vehicle deleted or deactivated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/SuccessResponse'
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       403:
 *         description: Admin role required
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       404:
 *         description: Vehicle not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
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
// ============================================
// FILE: src/middleware/validate.js
// PURPOSE: Shared express-validator result handler
// Usage: Apply AFTER validation chains in route definitions
// Requirements: FOUND-06
// ============================================
const { validationResult } = require('express-validator');

/**
 * validate middleware
 * Must be placed AFTER express-validator chain arrays in route definition.
 * Returns 400 with field-level errors if any validation fails.
 * Calls next() if all validations pass.
 *
 * Usage example:
 *   router.post('/', verifyToken, createJobValidation, validate, controller.create);
 */
const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: 'Validation failed',
      errors: errors.array(),   // Array of { type, msg, path, location }
    });
  }
  next();
};

module.exports = validate;

// ============================================
// FILE: src/config/swagger.js
// PURPOSE: Swagger/OpenAPI documentation configuration
// ============================================
const swaggerJSDoc = require('swagger-jsdoc');

// Swagger definition
const swaggerDefinition = {
  openapi: '3.0.0',
  info: {
    title: 'Vehicle Scheduling System API',
    version: '1.0.0',
    description: 'API documentation for the Vehicle Scheduling System backend',
    contact: {
      name: 'API Support',
      email: 'support@example.com'
    }
  },
  servers: [
    {
      url: 'http://localhost:3000/api',
      description: 'Development server'
    }
  ],
  components: {
    securitySchemes: {
      ApiKeyAuth: {
        type: 'apiKey',
        in: 'header',
        name: 'Authorization'
      }
    },
    schemas: {
      Job: {
        type: 'object',
        properties: {
          id: { type: 'integer' },
          job_number: { type: 'string' },
          job_type: { type: 'string', enum: ['installation', 'delivery', 'maintenance'] },
          customer_name: { type: 'string' },
          customer_phone: { type: 'string' },
          customer_address: { type: 'string' },
          description: { type: 'string' },
          scheduled_date: { type: 'string', format: 'date' },
          scheduled_time_start: { type: 'string', format: 'time' },
          scheduled_time_end: { type: 'string', format: 'time' },
          estimated_duration_minutes: { type: 'integer' },
          current_status: { type: 'string', enum: ['pending', 'assigned', 'in_progress', 'completed', 'cancelled'] },
          priority: { type: 'string', enum: ['urgent', 'high', 'normal', 'low'] },
          created_by: { type: 'integer' },
          created_at: { type: 'string', format: 'date-time' },
          updated_at: { type: 'string', format: 'date-time' }
        }
      },
      Vehicle: {
        type: 'object',
        properties: {
          id: { type: 'integer' },
          vehicle_name: { type: 'string' },
          license_plate: { type: 'string' },
          vehicle_type: { type: 'string', enum: ['car', 'van', 'truck'] },
          capacity_kg: { type: 'number' },
          is_active: { type: 'boolean' },
          last_maintenance_date: { type: 'string', format: 'date' },
          notes: { type: 'string' }
        }
      },
      Assignment: {
        type: 'object',
        properties: {
          id: { type: 'integer' },
          job_id: { type: 'integer' },
          vehicle_id: { type: 'integer' },
          driver_id: { type: 'integer' },
          assigned_by: { type: 'integer' },
          assigned_at: { type: 'string', format: 'date-time' },
          notes: { type: 'string' }
        }
      }
    }
  }
};

// Options for the swagger docs
const options = {
  swaggerDefinition,
  apis: ['./src/routes/*.js', './src/controllers/*.js'],
};

// Initialize swagger-jsdoc
const swaggerSpec = swaggerJSDoc(options);

module.exports = swaggerSpec;
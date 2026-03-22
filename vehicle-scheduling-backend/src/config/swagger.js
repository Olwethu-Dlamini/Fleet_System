// ============================================
// FILE: src/config/swagger.js
// PURPOSE: Swagger/OpenAPI documentation configuration
// ============================================
const swaggerJSDoc = require('swagger-jsdoc');

// Swagger definition
const swaggerDefinition = {
  openapi: '3.0.0',
  info: {
    title: 'FleetScheduler Pro API',
    version: '1.0.0',
    description: 'REST API for FleetScheduler Pro — a vehicle and fleet scheduling platform for service companies. Admins and schedulers assign jobs to drivers and technicians, track vehicles, manage maintenance, and monitor field operations in real-time via GPS.',
    contact: {
      name: 'API Support',
      email: 'support@fleetschedulerpro.com'
    }
  },
  servers: [
    {
      url: 'http://localhost:3000/api',
      description: 'Development server'
    }
  ],
  tags: [
    { name: 'Authentication', description: 'Login, logout, and current user endpoints' },
    { name: 'Jobs', description: 'Job CRUD, assignment of drivers, schedule management' },
    { name: 'Vehicles', description: 'Vehicle CRUD — admin only for write operations' },
    { name: 'Job Assignments', description: 'Assign vehicles and drivers to jobs, check conflicts, view load balancing' },
    { name: 'Job Status', description: 'Status transitions, history, and completion with GPS capture' },
    { name: 'Dashboard', description: 'Summary stats, quick counts, and hourly chart data' },
    { name: 'Reports', description: 'Analytics and reporting — requires admin or scheduler role' },
    { name: 'Users', description: 'User management — admin only for write operations' },
    { name: 'Availability', description: 'Pre-flight availability checks for drivers and vehicles' },
    { name: 'Vehicle Maintenance', description: 'Maintenance scheduling and history per vehicle' },
    { name: 'Settings', description: 'Key-value admin settings store — admin only' },
    { name: 'Notifications', description: 'In-app notification centre with read/unread tracking and preferences' },
    { name: 'Time Extensions', description: 'Technician time extension requests with smart rescheduling suggestions' },
    { name: 'GPS', description: 'Live driver tracking, directions, consent management' },
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
          id: { type: 'integer', example: 1 },
          job_number: { type: 'string', example: 'JOB-0042' },
          job_type: { type: 'string', enum: ['installation', 'delivery', 'miscellaneous'], example: 'installation' },
          customer_name: { type: 'string', example: 'Acme Corp' },
          customer_phone: { type: 'string', example: '+27821234567' },
          customer_address: { type: 'string', example: '123 Main St, Johannesburg' },
          description: { type: 'string', example: 'Install HVAC unit in server room' },
          destination_lat: { type: 'number', example: -26.2041 },
          destination_lng: { type: 'number', example: 28.0473 },
          scheduled_date: { type: 'string', format: 'date', example: '2026-03-25' },
          scheduled_time_start: { type: 'string', example: '09:00:00' },
          scheduled_time_end: { type: 'string', example: '11:00:00' },
          estimated_duration_minutes: { type: 'integer', example: 120 },
          current_status: { type: 'string', enum: ['pending', 'assigned', 'in_progress', 'completed', 'cancelled'], example: 'assigned' },
          priority: { type: 'string', enum: ['urgent', 'high', 'normal', 'low'], example: 'normal' },
          created_by: { type: 'integer', example: 1 },
          created_at: { type: 'string', format: 'date-time' },
          updated_at: { type: 'string', format: 'date-time' }
        }
      },
      Vehicle: {
        type: 'object',
        properties: {
          id: { type: 'integer', example: 1 },
          vehicle_name: { type: 'string', example: 'Ford Transit 001' },
          license_plate: { type: 'string', example: 'GP 123 ABC' },
          vehicle_type: { type: 'string', enum: ['car', 'van', 'truck'], example: 'van' },
          capacity_kg: { type: 'number', example: 1000 },
          is_active: { type: 'boolean', example: true },
          last_maintenance_date: { type: 'string', format: 'date', example: '2026-01-15' },
          notes: { type: 'string', example: 'Requires 95 unleaded fuel' }
        }
      },
      Assignment: {
        type: 'object',
        properties: {
          id: { type: 'integer', example: 1 },
          job_id: { type: 'integer', example: 5 },
          vehicle_id: { type: 'integer', example: 2 },
          driver_id: { type: 'integer', example: 3 },
          assigned_by: { type: 'integer', example: 1 },
          assigned_at: { type: 'string', format: 'date-time' },
          notes: { type: 'string', example: 'Priority delivery' }
        }
      },
      User: {
        type: 'object',
        properties: {
          id: { type: 'integer', example: 1 },
          username: { type: 'string', example: 'jdoe' },
          full_name: { type: 'string', example: 'John Doe' },
          email: { type: 'string', format: 'email', example: 'jdoe@fleet.com' },
          role: { type: 'string', enum: ['admin', 'scheduler', 'technician'], example: 'technician' },
          is_active: { type: 'boolean', example: true },
          contact_phone: { type: 'string', example: '+27821234567' },
          contact_phone_secondary: { type: 'string', example: '+27831234567' },
          created_at: { type: 'string', format: 'date-time' }
        }
      },
      Maintenance: {
        type: 'object',
        properties: {
          id: { type: 'integer', example: 1 },
          vehicle_id: { type: 'integer', example: 2 },
          vehicle_name: { type: 'string', example: 'Ford Transit 001' },
          maintenance_type: { type: 'string', enum: ['oil_change', 'tyre_rotation', 'brake_service', 'full_service', 'other'], example: 'oil_change' },
          other_type_desc: { type: 'string', example: 'Custom bodywork repair' },
          status: { type: 'string', enum: ['scheduled', 'in_progress', 'completed'], example: 'scheduled' },
          start_date: { type: 'string', format: 'date', example: '2026-03-28' },
          end_date: { type: 'string', format: 'date', example: '2026-03-29' },
          notes: { type: 'string', example: 'Oil and filter change at 80,000km service' },
          created_by: { type: 'integer', example: 1 },
          created_at: { type: 'string', format: 'date-time' }
        }
      },
      Notification: {
        type: 'object',
        properties: {
          id: { type: 'integer', example: 1 },
          user_id: { type: 'integer', example: 3 },
          type: { type: 'string', example: 'job_assigned' },
          title: { type: 'string', example: 'New Job Assigned' },
          message: { type: 'string', example: 'You have been assigned to Job JOB-0042' },
          data: { type: 'object', example: { job_id: 42 } },
          is_read: { type: 'boolean', example: false },
          created_at: { type: 'string', format: 'date-time' }
        }
      },
      NotificationPreference: {
        type: 'object',
        properties: {
          user_id: { type: 'integer', example: 3 },
          push_enabled: { type: 'boolean', example: true },
          email_enabled: { type: 'boolean', example: false },
          job_assigned: { type: 'boolean', example: true },
          job_overdue: { type: 'boolean', example: true },
          time_extension: { type: 'boolean', example: true }
        }
      },
      TimeExtensionRequest: {
        type: 'object',
        properties: {
          id: { type: 'integer', example: 1 },
          job_id: { type: 'integer', example: 5 },
          requested_by: { type: 'integer', example: 3 },
          duration_minutes: { type: 'integer', example: 30 },
          reason: { type: 'string', example: 'Water damage discovered under flooring' },
          status: { type: 'string', enum: ['pending', 'approved', 'denied'], example: 'pending' },
          created_at: { type: 'string', format: 'date-time' }
        }
      },
      RescheduleOption: {
        type: 'object',
        properties: {
          id: { type: 'integer', example: 1 },
          type: { type: 'string', example: 'delay' },
          description: { type: 'string', example: 'Delay affected job by 30 minutes' },
          affected_jobs: { type: 'array', items: { type: 'object' } }
        }
      },
      GpsPosition: {
        type: 'object',
        properties: {
          driverId: { type: 'integer', example: 3 },
          driverName: { type: 'string', example: 'jdoe' },
          lat: { type: 'number', example: -26.2041 },
          lng: { type: 'number', example: 28.0473 },
          accuracy_m: { type: 'number', example: 10.5 },
          timestamp: { type: 'string', format: 'date-time' }
        }
      },
      GpsConsent: {
        type: 'object',
        properties: {
          user_id: { type: 'integer', example: 3 },
          tenant_id: { type: 'integer', example: 1 },
          gps_enabled: { type: 'boolean', example: true },
          consented_at: { type: 'string', format: 'date-time' }
        }
      },
      DashboardSummary: {
        type: 'object',
        properties: {
          todayJobs: { type: 'integer', example: 12 },
          pendingJobs: { type: 'integer', example: 4 },
          inProgressJobs: { type: 'integer', example: 3 },
          completedJobs: { type: 'integer', example: 5 },
          cancelledJobs: { type: 'integer', example: 0 },
          activeVehicles: { type: 'integer', example: 7 },
          totalDrivers: { type: 'integer', example: 8 }
        }
      },
      DriverLoad: {
        type: 'object',
        properties: {
          id: { type: 'integer', example: 3 },
          full_name: { type: 'string', example: 'John Doe' },
          job_count: { type: 'integer', example: 2 },
          rank: { type: 'integer', example: 1 },
          below_average: { type: 'boolean', example: true }
        }
      },
      Setting: {
        type: 'object',
        properties: {
          key: { type: 'string', example: 'scheduler_gps_visible' },
          value: { type: 'string', example: 'true' }
        }
      },
      ErrorResponse: {
        type: 'object',
        properties: {
          success: { type: 'boolean', example: false },
          error: { type: 'string', example: 'Validation failed' },
          message: { type: 'string', example: 'Detailed error description' }
        }
      },
      SuccessResponse: {
        type: 'object',
        properties: {
          success: { type: 'boolean', example: true },
          message: { type: 'string', example: 'Operation completed successfully' }
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

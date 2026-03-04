# 🚀 Vehicle Scheduling System - Quick Start Guide

## ✅ Backend is Running!

Your Node.js + Express backend is now live at:
```
http://localhost:3000
```

---

## 📋 Quick Test (In Browser)

Open your browser and visit:
```
http://localhost:3000/api/health
```

You should see:
```json
{
  "status": "OK",
  "timestamp": "2024-02-10T..."
}
```

✅ **If you see this, your server is working!**

---

## 🧪 Testing Methods

### **Method 1: VS Code REST Client (Recommended for Beginners)**

1. **Install Extension:**
   - Open VS Code
   - Go to Extensions (Ctrl+Shift+X)
   - Search: "REST Client"
   - Install by Huachao Mao

2. **Use the Test File:**
   - Open `test-api.http` (downloaded below)
   - Click "Send Request" above any request
   - Results appear in a new panel

### **Method 2: Postman**

1. **Install Postman:**
   - Download from: https://www.postman.com/downloads/

2. **Import Collection:**
   - Open Postman
   - Click "Import"
   - Select `Vehicle-Scheduling-API.postman_collection.json`
   - All endpoints are ready to use!

### **Method 3: Browser (GET Requests Only)**

Visit these URLs in your browser:
- http://localhost:3000/api/health
- http://localhost:3000/api/vehicles
- http://localhost:3000/api/jobs
- http://localhost:3000/api/dashboard/summary

---

## 📝 Essential API Endpoints

### **1. Get All Vehicles**
```
GET http://localhost:3000/api/vehicles
```

**Expected Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "vehicle_name": "Vehicle 1 - Delivery Van",
      "license_plate": "ABC-123",
      "vehicle_type": "van",
      "is_active": 1
    }
  ],
  "count": 3
}
```

---

### **2. Get All Jobs**
```
GET http://localhost:3000/api/jobs
```

**Expected Response:**
```json
{
  "success": true,
  "jobs": [
    {
      "id": 1,
      "job_number": "JOB-2024-0001",
      "customer_name": "ABC Corporation",
      "scheduled_date": "2024-02-15",
      "current_status": "assigned"
    }
  ],
  "count": 3
}
```

---

### **3. Create New Job**
```
POST http://localhost:3000/api/jobs
Content-Type: application/json

{
  "customer_name": "John Doe",
  "customer_phone": "555-1234",
  "customer_address": "123 Main St",
  "job_type": "installation",
  "description": "Install new equipment",
  "scheduled_date": "2024-02-25",
  "scheduled_time_start": "09:00:00",
  "scheduled_time_end": "12:00:00",
  "estimated_duration_minutes": 180,
  "priority": "normal",
  "created_by": 1
}
```

**Expected Response:**
```json
{
  "success": true,
  "job": {
    "id": 4,
    "job_number": "JOB-2024-0004",
    "customer_name": "John Doe",
    "current_status": "pending"
  },
  "message": "Job created successfully"
}
```

---

### **4. Assign Job to Vehicle**
```
POST http://localhost:3000/api/job-assignments/assign
Content-Type: application/json

{
  "job_id": 1,
  "vehicle_id": 1,
  "driver_id": 3,
  "assigned_by": 1
}
```

**Expected Response:**
```json
{
  "success": true,
  "message": "Job assigned to vehicle successfully",
  "data": {
    "assignment_id": 1,
    "job_number": "JOB-2024-0001",
    "vehicle_name": "Vehicle 1 - Delivery Van"
  }
}
```

---

### **5. Update Job Status**
```
POST http://localhost:3000/api/job-status/update
Content-Type: application/json

{
  "job_id": 1,
  "new_status": "in_progress",
  "changed_by": 1,
  "reason": "Driver started work"
}
```

**Expected Response:**
```json
{
  "success": true,
  "message": "Job status updated to 'in_progress' successfully",
  "data": {
    "job": {...},
    "statusChange": {...}
  }
}
```

---

### **6. Get Dashboard Summary**
```
GET http://localhost:3000/api/dashboard/summary
```

**Expected Response:**
```json
{
  "success": true,
  "data": {
    "summary": {
      "totalJobs": 10,
      "completedJobs": 5,
      "activeJobs": 3,
      "vehiclesBusy": 2,
      "vehiclesAvailable": 1
    },
    "todaysJobs": [...],
    "recentActivity": [...]
  }
}
```

---

## 🔄 Complete Workflow Test

Test the entire job lifecycle:

### **Step 1: Create a Job**
```
POST /api/jobs
{
  "customer_name": "Test Customer",
  "customer_phone": "555-1234",
  "customer_address": "123 Test St",
  "job_type": "delivery",
  "description": "Test delivery",
  "scheduled_date": "2024-02-25",
  "scheduled_time_start": "09:00:00",
  "scheduled_time_end": "11:00:00",
  "estimated_duration_minutes": 120,
  "priority": "normal",
  "created_by": 1
}
```
✅ **Job created with status: pending**

---

### **Step 2: Assign to Vehicle**
```
POST /api/job-assignments/assign
{
  "job_id": 4,
  "vehicle_id": 2,
  "driver_id": 4,
  "assigned_by": 1
}
```
✅ **Job status changed to: assigned**

---

### **Step 3: Start Job**
```
POST /api/job-status/update
{
  "job_id": 4,
  "new_status": "in_progress",
  "changed_by": 4,
  "reason": "Driver started delivery"
}
```
✅ **Job status changed to: in_progress**

---

### **Step 4: Complete Job**
```
POST /api/job-status/update
{
  "job_id": 4,
  "new_status": "completed",
  "changed_by": 4,
  "reason": "Delivery completed successfully"
}
```
✅ **Job status changed to: completed**

---

## 🚫 Testing Double-Booking Prevention

### **Scenario: Try to book same vehicle twice**

1. **Create Job A (9:00-12:00)**
```json
{
  "scheduled_date": "2024-02-26",
  "scheduled_time_start": "09:00:00",
  "scheduled_time_end": "12:00:00"
}
```

2. **Assign to Vehicle 1**
```json
{
  "job_id": 5,
  "vehicle_id": 1
}
```
✅ **Success**

3. **Create Job B (10:00-14:00) - OVERLAPS with Job A**
```json
{
  "scheduled_date": "2024-02-26",
  "scheduled_time_start": "10:00:00",
  "scheduled_time_end": "14:00:00"
}
```

4. **Try to assign to Vehicle 1 again**
```json
{
  "job_id": 6,
  "vehicle_id": 1
}
```
❌ **ERROR EXPECTED:**
```json
{
  "success": false,
  "message": "Time conflict: Vehicle already has job(s) scheduled during this time"
}
```

**This proves double-booking prevention is working!**

---

## 🐛 Common Issues & Solutions

### **Issue 1: "Cannot GET /api/vehicles"**
**Cause:** Server not running  
**Solution:**
```bash
cd vehicle-scheduling-backend
npm run dev
```

---

### **Issue 2: "Database connection failed"**
**Cause:** MySQL not running  
**Solution:**
1. Open XAMPP Control Panel
2. Click "Start" on MySQL
3. Restart your Node.js server

---

### **Issue 3: "Job with ID X not found"**
**Cause:** Database is empty or wrong ID  
**Solution:**
```sql
-- Run in phpMyAdmin
SELECT * FROM jobs;
SELECT * FROM vehicles;
```

---

### **Issue 4: Port 3000 already in use**
**Solution:**
1. Change port in `.env`:
   ```
   PORT=3001
   ```
2. Restart server
3. Use: `http://localhost:3001/api`

---

## 📊 Sample Data

Your database should already have:
- ✅ 3 Vehicles (Vehicle 1, 2, 3)
- ✅ 3 Sample Jobs
- ✅ 5 Sample Users (admin, dispatcher, 3 drivers)

To check:
1. Open phpMyAdmin (http://localhost/phpmyadmin)
2. Select `vehicle_scheduling` database
3. Browse tables: `vehicles`, `jobs`, `users`

---

## 🎯 Next Steps

### **For Backend Development:**
1. ✅ Test all endpoints using REST Client
2. ✅ Verify double-booking prevention works
3. ✅ Check dashboard and reports
4. Create additional test data
5. Add authentication (future)

### **For Flutter Integration:**
1. Create Flutter project
2. Add `http` package
3. Create API service class
4. Connect to `http://localhost:3000/api`
5. Build UI screens

---

## 📚 API Documentation Reference

### **Status Flow:**
```
pending → assigned → in_progress → completed
                                 → cancelled
```

### **Job Types:**
- `installation`
- `delivery`
- `maintenance`

### **Priority Levels:**
- `low`
- `normal`
- `high`
- `urgent`

### **Vehicle Types:**
- `van`
- `truck`
- `car`

---

## 💡 Tips

1. **Always check health endpoint first**
   ```
   GET /api/health
   ```

2. **Use query parameters for filtering**
   ```
   GET /api/vehicles?activeOnly=true
   GET /api/job-assignments/vehicle/1?date=2024-02-20
   ```

3. **Check status history for debugging**
   ```
   GET /api/job-status/history/1
   ```

4. **Use dashboard for overview**
   ```
   GET /api/dashboard/summary
   ```

---

## 🎉 Success Indicators

Your backend is working correctly if:
- ✅ Health check returns 200 OK
- ✅ Can create jobs
- ✅ Can assign vehicles
- ✅ Double-booking is prevented
- ✅ Status updates work
- ✅ Dashboard shows correct data

---

## 📞 Need Help?

**Check logs in terminal:**
```
npm run dev
```
Watch for:
- ✅ "Server running on port 3000"
- ✅ "Database connected successfully"
- ❌ Any error messages

**Common error keywords to search for:**
- "ECONNREFUSED" → Database not running
- "ER_BAD_DB_ERROR" → Database not created
- "ER_DUP_ENTRY" → Duplicate data (usually OK)

---

Happy Testing! 🚀

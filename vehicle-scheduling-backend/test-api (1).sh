#!/bin/bash
# ============================================
# Vehicle Scheduling System - API Test Script
# Run this in Git Bash or WSL on Windows
# ============================================

BASE_URL="http://localhost:3000/api"

echo "=========================================="
echo "Testing Vehicle Scheduling System API"
echo "=========================================="
echo ""

# Test 1: Health Check
echo "1. Testing Health Check..."
curl -X GET "$BASE_URL/health"
echo -e "\n"

# Test 2: Get All Vehicles
echo "2. Getting all vehicles..."
curl -X GET "$BASE_URL/vehicles"
echo -e "\n"

# Test 3: Get Vehicle by ID
echo "3. Getting vehicle by ID (1)..."
curl -X GET "$BASE_URL/vehicles/1"
echo -e "\n"

# Test 4: Get All Jobs
echo "4. Getting all jobs..."
curl -X GET "$BASE_URL/jobs"
echo -e "\n"

# Test 5: Create New Job
echo "5. Creating new job..."
curl -X POST "$BASE_URL/jobs" \
  -H "Content-Type: application/json" \
  -d '{
    "customer_name": "Test Customer",
    "customer_phone": "555-1234",
    "customer_address": "123 Test Street",
    "job_type": "installation",
    "description": "Test job",
    "scheduled_date": "2024-02-25",
    "scheduled_time_start": "09:00:00",
    "scheduled_time_end": "12:00:00",
    "estimated_duration_minutes": 180,
    "priority": "normal",
    "created_by": 1
  }'
echo -e "\n"

# Test 6: Assign Job to Vehicle
echo "6. Assigning job to vehicle..."
curl -X POST "$BASE_URL/job-assignments/assign" \
  -H "Content-Type: application/json" \
  -d '{
    "job_id": 1,
    "vehicle_id": 1,
    "driver_id": 3,
    "assigned_by": 1
  }'
echo -e "\n"

# Test 7: Get Dashboard Summary
echo "7. Getting dashboard summary..."
curl -X GET "$BASE_URL/dashboard/summary"
echo -e "\n"

echo "=========================================="
echo "Testing Complete!"
echo "=========================================="

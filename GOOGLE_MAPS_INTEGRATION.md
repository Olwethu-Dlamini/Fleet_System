# 🗺️ Google Maps Integration: Technical Change Log

This document details all modifications made to the **Vehicle Scheduling System** to support Google Maps integration, including coordinate storage, map picking, and driver navigation.

---

## 1. Database Layer (MySQL)

**Action Required**: You must manually execute the following SQL to update your database schema.

```sql
-- Add latitude and longitude columns to store job destinations
ALTER TABLE jobs 
ADD COLUMN destination_lat DECIMAL(10, 8) NULL AFTER customer_address,
ADD COLUMN destination_lng DECIMAL(11, 8) NULL AFTER destination_lat;
```

---

## 2. Backend Layer (Node.js/Express)

### 📄 `src/models/Job.js`
- **`createJob()`**: Added `destination_lat` and `destination_lng` to the `INSERT` query.
- **`updateJob()`**: Added coordinate fields to the `allowedFields` array to permit updates.
- **`SELECT` Queries**: Updated `getJobById`, `getAllJobs`, `getJobsByDate`, and `getJobsByVehicle` to include `j.destination_lat` and `j.destination_lng`.

### 📄 `src/routes/jobs.js`
- **`PUT /api/jobs/:id`**: Updated the route handler to extract coordinates from the request body (`req.body`) and include them in the `UPDATE` SQL statement.

---

## 3. Frontend Layer (Flutter)

### 📄 `pubspec.yaml`
Added the following dependencies:
- `google_maps_flutter`: To display the interactive map.
- `geolocator`: To get the user's current GPS position.
- `url_launcher`: To open external navigation apps (Google Maps) from the driver's view.

### 📄 `android/app/src/main/AndroidManifest.xml`
- **Permissions**: Added `ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION`.
- **API Key**: Added the `<meta-data>` placeholder for the Google Maps API Key.

### 📄 `lib/models/job.dart`
- Added `destinationLat` and `destinationLng` fields.
- Implemented `_parseDouble()` safe parser.
- Updated `fromJson()` and `toJson()` for serialization.

### 📄 `lib/services/job_service.dart` & `lib/providers/job_provider.dart`
- Updated `createJob()` and `updateJob()` signatures to accept and send coordinates to the backend.

---

## 4. New Components & UI Updates

### 📄 `lib/widgets/common/location_picker_popup.dart` (NEW)
A full-screen map widget that:
- Automatically finds the user's current location on startup.
- Allows users to drop a pin to select a specific destination.
- Returns the selected coordinates and a placeholder address to the calling screen.

### 📄 `lib/screens/jobs/create_job_screen.dart` & `edit_job_screen.dart`
- **State**: Added `_lat` and `_lng` variables.
- **UI**: Added a **Map Icon Button** inside the Address text field.
- **Logic**: Implemented `_pickLocation()` to launch the new map picker and update the form state.

### 📄 `lib/screens/jobs/job_detail_screen.dart`
- **Navigation**: Implemented `_openMap()` using `url_launcher` to open `google.com/maps/search/` with the job's coordinates.
- **UI**: Added a **"Navigate" Directions Icon** next to the address row, visible only if the job has saved coordinates.

---

## 🚀 Post-Implementation Steps

1.  **Run SQL**: Execute the `ALTER TABLE` command in Section 1.
2.  **API Key**: Replace `YOUR_GOOGLE_MAPS_API_KEY_HERE` in `AndroidManifest.xml` with a valid key from the Google Cloud Console.
3.  **Enable SDK**: Ensure the **Maps SDK for Android** and **Geocoding API** are enabled in your Google Cloud Project.
4.  **Rebuild**: Run `flutter clean` and `flutter run` to apply the new native configurations.

# Testing Guide

This document provides instructions on how to run automation tests for both the backend (Laravel) and frontend (Flutter) modules of the SmartDentQueue application.

## Backend (Laravel)

The backend uses PHPUnit for Feature and Unit testing of API endpoints.

### Commands
- **Run all tests:** 
  ```bash
  php artisan test
  ```
- **Run a specific test file:** 
  ```bash
  php artisan test tests/Feature/AuthControllerTest.php
  ```

### Modules Covered
- **Authentication:** `AuthControllerTest.php` (Covers Login, Register, and Logout flows).
- **Admin Master List:** `AdminMasterListApiTest.php` (Verifies fetching all appointments and correct status mapping like "Approved").
- **Profile Updates:** `AdminProfileUpdateApiTest.php`, `PatientProfileUpdateApiTest.php` (Verifies profile and password changes).
- **Appointments:** `CreateAppointmentApiTest.php`, `AppointmentStatusTransitionTest.php`, `PatientCancelAppointmentTest.php` (Covers the full appointment lifecycle).
- **Queue Management:** `QueueAssignmentTest.php` (Verifies daily queue number generation).
- **Patient Records:** `PatientSearchTest.php`, `PatientRecordDetailApiTest.php` (Verifies admin/staff access to patient data).

---

## Frontend (Flutter)

The frontend uses Flutter's built-in testing framework with `mockito` for service-level unit testing.

### Commands
- **Run all tests:**
  ```bash
  flutter test
  ```
- **Run a specific test file:**
  ```bash
  flutter test test/services/http_auth_service_test.dart
  ```

### Modules Covered
- **Auth Service:** `test/services/http_auth_service_test.dart` (Tests authentication logic and token storage).
- **Appointment Service:** `test/services/appointment_service_test.dart` (Tests API integration for the Master List and booking).
- **Admin Dashboard Service:** `test/services/admin_dashboard_service_test.dart` (Tests fetching dashboard statistics).
- **Admin Profile Service:** `test/services/admin_profile_service_test.dart` (Tests sending a PUT request for profile updates).
- **Patient Record Service:** `test/services/patient_record_service_test.dart` (Tests fetching and searching patient lists).
- **Profile Service (Multipart):** `test/services/profile_service_test.dart` (Tests role-based endpoints and HTTP method overrides for multipart updates).
- **Status Service:** `test/services/status_service_test.dart` (Tests API connection health checks).
- **Widget Testing:** Initial smoke tests are located in `test/widget_test.dart`.

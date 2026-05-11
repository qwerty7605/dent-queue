# Frontend Note

This note is for any future ChatGPT/Codex session that needs to understand the Flutter frontend quickly.

## Stack

- Framework: Flutter
- Entry point: `frontend/lib/main.dart`
- App name: `SmartDentQueue`
- Theme: `frontend/lib/core/app_theme.dart`
- API base wiring: `frontend/lib/core/config.dart`, `frontend/lib/core/api_client.dart`
- Auth token storage: `frontend/lib/core/token_storage.dart`

## App Entry Flow

- `main.dart` bootstraps `ApiClient`, `BaseService`, `HttpAuthService`, and `SecureTokenStorage`.
- The app starts in `AuthSwitcherView`.
- Current startup flow:
  - if there is no token, go directly to `LoginView`
  - if token is valid, go to `DashboardView`
  - if token is invalid, clear storage and go to `LoginView`
- The old `Get Started` page was removed from the flow.

## Top-Level Routing

`frontend/lib/views/dashboard_view.dart` is the role switcher after login.

- `patient` -> `PatientDashboardView`
- `staff` or `intern` -> `StaffDashboardView`
- `admin` -> `AdminDashboardView`

Logout is handled centrally in `DashboardView`, then passed into each role dashboard.

## Directory Layout

- `frontend/lib/core`
  - app config, theme, API client, validators, cache helpers, appointment helpers
- `frontend/lib/models`
  - UI-facing models such as notifications and recycle bin entries
- `frontend/lib/services`
  - HTTP service layer for auth, appointments, dashboards, settings, staff, records, notifications
- `frontend/lib/views`
  - page-level role dashboards and admin/staff/patient screens
- `frontend/lib/widgets`
  - shared dialogs, navigation chrome, tables, pickers, empty states, admin layout

## Auth Screens

- `frontend/lib/views/login_view.dart`
- `frontend/lib/views/register_view.dart`
- Shared auth shell: `frontend/lib/views/auth_ui.dart`

Important UI direction:

- green/cream auth palette
- hero panel on larger screens
- card-based auth form on the right for desktop

## Patient Frontend

Main file: `frontend/lib/views/patient_dashboard_view.dart`

Current structure:

- Bottom navigation only
- No side drawer
- Tabs are:
  - `Home`
  - `History`
  - `Appointments`
  - `Profile`

Important current behavior:

- The `History` tab is the patient appointment history page.
- The page title says `Appointment History`.
- The button label stays short as `History`.
- The patient header has a subtle red logout icon before the logo.
- That logout icon is left-pointing and has no filled circle background.
- Notifications still open from the top bar.
- Patient queue status auto-refreshes every 10 seconds.
- Completed appointments are shown in appointment history.
- Patient appointment data also merges recycle-bin/cancelled data where needed.

Key related widgets:

- `book_appointment_dialog.dart`
- `appointment_details_dialog.dart`
- `reschedule_appointment_dialog.dart`
- `edit_profile_dialog.dart`
- `navigation_chrome.dart`

## Staff Frontend

Main file: `frontend/lib/views/staff_dashboard_view.dart`

Staff tabs:

- home
- appointments
- walk-in
- calendar
- records
- profile

Important behavior:

- `intern` uses the same dashboard but in read-only mode.
- Staff loads the queue for the selected date.
- Staff can access:
  - walk-in management
  - calendar view
  - patient records
  - recycle bin
  - notifications

Related files:

- `frontend/lib/views/staff_calendar_view.dart`
- `frontend/lib/views/staff_walk_in_view.dart`
- `frontend/lib/views/staff_patient_records_view.dart`
- `frontend/lib/views/staff_patient_detail_view.dart`
- `frontend/lib/views/recycle_bin_view.dart`

## Admin Frontend

Main file: `frontend/lib/views/admin_dashboard_view.dart`
Shared shell: `frontend/lib/widgets/admin_layout.dart`

Sidebar routes:

- Dashboard
- Patient Accounts
- Staff Registry
- Appointments
- Reports
- Settings
- Profile

Important current behavior and UI decisions:

- `Clinic Configuration` was renamed to `Settings`.
- Duplicate page-level `Clinic Settings` heading/description was removed.
- Shared page descriptions were removed from admin pages so headers stay cleaner.
- Dashboard stat cards should show:
  - Patient Accounts
  - Staff Registry
  - Appointments
  - Reports
- Dashboard latest appointments preview currently shows the last `3` appointments.
- On the dashboard, `Latest Appointments` and `System Logs` are intended to sit side by side.
- Latest appointments should be visually compact and card-like, not long stretched rows.

Admin child views:

- `frontend/lib/views/admin_patients_view.dart`
- `frontend/lib/views/admin_staff_view.dart`
- `frontend/lib/views/admin_master_list_view.dart`
- `frontend/lib/views/admin_reports_view.dart`
- `frontend/lib/views/admin_settings_view.dart`
- `frontend/lib/views/admin_profile_view.dart`

## Date Range UI Conventions

There is a shared custom range field:

- `frontend/lib/widgets/anchored_date_range_field.dart`

This exists because the requested UX is not a full-screen date picker page. The expected behavior is:

- range picker appears anchored below the field
- it behaves more like a compact popover/modal tied to the input
- user can drag/select date ranges visually

This UI is already used in:

- `frontend/lib/views/admin_reports_view.dart`
- `frontend/lib/views/admin_settings_view.dart`

## Reports Screen

Main file: `frontend/lib/views/admin_reports_view.dart`

Current direction:

- Replace separate `Start Date` and `End Date` inputs with a single `Filter by Date` range control.
- The control should follow the anchored picker UX described above.

## Settings Screen

Main file: `frontend/lib/views/admin_settings_view.dart`

Current direction:

- Page is labeled `Settings`, not `Clinic Configuration`.
- Doctor unavailability supports date ranges, not just a single day.
- The date control is draggable/range-based.
- For one selected day, admin can choose:
  - full day unavailable
  - available morning only
  - available afternoon only
- For multi-day ranges, the main intended mode is full-day blocking across the selected range.

Backend-linked expectation already discussed in UI work:

- doctor week blocking is meant to affect appointments during that range
- current backend handling for pending vs confirmed appointments should be checked in Laravel services if behavior changes are requested

## Shared Widgets Worth Knowing

- `frontend/lib/widgets/admin_layout.dart`
  - admin shell, sidebar, header, dark mode toggle
- `frontend/lib/widgets/navigation_chrome.dart`
  - shared app header and bottom-nav pieces
- `frontend/lib/widgets/app_empty_state.dart`
  - empty-state component reused across dashboards
- `frontend/lib/widgets/admin_data_table.dart`
  - reusable admin table shell
- `frontend/lib/widgets/dashboard_stat_card.dart`
  - admin metric cards
- `frontend/lib/widgets/app_confirmation_dialog.dart`
  - shared confirmation dialog, used for logout and other confirms

## Service Layer Map

Most view logic talks to these services:

- `auth_service.dart`, `http_auth_service.dart`
- `appointment_service.dart`
- `notification_service.dart`
- `patient_record_service.dart`
- `admin_dashboard_service.dart`
- `admin_settings_service.dart`
- `admin_staff_service.dart`
- `profile_service.dart`
- `admin_profile_service.dart`
- `staff_service.dart`

General pattern:

- services depend on `BaseService`
- `BaseService` uses `ApiClient`
- views hold local UI state and call services directly

## Current UI Assumptions To Preserve

- Patient uses bottom nav, not side nav.
- Patient history means appointment history.
- Patient logout icon should stay subtle.
- Admin settings label should remain `Settings`.
- Admin dashboard overview should stay brief and uncluttered.
- Latest appointments preview on admin dashboard should stay compact.
- Date-range picking in reports/settings should follow the custom anchored picker style, not the default full-page calendar route.

## Fast Starting Points

If you need to change a specific area, start here:

- auth/startup issues: `frontend/lib/main.dart`
- role routing after login: `frontend/lib/views/dashboard_view.dart`
- patient UI: `frontend/lib/views/patient_dashboard_view.dart`
- staff UI: `frontend/lib/views/staff_dashboard_view.dart`
- admin shell: `frontend/lib/widgets/admin_layout.dart`
- admin dashboard: `frontend/lib/views/admin_dashboard_view.dart`
- admin reports filters: `frontend/lib/views/admin_reports_view.dart`
- admin settings and doctor availability: `frontend/lib/views/admin_settings_view.dart`

# Laravel Backend: MCS Scaffolding

This project implements a clean architecture using the **Model–Controller–Service (MCS)** pattern. It is currently in the **scaffolding phase**, providing the necessary structure for scalable development without any initial business logic.

## Architecture Overview

### 1. Models (Eloquent)
Located in `app/Models`.
- Core data structures based on the database schema.
- Relationships (belongsTo, hasMany) are defined for seamless data retrieval.
- Mass-assignment protection via `$fillable`.

### 2. Services (Logic Layer)
Located in `app/Services`.
- Dedicated classes for core modules (`UserService`, `AppointmentService`, `QueueService`, etc.).
- Method signatures are defined but intentionally empty, ready for future implementation.
- This layer ensures logic is reusable and decoupled from the HTTP layer.

### 3. Controllers (HTTP Layer)
Located in `app/Http/Controllers/Api`.
- Resource controllers using **Dependency Injection** in their constructors to reference their respective Services.
- All HTTP methods (index, store, show, update, destroy) are defined but currently empty.

### 4. Routing
Located in `routes/api.php`.
- Organized into logical groups with `v1` versioning.
- Route placeholders are ready for the corresponding controller methods.

## Default Accounts

For testing, use the following administrator account:
- **Email**: `admin@example.com`
- **Password**: `password123`

See **[CREDENTIALS.md](file:///home/aldridge/app-dev/laravel/CREDENTIALS.md)** for more roles (Staff, Patient).

## Getting Started

1. **Verify Structure**: Run `ls -R app/Models app/Services app/Http/Controllers/Api` to see the generated files.
2. **List Routes**: Run `php artisan route:list` to see the available API endpoints.

## Database Host Behavior

- When Laravel runs on the host machine, the default database host is `127.0.0.1`.
- When Laravel runs inside the Docker `php` container, the default database host is `db`.
- You can still override either case explicitly with `DB_HOST`.

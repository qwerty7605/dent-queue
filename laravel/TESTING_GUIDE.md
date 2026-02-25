# Testing Guide: AGD-8 Authentication & RBAC

This guide provides the necessary steps and commands to verify the Authentication engine and Role-Based Access Control (RBAC).

## 1. Default Accounts
The following accounts have been seeded for testing (Password for all: `password123`):

| Role | Email | Expected Access |
|---|---|---|
| **Admin** | `admin@example.com` | Full access to `/admin/*` |
| **Staff** | `staff@example.com` | Access to `/admin/*` |
| **Patient** | `patient@example.com` | Access to `/patient/*` only |

---

## 2. Postman Testing: Login & Authentication (Port 8080)

Follow these steps to verify login functionality via Nginx.

### Step 1: Create Login Request
- **Method**: `POST`
- **URL**: `http://localhost:8080/api/v1/auth/login`
- **Headers**:
    - `Accept`: `application/json`
    - `Content-Type`: `application/json`
- **Body** (Raw JSON):
```json
{
    "email": "patient@example.com",
    "password": "password123"
}
```

### Step 2: Expected Output (Success)
If the login is successful, you should receive a **200 OK** status with the following structure:
```json
{
    "user": {
        "id": 3,
        "full_name": "Generic Patient",
        "email": "patient@example.com",
        "role_id": 3,
        "role": {
            "id": 3,
            "name": "Patient"
        }
    },
    "access_token": "1|AbCdeFgHiJkLmNoP...",
    "token_type": "Bearer"
}
```

### Step 3: Access Protected Route
Use the `access_token` as a **Bearer Token** in the Authorization header.

- **Success Test**: `GET` to `/api/v1/patient/appointments` (Returns empty array/200 OK).
- **Unauthorized Test (RBAC)**: `GET` to `/api/v1/admin/services` (Expected: **403 Forbidden**).

### Step 4: Logout
Send a `POST` request to `/api/v1/auth/logout` with the Bearer token.

**Expected Result**: Subsequent requests using the same token should return **401 Unauthorized**.

## 3. Postman Testing: Registration (Port 8080)

Follow these steps to test creating a new user account.

### Step 1: Create Register Request
- **Method**: `POST`
- **URL**: `http://localhost:8080/api/v1/auth/register`
- **Headers**:
    - `Accept`: `application/json`
    - `Content-Type`: `application/json`
- **Body** (Raw JSON):
```json
{
    "full_name": "New User",
    "email": "newuser@example.com",
    "password": "password123",
    "password_confirmation": "password123",
    "phone_number": "09123456789"
}
```

### Step 2: Expected Output (Success)
You should receive a **201 Created** status:
```json
{
    "user": {
        "id": 4,
        "full_name": "New User",
        "email": "newuser@example.com",
        "phone_number": "09123456789",
        "role_id": 3,
        "is_active": true,
        "role": {
            "id": 3,
            "name": "Patient"
        }
    },
    "access_token": "2|XyZ123...",
    "token_type": "Bearer"
}
```

---

## 4. Role-Based Access Control (RBAC) Verification
1. **Login as Patient**: Use `patient@example.com`.
2. **Access Patient Route**: `GET http://localhost:8080/api/v1/patient/appointments` -> **200 OK**.
3. **Access Admin Route**: `GET http://localhost:8080/api/v1/admin/services` -> **403 Forbidden**.

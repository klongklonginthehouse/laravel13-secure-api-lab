# Secure API Lab — completed implementation

This repository is the finished laboratory activity described below. Everything in Part A through Part F has been carried out on this machine, and every endpoint was exercised against the running application.

## Environment used

| Component | Version |
|---|---|
| OS | Windows 11 |
| PHP (CLI) | 8.4.27 NTS (separate install; the XAMPP bundle ships 8.2 and Laravel 13 needs 8.3+) |
| Composer | 2.11.1 |
| Node / npm | 26.13.0 / 11.x |
| Laravel | 13.40.0 |
| Database | MariaDB 10.4.32 (XAMPP), `demo_app_integ2`, all tables InnoDB |
| API auth | Laravel Sanctum personal access tokens |

## Verified test results

Captured from `http://127.0.0.1:8000` against the live application (`evidence/run-results.json`, screenshots in `evidence/`):

| Test | Method and endpoint | Expected | Actual |
|---|---|---|---|
| 1 | `GET /api/hello` | 200 | 200 |
| 2 | `POST /api/register` | 201 | 201 |
| 3 | `POST /api/login` | 200 | 200 (Bearer token issued) |
| 4 | `GET /api/profile` (no token) | 401 | 401 |
| 5 | `GET /api/profile` (valid token) | 200 | 200 |
| 6 | `POST /api/login` (wrong password) | 422 | 422 `Invalid credentials.` |
| 7 | `POST /api/logout` (valid token) | 200 | 200 |
| 8 | `GET /api/profile` (revoked token) | 401 | 401 |

After logout, `personal_access_tokens` is empty — the row is deleted, so the same token is rejected on the next request.

## Running it again

```bash
composer install
cp .env.example .env      # then set DB_DATABASE=demo_app_integ2 and your MySQL credentials
php artisan key:generate
php artisan migrate
php artisan serve
```

Start MySQL (and Apache if you want phpMyAdmin) from the XAMPP Control Panel first, and make sure the CLI `php -v` is 8.3+.

The Postman collection and environment are in `postman/`. Import both, run the requests in order — request 3 stores the token in `access_token` automatically.

## Evidence

`evidence/` holds the eight screenshots named in the activity, the raw response bodies in `evidence/responses/`, the combined run in `evidence/run-results.json`, and a single-page report (`evidence/report.html`). Access tokens are redacted everywhere; passwords appear only in the request bodies of the disposable lab account.

---

# Laboratory Activity: Building and Testing a Secure API with Laravel 13

**Course:** Integrative Programming & Technologies II  
**Module 5 — Lesson 1:** Secure API Design and Token-Based Authentication  
**Framework:** Laravel 13 | **Database:** MySQL (WAMP or XAMPP) | **API authentication:** Laravel Sanctum  
**Testing tool:** Postman | **Submission:** GitHub repository URL + screenshots

## Learning outcomes

By the end of this activity, students should be able to:

1. Create a Laravel 13 project from scratch using WAMP or XAMPP for MySQL.
2. Configure the `.env` file, InnoDB, and Laravel's schema defaults.
3. Install Node dependencies, Laravel API routing, and Sanctum; publish CORS configuration.
4. Implement token-based registration, login, an authenticated profile endpoint, and logout.
5. Test successful and unsuccessful API requests in Postman.
6. Document their work with screenshots and push source code to GitHub safely.

> **Scope:** This is a classroom development exercise. It uses personal access tokens, not browser-session SPA authentication. Do not deploy the sample credentials or expose real user data publicly.

---

## Part A — Prepare your development environment

### 1. Install the prerequisites

- **WAMP or XAMPP**, with a PHP version supported by Laravel 13 (**PHP 8.3+**) and MySQL/MariaDB.
- **Composer**, **Node.js and npm**, **Git**, **Postman**, and a code editor (e.g., VS Code).
- Confirm that the PHP used by your terminal is a supported version and that `pdo_mysql` is enabled. The CLI PHP may differ from the PHP bundled with WAMP/XAMPP.

Open a terminal and check:

```bash
php -v
composer -V
node -v
npm -v
git --version
php -m
```

Look for `pdo_mysql` in `php -m`. If it is missing, enable it in the CLI PHP's `php.ini`, then restart the terminal.

### 2. Start WAMP/XAMPP

1. Open **WAMP** or **XAMPP Control Panel**.
2. Start **MySQL** and **Apache**.
3. Open phpMyAdmin from your WAMP/XAMPP dashboard (commonly `http://localhost/phpmyadmin`).
4. Create a new database named **`demo_app_integ2`** with a `utf8mb4` collation. Alternatively, run:

```sql
CREATE DATABASE demo_app_integ2
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
```

> **Apache note:** We start Apache for phpMyAdmin and the WAMP/XAMPP environment. The commands below run the Laravel application using `php artisan serve` on port 8000, **not** an Apache virtual host. To serve Laravel via Apache instead, you must configure the web root to Laravel's `public/` folder. Do not point Apache at the Laravel project root.

### 3. Create a Laravel 13 project

Open a terminal in the folder where you keep your projects. Example for XAMPP on Windows:

```powershell
cd C:\xampp\htdocs
```

For WAMP, use the corresponding `www` folder, or any suitable development folder.

Create and enter your application:

```bash
composer create-project laravel/laravel demo-api "^13.0"
cd demo-api
php artisan --version
```

If Composer reports that your PHP version is unsupported, switch the CLI to a supported PHP installation before proceeding.

### 4. Install frontend dependencies

```bash
npm install
npm run build
```

The API endpoints in this lab do **not** require a frontend, but this step verifies that the standard Laravel project's Node/Vite dependencies can be installed and built. `npm run dev` is optional while developing views.

---

## Part B — Configure Laravel and MySQL

### 5. Set up `.env`

Open the `.env` file at the project root. Update the relevant lines (keep the other Laravel defaults):

```dotenv
APP_NAME="Secure API Demo"
APP_ENV=local
APP_DEBUG=true
APP_URL=http://127.0.0.1:8000

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=demo_app_integ2
DB_USERNAME=root
DB_PASSWORD=
```

- An empty database password is common in **some local installations**; enter your actual password if configured.
- Use your actual MySQL port if it is not `3306`.
- If an existing `DB_URL` or `DATABASE_URL` points to another database, remove or correct that override.
- **Never upload your real `.env` file to GitHub.** Laravel normally ignores it with `.gitignore`.

If `.env` is missing, copy `.env.example` to `.env`, then run:

```bash
php artisan key:generate
```

If `.env` already contains `APP_KEY`, do not regenerate it unnecessarily.

### 6. Set InnoDB in `config/database.php`

In the **`mysql`** connection array, locate the `engine` setting and set it to:

```php
'engine' => 'InnoDB',
```

**Why?** MyISAM may fail on the composite index in Laravel's `failed_jobs` migration with `Specified key was too long; max key length is 1000 bytes`. InnoDB is preferable for Laravel tables, including those needing transactions and foreign keys.

### 7. Configure default string length

Open `app/Providers/AppServiceProvider.php`. Add the `Schema` import and the default string length inside `boot()`:

```php
<?php

namespace App\Providers;

use Illuminate\Support\Facades\Schema;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        //
    }

    public function boot(): void
    {
        Schema::defaultStringLength(191);
    }
}
```

> This is an **additional classroom compatibility setting**, not a substitute for InnoDB. It changes default lengths of string columns created by migrations; it does not solve every composite-index length problem.

### 8. Clear cached configuration and run migrations

```bash
php artisan config:clear
php artisan migrate
php artisan migrate:status
```

If Laravel asks to create the database, you may accept, or create it first through phpMyAdmin.

**If migrations previously failed with MyISAM:** first verify the `mysql` engine setting above. Only when this is a brand-new disposable database with **no important data**, you may run:

```bash
php artisan migrate:fresh
```

**Warning:** `migrate:fresh` drops **all tables** in the configured database. Never use it on a database containing important records.

---

## Part C — Enable API routing, Sanctum, and CORS

### 9. Install API support and Sanctum

From the Laravel project directory, run:

```bash
php artisan install:api
php artisan migrate
```

The Laravel 13 command enables API routing, installs Sanctum, and creates `routes/api.php`. The migration creates Sanctum's `personal_access_tokens` table. **Do not install Sanctum a second time manually after `install:api` has succeeded.**

Verify:

```bash
php artisan route:list --path=api
```

### 10. Publish CORS configuration

```bash
php artisan config:publish cors
```

Open `config/cors.php`. For this laboratory, the default `api/*` paths and configuration are generally sufficient. Keep the original settings unless your instructor supplies a separate browser frontend origin.

> **Important:** CORS controls access initiated by browsers across origins. **Postman does not enforce browser CORS policies.** Publishing this file is a configuration exercise, not a requirement for Postman requests. Do not use `allowed_origins => ['*']` with credentialed browser access.

### 11. Enable Sanctum tokens on the `User` model

Open `app/Models/User.php`. Add:

```php
use Laravel\Sanctum\HasApiTokens;
```

Inside the existing `User` class, add `HasApiTokens` to its existing trait line; for example:

```php
use HasApiTokens, HasFactory, Notifiable;
```

**Do not overwrite or remove** the existing `$fillable`, `$hidden`, or `casts()` configuration. The default Laravel user model should already allow `name`, `email`, and `password` to be mass-assigned. Keep the default password hashing cast if present.

---

## Part D — Build the token authentication API

### 12. Generate the controller

```bash
php artisan make:controller Api/AuthController
```

Replace `app/Http/Controllers/Api/AuthController.php` with:

```php
<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function register(Request $request)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
        ]);

        $user = User::create([
            'name' => $data['name'],
            'email' => $data['email'],
            'password' => Hash::make($data['password']),
        ]);

        return response()->json([
            'message' => 'Registration successful',
            'user' => $user->only('id', 'name', 'email'),
        ], 201);
    }

    public function login(Request $request)
    {
        $data = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        $user = User::where('email', $data['email'])->first();

        if (! $user || ! Hash::check($data['password'], $user->password)) {
            throw ValidationException::withMessages([
                'email' => ['Invalid credentials.'],
            ]);
        }

        $token = $user->createToken('postman-lab')->plainTextToken;

        return response()->json([
            'message' => 'Login successful',
            'token_type' => 'Bearer',
            'access_token' => $token,
        ]);
    }

    public function profile(Request $request)
    {
        return response()->json([
            'user' => $request->user()->only('id', 'name', 'email'),
        ]);
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json([
            'message' => 'Logged out successfully',
        ]);
    }
}
```

**Discussion:** Password hashing protects stored credentials. Sanctum stores a hash of each API token and displays the plain-text token only when created; treat that returned token as a secret. This tutorial implements login for Postman with a personal access token; it does not implement a browser SPA authentication flow.

### 13. Define API routes

Replace `routes/api.php` with:

```php
<?php

use App\Http\Controllers\Api\AuthController;
use Illuminate\Support\Facades\Route;

Route::get('/hello', function () {
    return response()->json([
        'message' => 'Welcome to the Laravel 13 API',
    ]);
});

Route::post('/register', [AuthController::class, 'register'])
    ->middleware('throttle:6,1');

Route::post('/login', [AuthController::class, 'login'])
    ->middleware('throttle:6,1');

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/profile', [AuthController::class, 'profile']);
    Route::post('/logout', [AuthController::class, 'logout']);
});
```

Check registered routes:

```bash
php artisan route:list --path=api
```

### 14. Start the Laravel development server

```bash
php artisan serve
```

Keep this terminal open. Requests below assume:

```text
http://127.0.0.1:8000
```

If the server uses another port, substitute the port in every Postman request.

---

## Part E — Test all endpoints in Postman

Create a Postman collection called **Module 5 - Laravel API**. For **every** request below, add:

```http
Accept: application/json
```

For requests with JSON bodies, also add `Content-Type: application/json`, and use **Body → raw → JSON**.

### Test 1 — Public endpoint

- **Method:** `GET`
- **URL:** `http://127.0.0.1:8000/api/hello`
- **Authorization:** No Auth

Expected **200 OK**:

```json
{
  "message": "Welcome to the Laravel 13 API"
}
```

### Test 2 — Register a new user

- **Method:** `POST`
- **URL:** `http://127.0.0.1:8000/api/register`
- **Authorization:** No Auth
- **Body:**

```json
{
  "name": "Juan Dela Cruz",
  "email": "juan@example.com",
  "password": "Student@12345",
  "password_confirmation": "Student@12345"
}
```

Expected **201 Created** and a user object with `id`, `name`, and `email`. No password is returned.

> If the email already exists, use another example email or a fresh disposable test database. Repeating registration with the same email should return **422 Unprocessable Content**.

### Test 3 — Login and obtain an access token

- **Method:** `POST`
- **URL:** `http://127.0.0.1:8000/api/login`
- **Authorization:** No Auth
- **Body:**

```json
{
  "email": "juan@example.com",
  "password": "Student@12345"
}
```

Expected **200 OK**. Example response (token is illustrative):

```json
{
  "message": "Login successful",
  "token_type": "Bearer",
  "access_token": "1|example-only-not-a-real-token"
}
```

Copy your **actual** `access_token` into a private Postman environment variable, such as `access_token`. **Do not include the real token in screenshots, exports, README, or GitHub.**

### Test 4 — Try protected access without a token

- **Method:** `GET`
- **URL:** `http://127.0.0.1:8000/api/profile`
- **Authorization:** No Auth

Expected **401 Unauthorized** with a JSON message such as:

```json
{
  "message": "Unauthenticated."
}
```

### Test 5 — Access profile with a Bearer token

- **Method:** `GET`
- **URL:** `http://127.0.0.1:8000/api/profile`
- In the **Authorization** tab, choose **Bearer Token** and enter `{{access_token}}` (using your private environment variable).

Expected **200 OK**:

```json
{
  "user": {
    "id": 1,
    "name": "Juan Dela Cruz",
    "email": "juan@example.com"
  }
}
```

The user ID may differ in your environment.

### Test 6 — Login with an incorrect password

- **Method:** `POST`
- **URL:** `http://127.0.0.1:8000/api/login`
- **Body:**

```json
{
  "email": "juan@example.com",
  "password": "wrong-password"
}
```

Expected **422 Unprocessable Content** with an `Invalid credentials.` validation message. This demonstrates safe login failure without revealing whether the email is valid.

### Test 7 — Logout and revoke the token

- **Method:** `POST`
- **URL:** `http://127.0.0.1:8000/api/logout`
- **Authorization:** Bearer Token `{{access_token}}`

Expected **200 OK**:

```json
{
  "message": "Logged out successfully"
}
```

Afterwards, **repeat Test 5 with that same token**. The expected result is **401 Unauthorized**, because the token was revoked.

### Expected results summary

| Test | Method and endpoint | Expected status |
|---|---|---|
| 1 | `GET /api/hello` | `200` |
| 2 | `POST /api/register` | `201` |
| 3 | `POST /api/login` | `200` |
| 4 | `GET /api/profile` (no token) | `401` |
| 5 | `GET /api/profile` (valid token) | `200` |
| 6 | `POST /api/login` (wrong password) | `422` |
| 7 | `POST /api/logout` (valid token) | `200` |
| 8 | `GET /api/profile` (revoked token) | `401` |

> **Note:** The statuses shown assume the exact controller and routes above and a normal local development setup. A `429` means the rate limit was reached; let the limit reset instead of disabling rate limiting.

---

## Part F — Evidence and submission

### Required screenshots

Create an `evidence/` folder in your project. Save **eight screenshots**, one for each test in the table above, using these filenames:

```text
evidence/
  01-public-api-200.png
  02-register-201.png
  03-login-200.png
  04-profile-no-token-401.png
  05-profile-with-token-200.png
  06-invalid-login-422.png
  07-logout-200.png
  08-revoked-token-401.png
```

Each screenshot must clearly display **the Postman request method, URL, HTTP response status, and response JSON**. For screenshots involving login or Authorization headers, **hide or redact the real access token**. Screenshots should not contain passwords, credentials, or secrets.

Also include a brief `SUBMISSION.md` containing your name, section, screenshots checklist, and the URL of your repository. Do **not** include actual tokens or `.env` secrets.

### Push the project to GitHub

1. Create a new **empty** GitHub repository named `laravel13-secure-api-lab`. Do not initialize it with a separate README if you will push an existing local project.
2. In your Laravel project folder, confirm `.env`, `vendor/`, and `node_modules/` are ignored by Git. Never commit those folders or secret files.
3. If necessary, rename this provided activity file to `README.md` in your repository (or retain your existing README and link to this activity).
4. Run:

```bash
git init
git status
git add .
git status
git commit -m "Complete Laravel 13 secure API lab"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/laravel13-secure-api-lab.git
git push -u origin main
```

Replace `YOUR_USERNAME` with your own GitHub username. If your folder already has an `origin` remote, update it with `git remote set-url origin <your-repository-url>` instead of adding it again.

**Before pushing:** Check `git status` and the staged files; make sure `.env`, personal access tokens, passwords, database dumps, and unrelated personal files are excluded. Keep `.env.example` with placeholder values only.

### Submission format

Submit the following in your class LMS:

- **GitHub repository URL:** `https://github.com/YOUR_USERNAME/laravel13-secure-api-lab`
- **Postman evidence:** Eight screenshots in the repository's `evidence/` folder.
- **Short reflection:** In 2–3 sentences, explain the difference between a `401` response and a successful authenticated profile response, and what happens after logout.

### Grading rubric (50 points)

| Criterion | Points |
|---|---:|
| Laravel 13 project setup, npm installation, `.env`, database/InnoDB/schema configuration | 12 |
| Sanctum, API routes, and CORS publication | 8 |
| Working registration, login, profile, and logout token flow | 18 |
| Postman testing and readable, safely redacted evidence | 8 |
| GitHub repository, project documentation, and reflection | 4 |
| **Total** | **50** |

---

## Troubleshooting guide

| Problem | What to check |
|---|---|
| `php` or `composer` not recognized | Add the correct installation directories to Windows PATH; restart the terminal. |
| Laravel reports unsupported PHP | Ensure CLI `php -v` uses PHP 8.3+; WAMP/XAMPP's Apache PHP may be different. |
| `could not find driver` | Enable the `pdo_mysql` extension in the **CLI** `php.ini`. |
| `SQLSTATE[HY000] [1045] Access denied` | Check `DB_USERNAME`, `DB_PASSWORD`, MySQL port, and server status. |
| `SQLSTATE[HY000] [1049] Unknown database` | Create `demo_app_integ2` in phpMyAdmin and check `.env`. |
| Index too long on `failed_jobs` | Set the MySQL connection engine to `InnoDB`; clear config. Use `migrate:fresh` only for a disposable database. |
| `routes/api.php` is missing | Run `php artisan install:api`. |
| `personal_access_tokens` table is missing | Run `php artisan migrate` after installing Sanctum. |
| `Trait HasApiTokens not found` | Confirm Sanctum installed successfully and the import is `Laravel\Sanctum\HasApiTokens`. |
| Login returns `422` | Check registered email, password, validation payload, and whether the same account was created successfully. |
| Protected profile returns `401` | Send a valid, not-yet-revoked Bearer token; include `Accept: application/json`. |
| Login returns `429` | Too many requests; wait until the throttle window expires. |
| Postman reports CORS error | Postman itself does not enforce CORS. Recheck the server URL, HTTP request, and whether you're actually testing in a browser. |
| Browser's Laravel page has broken CSS | Run `npm install` and `npm run dev` (or `npm run build`); the JSON API itself does not need Vite assets. |

## References

- [Laravel 13 — Installation](https://laravel.com/docs/13.x/installation)
- [Laravel 13 — Database](https://laravel.com/docs/13.x/database)
- [Laravel 13 — Routing](https://laravel.com/docs/13.x/routing)
- [Laravel 13 — Sanctum](https://laravel.com/docs/13.x/sanctum)
- [Laravel 13 — Configuration](https://laravel.com/docs/13.x/configuration)
- [Laravel 13 — Validation](https://laravel.com/docs/13.x/validation)

**Reminder:** This laboratory covers **Lesson 1: Secure API Design and Token-Based Authentication**. Role-based authorization (RBAC) is reserved for Module 5, Lesson 2.

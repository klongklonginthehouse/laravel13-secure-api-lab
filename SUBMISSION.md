# Module 5 Lesson 1 Submission

**Name:** Jave F. Gajelloma
**Section:** BSICT 3B
**Course:** Integrative Programming & Technologies II
**Repository:** https://github.com/klongklonginthehouse/laravel13-secure-api-lab

## Screenshots checklist

| # | Test | File |
|---|---|---|
| 1 | `GET /api/hello` — 200 | `evidence/01-public-api-200.png` |
| 2 | `POST /api/register` — 201 | `evidence/02-register-201.png` |
| 3 | `POST /api/login` — 200 | `evidence/03-login-200.png` |
| 4 | `GET /api/profile` without token — 401 | `evidence/04-profile-no-token-401.png` |
| 5 | `GET /api/profile` with token — 200 | `evidence/05-profile-with-token-200.png` |
| 6 | `POST /api/login` wrong password — 422 | `evidence/06-invalid-login-422.png` |
| 7 | `POST /api/logout` — 200 | `evidence/07-logout-200.png` |
| 8 | `GET /api/profile` with revoked token — 401 | `evidence/08-revoked-token-401.png` |

All eight were captured from the running application on `http://127.0.0.1:8000`. Each one shows the request method, the full URL, the HTTP status, and the response JSON. The `Authorization` header is shown as `Bearer <REDACTED_ACCESS_TOKEN>` and no real token or `.env` value appears in any screenshot.

Supporting files:

- `evidence/run-results.json` — every status code and response body from the run that produced the screenshots.
- `evidence/responses/` — individual response bodies, one per test.
- `postman/` — the collection and environment used for the requests, with a test script that stores the token automatically.

## Reflection

A `401 Unauthorized` means the request reached the protected route without a credential that Sanctum accepts: either no `Authorization: Bearer` header was sent, the token was malformed, or the token had already been deleted from `personal_access_tokens`. A successful `200 OK` on the same route means the header carried a live token that Sanctum matched to a user, so `$request->user()` returned that record and the endpoint sent back only its `id`, `name`, and `email`. Logout deletes the current token row from the database, so the token string still exists in the client but no longer resolves to a user — the next profile request with it is treated as unauthenticated and returns `401`.

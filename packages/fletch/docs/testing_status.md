# Testing Status

## Runs Performed
- `dart test test/unit/request_test.dart -p vm` — **pass**.
- `dart test test/integration/server_lifecycle_test.dart -p vm` — **pass**.
- Full-suite `dart test` — **pass** (logs include expected HttpError printouts when tests trigger error paths).

## Fixes Completed
- **Request body size limit**: rewrote `_ensureBodyBytes` to use `StreamIterator`, discard remaining bytes on overflow without double-listening, and surface a clean 413.
- **Multipart parsing**: tightened `_FormDataPayload` typing/copying to avoid `List<dynamic>` casts and ensured file-size violations raise controlled HttpErrors.
- **Shutdown handling**: `Fletch.close` now waits on server lifecycles and adds a brief grace window so late requests get 503s instead of connection refusals.
- **Tracing/logging**: Request IDs are accepted/generated and echoed on responses; errors are logged via `logger`. CORS now rejects wildcard+credentials combos.
- **Config safety**: constructor validates limits/timeouts and warns when `maxFileSize > maxBodySize`.
- **Tooling**: Added `tool/benchmark.dart` for quick local load tests.

## Current Status
- All authored suites (unit, integration, security, performance) are green via `dart test`.
- Remaining console noise is from tests intentionally provoking 4xx/5xx paths; behaviour matches expectations.

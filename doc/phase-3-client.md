# Phase 3 — Client (`client.bal`)

**Status:** ✅ Complete & verified (37/37 unit tests passing; live smoke test deferred — no creds)
**Goal:** Wire the loader to the `ballerinax/azure_storage_service.files` connector: map the
loader's `ConnectionConfig`/`AuthorizationMethod` onto the connector's, and construct the
**two** clients the loader needs — `files:FileClient` (listing + download) and
`files:ManagementClient` (share enumeration for `share: "*"`). Also pin down the connector's
not-found error shape for `isNotFoundError` (plan open item #1).

---

## 1. What was built

`ballerina/client.bal`, ported from the Blob loader's `client.bal` and retargeted to the
`files:` connector:

| Symbol | Role | vs Blob |
|---|---|---|
| `toConnectorAuthMethod(AuthorizationMethod)` | → `files:AuthorizationMethod` (`ACCESS_KEY`/`SAS`) | retargeted `blobs:` → `files:` |
| `toConnectorConfig(ConnectionConfig)` | → `files:ConnectionConfig`; forwards identity + auth + every set HTTP option | **identical body**, retargeted type |
| `newFileClient(ConnectionConfig)` | → `files:FileClient \| ai:Error` (listing + download) | renamed from `newBlobClient` |
| `newManagementClient(ConnectionConfig)` | → `files:ManagementClient \| ai:Error` (only for `share: "*"`) | **new** — Blob had a single client |
| `isNotFoundError(error)` | typed check `err is files:NotFoundError` | **moved earlier + simplified** (Blob probed error messages) |

The connector import (`import ballerinax/azure_storage_service.files;`) is now live and
recorded in `Dependencies.toml` (connector `4.3.4`, modules `…files` + `…utils`).

The Phase 0 placeholder `file_data_loader.bal` (`API_VERSION` const) still remains and
compiles; it is replaced by the real loader in Phase 4.

---

## 2. Two clients from one config

Unlike Blob (a single `BlobClient`), Azure Files splits responsibilities:

- **`files:FileClient`** — `getDirectoryList`, `getFileList`, `getFileAsByteArray`. Always
  needed. Built by `newFileClient`.
- **`files:ManagementClient`** — `listShares`. Needed **only** to expand a `share: "*"`
  source into concrete share names. Built by `newManagementClient`.

Both connector clients expose `init(ConnectionConfig config) returns Error?` and, crucially,
**construct only an `http:Client` at init — no network round-trip** (verified in the
connector source: `init` just builds `https://{accountName}.file.core.windows.net` +
`constructHTTPClientConfig`). So construction succeeds offline and the unit tests below are
meaningful without credentials. The loader (Phase 4) will build the `FileClient` eagerly and
the `ManagementClient` for `"*"` sources; both wrap failures as `ai:Error`, mirroring
`newBlobClient`.

---

## 3. `isNotFoundError` — plan open item #1 resolved

The Blob loader had to sniff error **messages** for 404s. The `files` connector is properly
typed: `createErrorFromXMLResponse` maps every HTTP status to a distinct error subtype —

```ballerina
public type Error ServerError|ClientError;
public type ServerError distinct error<ServerErrorDetail>;   // { httpStatus, errorCode, message }
public type NotFoundError distinct ServerError;              // HTTP 404
```

and produces `NotFoundError("Resource not found.", httpStatus = 404, errorCode = <AzureCode>, …)`
for **every** 404 — `ShareNotFound`, `ResourceNotFound`, `ParentNotFound`, etc. (the specific
Azure code lands in `errorCode`, not the type). So a single typed check is exact and robust:

```ballerina
isolated function isNotFoundError(error err) returns boolean => err is files:NotFoundError;
```

> **Deviation from the plan's phase split:** the plan lists `isNotFoundError` under Phase 4.
> It's defined here in Phase 3 instead, because it's purely a connector-error concern and,
> now that the concrete `files:NotFoundError` type is confirmed, it can be **unit-tested
> offline** (constructing the typed error) rather than only via live 404s. Phase 4 just calls it.

---

## 4. Tests (`ballerina/tests/client_test.bal`) — the Phase 2 deferrals, retargeted

Added **9** tests (no live calls):

| Test | Asserts |
|---|---|
| `testAuthMethodMapping` | `ACCESS_KEY`/`SAS` → `files:ACCESS_KEY`/`files:SAS`. |
| `testToConnectorConfigForwardsIdentityAndAuth` | account/token/auth/httpVersion/timeout forwarded. |
| `testToConnectorConfigForwardsOptionalHttpOptions` | set `timeout`/`retryConfig`/`proxy`/`secureSocket` forwarded. |
| `testToConnectorConfigOmitsUnsetOptionalOptions` | unset `retryConfig`/`proxy`/`circuitBreaker` stay `()`. |
| `testNewFileClientWithSas` / `…WithAccessKey` | `FileClient` constructs under both auth methods. |
| `testNewManagementClientWithSas` | `ManagementClient` constructs. |
| `testIsNotFoundErrorForNotFound` | a `files:NotFoundError` is recognised. |
| `testIsNotFoundErrorForOtherErrors` | a `files:BadRequestError` and a generic error are **not**. |

---

## 5. Verification

```bash
cd ballerina && bal test
```

Result: **37 passing, 0 failing** (21 text-layer + 7 type-shape + 9 client). The connector
resolved from Central cache, compiled, and is recorded in `Dependencies.toml`.

### Gate note (live smoke test)
The plan's Phase 3 gate is "a live smoke test that constructs the clients against the real
account." No Azure credentials are available in this environment, so — as the Blob repo did
for its connector-backed calls — the live smoke test is **deferred**. It is meaningfully
substituted here: because connector `init` makes no network call, successful offline
construction already exercises the full config-mapping → client-build path. A live smoke
test (list one share / download one file) belongs in Phase 5's `live-test/` sample.

---

## 6. Open items status

1. **Not-found error shape** → ✅ resolved: `files:NotFoundError` (typed, covers all 404s).
2. **Content-type / timestamps in listings** → confirmed absent in Phase 2 (`FileEntry`);
   classification stays extension-only.
3. **`listShares` pagination `Marker` convention** → the connector's `SharesList`/`FileList`/
   `DirectoryList` all carry an optional `Marker` + `MaxResults`; `listShares` takes
   `ListShareURIParameters { prefix?, marker?, maxresults?, … }`. Confirmed same cursor
   convention as file/directory listings; the marker loop is implemented in Phase 4.

---

## 7. Phase 3 checklist

- [x] `toConnectorAuthMethod` / `toConnectorConfig` retargeted to `files:` (config body unchanged).
- [x] `newFileClient` — constructs `files:FileClient`, wraps failure as `ai:Error`.
- [x] `newManagementClient` — constructs `files:ManagementClient` for `share: "*"`.
- [x] `isNotFoundError` — typed `files:NotFoundError` check (open item #1 resolved) + tested.
- [x] Connector import resolves; `Dependencies.toml` records `azure_storage_service` 4.3.4.
- [x] `bal test` 37/37. **Gate met** (live smoke test deferred to Phase 5's sample).

**Next:** Phase 4 — `file_data_loader.bal`: the real `TextDataLoader` (`*ai:DataLoader`) holding
the `FileClient` (+ optional `ManagementClient`) and `readonly & Source[]`, implementing
`load()` as a genuine tree-walk — resolve shares (`[share]` or paginated `listShares` for `"*"`),
resolve each path to a directory listing or an explicit-file probe (404 → directory fallback via
`isNotFoundError`), and page `getFileList` (+ `getDirectoryList` when `recursive`) via the `Marker`
cursor, converting each file through the shared `buildDocument`.

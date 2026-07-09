# Phase 2 — Types (`types.bal`)

**Status:** ✅ Complete & verified (28/28 unit tests passing)
**Goal:** Port the loader's public/​internal type surface from the Blob loader to
`ballerinax/ai.azure.storage.file`, applying the one model-driven rename (`container` →
`share`) and replacing `BlobEntry` with a Files-shaped `FileEntry`. No connector wiring
yet — that is Phase 3.

---

## 1. What was built

`ballerina/types.bal` now defines the loader's configuration and listing surface:

| Symbol | Change vs Blob | Notes |
|---|---|---|
| `enum AuthorizationMethod` | **identical** | `ACCESS_KEY`, `SAS`. Azure AD / OAuth2 not offered (connector supports Shared Key + SAS only). |
| `type ConnectionConfig` | **identical shape** | `accountName`, `accessKeyOrSAS` (password), `authorizationMethod`, + the full HTTP option block. Doc/endpoint text retargeted `blob.core.windows.net` → `file.core.windows.net`. Maps 1:1 onto the `files` connector's own `ConnectionConfig`. |
| `type Source` | `container` → **`share`** | `share` (or `"*"` = every share), `paths` (default `["/"]`), `recursive` (default `false`), `includeExtensions` (default `()`). Docs now say directories/files (a real tree), not blob-name prefixes. |
| `type FileEntry` | **replaces `BlobEntry`** | `name`, `directoryPath`, `contentLength?`, `lastModified?`. Drops `contentType` and `creationTime`. |

The Phase 0 placeholder `file_data_loader.bal` (`API_VERSION` const) remains and still
compiles alongside `types.bal`; it is superseded by the real loader in Phase 4.

---

## 2. `ConnectionConfig` — confirmed identical to the connector surface

The cached connector (`ballerinax/azure_storage_service` 4.3.4, module
`azure_storage_service.files`) declares its own `ConnectionConfig` with exactly the fields
the loader forwards:

```ballerina
public type ConnectionConfig record {|
    *config:ConnectionConfig;
    never auth?;
    string accessKeyOrSAS;
    string accountName;
    AuthorizationMethod authorizationMethod;
    http:HttpVersion httpVersion = http:HTTP_1_1;
|};
```

So the loader-owned `ConnectionConfig` (a stable surface that hides the connector) maps 1:1
in Phase 3 — same as the Blob loader did. This resolves plan **open item #1's** config half:
the `files` connector takes the same auth/config surface as `blobs`.

---

## 3. `FileEntry` — shaped to what Azure Files actually returns

Inspecting the connector's listing records drove the `FileEntry` fields:

```ballerina
public type File record {
    string Name;
    PropertiesFileItem|EMPTY_STRING Properties?;
};
public type PropertiesFileItem record {
    string 'Content\-Length?;   // the ONLY property surfaced for a file
};
public type FileList record {
    File[]|File File;           // single-or-array; page cursor below
    string Marker?;
    int MaxResults?;
};
```

Consequences captured in `FileEntry` (and confirming plan **open item #2**):
- **No content type** in the listing → `contentType` dropped; classification is
  extension-driven (already fully supported by `classify`).
- **No per-file timestamp** in the listing → `lastModified` is kept (optional) for
  forward-compatibility but is typically `()`.
- **`Content-Length` is present** → `contentLength` (`decimal?`).
- `directoryPath` is added because a real tree needs to record *where* a file was found
  (the connector lists files per directory, unlike Blob's full-path blob names).

The `File`/`Directory` "single-or-array" shape and the `Marker` page cursor are noted here;
handling them is Phase 4 loader work.

---

## 4. Tests (`ballerina/tests/types_test.bal`)

Added **7** type-shape tests — no connector import, no live calls:

| Test | Asserts |
|---|---|
| `testSourceDefaults` | `paths` = `["/"]`, `recursive` = `false`, `includeExtensions` = `()`. |
| `testSourceExplicitValues` | all four fields round-trip (uses `share`). |
| `testSourceWildcardShare` | `share: "*"` is accepted; defaults still apply. |
| `testConnectionConfigDefaults` | `httpVersion`/`timeout`/`forwarded`/`compression`/`validation` defaults. |
| `testAuthorizationMethodValues` | `ACCESS_KEY` / `SAS` distinct enum members. |
| `testFileEntryDefaults` | `name` + `directoryPath` required; `contentLength`/`lastModified` default `()`. |
| `testFileEntryAtShareRoot` | empty `directoryPath` = share root; `contentLength` set. |

### Deferred to Phase 3
The Blob `types_test.bal` also exercised `toConnectorAuthMethod`, `toConnectorConfig`, and
`newBlobClient` (importing the connector). Those depend on `client.bal` and the connector
import, so their Files equivalents land in **Phase 3** alongside `client.bal`.

---

## 5. Verification

```bash
cd ballerina && bal test
```

Result: **28 passing, 0 failing** (21 Phase 1 text-layer + 7 Phase 2 type-shape). Gate met.

---

## 6. Phase 2 checklist

- [x] `AuthorizationMethod` — ported identical.
- [x] `ConnectionConfig` — ported identical shape; endpoint doc retargeted to Files; confirmed 1:1 with the connector's own `ConnectionConfig`.
- [x] `Source` — `container` → `share`; docs updated for a real directory tree.
- [x] `FileEntry` — replaces `BlobEntry`; `name`/`directoryPath`/`contentLength?`/`lastModified?`, shaped to the connector's `File`/`PropertiesFileItem`.
- [x] Type-shape tests added; `bal test` 28/28. **Gate met.**
- [ ] (Deferred to Phase 3) `toConnectorAuthMethod` / `toConnectorConfig` / client-construction tests.

**Next:** Phase 3 — `client.bal`: `toConnectorAuthMethod` / `toConnectorConfig` retargeted to
the `files:` types, and construction of `files:FileClient` (listing + download) plus a
`files:ManagementClient` (for `share: "*"` → `listShares`), wrapping failures as `ai:Error`.
Also confirm the connector's not-found error shape for `isNotFoundError` (plan open item #1).

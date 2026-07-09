# Phase 4 — Loader (`file_data_loader.bal`)

**Status:** ✅ Complete & verified (54/54 unit tests passing; live `load()` deferred to Phase 5)
**Goal:** Replace the Phase 0 placeholder with the real `TextDataLoader` (`*ai:DataLoader`):
a genuine `Share → Directory → File` tree-walk over the `files:FileClient`
(+ `files:ManagementClient` for `"*"`), converting each file through the shared
`buildDocument`. This is the phase where Azure Files' real directory tree replaces Blob's
flat-namespace prefix gymnastics.

---

## 1. What was built

`public isolated class TextDataLoader` implementing `ai:DataLoader`:

- Fields: `files:FileClient fileClient`, `files:ManagementClient? managementClient` (built
  only when some source uses `"*"`), and `readonly & Source[] sources`.
- `init(ConnectionConfig, Source[])` — validates non-empty sources, builds the file client
  eagerly and the management client lazily (only if a `"*"` source exists), wrapping failures
  as `ai:Error`.
- `load()` — returns `ai:Document[]|ai:Document|ai:Error` (a single `ai:Document` when exactly
  one file resolves, matching the Blob loader's contract).

### The tree-walk (per source, per share, per path)
1. **Resolve shares** — `[share]`, or `listShares()` for `"*"`. `tolerateMissing = share == "*"`.
2. **Resolve each path** (`loadPath`) — share root / trailing-`/` → directory listing;
   otherwise probe as an explicit file via `getFileAsByteArray`. On success, build one
   document (explicit files bypass the extension filter; a named non-text/Office file is an
   error). On 404 (`isNotFoundError`), fall back to a directory listing — unless the path
   "looks like a file" (has an extension) and `!tolerateMissing`, then error (typo detection).
3. **List a directory** (`listDirectory`) — `getFileList` for the files here, plus, when
   `recursive`, `getDirectoryList` then recurse into each sub-directory. Each file: apply
   `matchesExtensionFilter`, download, convert via `buildDocument`; unsupported/Office files
   are skipped with a `log:printWarn` (never an error inside a listing).

### Module-level helpers (pure, unit-tested)
`normalizePath`, `trimTrailingSlash`, `splitPath`, `toFileEntries`, `contentLengthOf`,
`directoryNames`, `shareNames`, `isEmptyListing`.

The Phase 0 placeholder (`API_VERSION`) was **removed** — the file now holds the real loader.

---

## 2. Simpler than Blob (the payoff of a real tree)

| Blob loader | Files loader |
|---|---|
| `normalizeBlobPath` + trailing-slash prefix probing | `normalizePath` / `splitPath` over a real path |
| `isDirectChild` filtering (flat prefix returns all depths) | **gone** — `getFileList` returns only this directory's files; `getDirectoryList` returns only its sub-directories |
| Non-recursive = prefix listing + direct-child filter | Non-recursive = "just this directory's `getFileList`" |
| Recursive = one prefix listing at all depths | Recursive = `getFileList` + `getDirectoryList` then genuine recursion |
| `map<json>` `Properties` readers (`propString`/`propDecimal`) | typed `File.Properties` (`contentLengthOf`) |

---

## 3. Connector realities that shaped the implementation

Reading the `azure_storage_service.files` 4.3.4 source surfaced three behaviors that the
loader must accommodate — all verified in the connector code, not assumed:

### 3.1 Empty listing is an **error**, not an empty result
`getFileList` / `getDirectoryList` / `listShares` each return a distinct
`files:ProcessingError` when the listing is empty, with a sentinel message:

| Call | Empty sentinel (message) |
|---|---|
| `getFileList` | `No files found in received azure response` |
| `getDirectoryList` | `No directories found in received azure response` |
| `listShares` | `No any shares found in storage account` |

`isEmptyListing(error)` recognises these (a `files:ProcessingError` whose message contains a
sentinel) and the loader maps them to "nothing here", **not** a failure. This is the crux of
the phase: a directory with only sub-directories, or an empty share, must not abort the walk.

### 3.2 Missing vs empty is by **type**
A missing directory/share returns `files:NotFoundError` (HTTP 404); an existing-but-empty one
returns `files:ProcessingError`. So the loader disambiguates **missing** (`isNotFoundError`,
Phase 3) from **empty** (`isEmptyListing`) purely by error type — missing is tolerated only
under `"*"` (else a typo error), empty is always fine.

### 3.3 No server-driven pagination ⚠️ (deviation from the plan)
The plan calls for a `Marker` page loop. **This connector version cannot support it:** each
list method parses only the `<Entries>` subtree of the response and **discards `<NextMarker>`**
(`SharesList` has no marker field at all). So a listing returns a single page — Azure's
default of up to 5000 entries per directory. The loader therefore performs a single call per
directory/share and does **not** loop on a marker (doing so would spin on a never-populated
field). This is a documented connector limitation, not a loader shortcut; directories/shares
with >5000 entries would need a connector fix to page fully.

---

## 4. Behavior contract (mirrors the Blob loader)

- **Single file resolved** → returns that one `ai:Document` (not a 1-element array).
- **Explicitly named file** → always loaded, **ignoring** `includeExtensions`; a named
  non-text file errors, and a named Office file gets a format-specific error.
- **Files inside a directory listing** → filtered by `includeExtensions`; unsupported/Office
  files are skipped with a `log:printWarn`, never an error.
- **`"*"` share** → applies each path to every share; a path missing from a given share is
  skipped (`tolerateMissing`), not an error.
- **Ambiguous no-extension path that exists as neither file nor directory** → a typo error
  for a named share, skipped for `"*"`.

---

## 5. Tests (`ballerina/tests/loader_test.bal`) — 17 new, all offline

| Area | Tests |
|---|---|
| `normalizePath` | root forms (`""`/`"/"`/whitespace); leading-slash drop + trailing-slash keep. |
| `trimTrailingSlash` / `splitPath` | directory conversion; nested + share-root path split. |
| `toFileEntries` | array + single-`File` normalization; `Content-Length` parse; absent / empty-string `Properties` → `()` size; directory recorded per entry. |
| `directoryNames` / `shareNames` | single-or-array union normalization. |
| `isEmptyListing` | all three empty sentinels recognised; a real `ProcessingError`, a plain error, and a `NotFoundError` rejected. |
| `init` | empty sources rejected; named-share and `"*"` (management client) both construct offline. |

### Why `load()` itself isn't unit-tested
The connector clients are concrete `isolated client class` types (not mockable interfaces),
and `load()` makes real listing/download calls. As the Blob repo did, the connector-backed
orchestration is **not** unit-tested; it is exercised end-to-end by Phase 5's `live-test/`
sample against a real account. Everything unit-testable without a live client **is** tested
(the pure tree-walk helpers, the empty/missing/single-or-array logic, and `init`).

---

## 6. Verification

```bash
cd ballerina && bal test   # 54 passing, 0 failing
cd ballerina && bal build  # Generating executable → target/bin/ai.azure.storage.file.jar
```

54 = 21 text-layer + 7 type-shape + 9 client + 17 loader. **Gate met** for everything not
requiring live credentials; live tree-walk / recursion / `"*"` / extension-filter /
Office-rejection cases are the Phase 5 sample's job.

---

## 7. Phase 4 checklist

- [x] `TextDataLoader` (`*ai:DataLoader`) with `FileClient` (+ optional `ManagementClient`) and `readonly & Source[]`.
- [x] `load()` → `ai:Document[]|ai:Document|ai:Error`; single-file returns a bare document.
- [x] Resolve shares (`[share]` / `listShares` for `"*"`, `dedupeStrings`).
- [x] Resolve each path: explicit-file probe → 404 fallback to directory (`isNotFoundError`); typo detection for extension-y missing paths (honouring `tolerateMissing`).
- [x] List a directory: `getFileList` (+ `getDirectoryList` and recursion when `recursive`); extension filter; `buildDocument`; skip unsupported/Office with `log:printWarn`.
- [x] Handle the connector's empty-listing sentinels (`isEmptyListing`) and single-or-array unions.
- [x] Dropped Blob-only `isDirectChild` filtering (separate file/dir calls make it unnecessary).
- [x] 17 offline helper/init tests; `bal test` 54/54, `bal build` OK. **Gate met.**
- [!] **Deviation:** no `Marker` page loop — the connector discards `NextMarker` (single-page listings, ≤5000 entries). Documented in §3.3.
- [ ] (Deferred to Phase 5) Live tests: single file, non-recursive dir, recursive tree, `"*"` shares, extension filter, Office rejection.

**Next:** Phase 5 — tests/docs/sample: the mocked layers stay; add the `live-test/` sample
(copy the Blob one, `container` → `share`) for end-to-end verification, and write the
`README.md` / `ballerina/README.md` (swap container/blob/prefix → share/directory/file; drop
the "no real folders" caveat; keep the RFC-1123 timestamp caveat; note the single-page
listing limitation from §3.3).

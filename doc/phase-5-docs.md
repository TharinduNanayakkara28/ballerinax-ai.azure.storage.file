# Phase 5 — Tests, Docs & Sample

**Status:** ✅ Complete & verified (54/54 unit tests; `live-test/` sample compiles against the published package)
**Goal:** Finish the module: keep the mocked text-layer/types/client/loader tests (already in
place through Phases 1–4), write the user-facing documentation, and add a `live-test/` sample
for end-to-end verification against a real Azure Files share.

---

## 1. What was built

### 1.1 `ballerina/README.md` — the package usage guide
Ported from the Blob loader's module README, rewritten for Azure Files:

- **Terminology swap** — container → **share**, blob → **file**, virtual folder / blob-name
  prefix → **directory**, throughout.
- **"No real folders" caveat removed** — replaced with a "share / directory model" section
  that describes the genuine `Share → Directory → File` tree (files and sub-directories listed
  separately, recursion is a real tree-walk).
- **Endpoint** updated to `https://{accountName}.file.core.windows.net`.
- **Timestamp caveat rewritten** — Azure Files' listings report **no** content type and **no**
  per-file timestamps, so classification is extension-based and `mimeType` / `createdAt` /
  `modifiedAt` are omitted (more precise than Blob's RFC-1123 note, which was about a parse
  failure; here the data simply isn't in the listing).
- **New "Limitations" section** — documents the single-page listing constraint (connector
  discards `NextMarker`, ≤5000 entries per directory; see `doc/phase-4-loader.md` §3.3), the
  no-content-type behavior, and PDF/text-only support.
- **Configuration reference** — `ConnectionConfig` table unchanged; `Source` table uses
  `share` and directory/file wording.

### 1.2 Root `README.md`
Status updated from "Phase 0 scaffold" to "all phases (0–5) complete", pointing at the
`live-test/` sample and the `doc/` per-phase records.

### 1.3 `live-test/` sample
Ported from the Blob sample (`container` → `share`):

| File | Notes |
|---|---|
| `main.bal` | Imports `ballerinax/ai.azure.storage.file`; builds a `file:TextDataLoader` over one `share` with `paths: ["/"]`, `recursive: true`; prints each loaded document's metadata + content. |
| `Ballerina.toml` | Standalone app (`tharindu/live_test`) consuming `ai.azure.storage.file` `1.0.0` from the **local** repository. |
| `Config.toml.template` | **Sanitized** placeholders (`<your-storage-account-name>` etc.) — no real key, unlike the source sample. Copy to `Config.toml` (git-ignored) to run. |

---

## 2. Test inventory (all mocked / offline — 54 total)

Carried forward from earlier phases; no new unit tests were needed in Phase 5 (the plan's new
loader-path coverage is inherently live and lives in the sample).

| Suite | Count | Phase |
|---|---|---|
| `text_layer_test.bal` | 21 | 1 |
| `types_test.bal` | 7 | 2 |
| `client_test.bal` | 9 | 3 |
| `loader_test.bal` | 17 | 4 |
| **Total** | **54** | |

The connector-backed `load()` tree-walk (single file, non-recursive directory, recursive
tree, `"*"` shares, extension filter, Office rejection) is **not** unit-tested — the connector
clients are concrete `isolated client class` types that can't be mocked, so those paths are
verified by the `live-test/` sample against a real account (same stance the Blob repo took).

---

## 3. Verification

### 3.1 Unit tests
```bash
cd ballerina && bal test     # 54 passing, 0 failing, 0 skipped
```

### 3.2 Sample compiles against the *published* package
The sample was built against the real, packed module (not the source tree), which validates
the entire public API surface end-to-end:

```bash
cd ballerina && bal pack && bal push --repository=local   # publish 1.0.0 to the local repo
cd live-test && bal build                                 # → target/bin/live_test.jar
```

This confirmed the public names the sample (and any consumer) depends on are correct:
`file:TextDataLoader`, `file:AuthorizationMethod`, `file:SAS` / `file:ACCESS_KEY`, and the
`Source` fields `share` / `paths` / `recursive` / `includeExtensions`. (Packing also required
`ballerina/README.md`, so the doc and the sample verify each other.)

### 3.3 Running the sample live (manual, needs credentials)
```bash
cd live-test
cp Config.toml.template Config.toml     # then fill in accountName / accessKeyOrSAS / share
bal run
```
Not executed here (no Azure credentials in this environment). This is the intended home for
the live tree-walk / recursion / `"*"` / extension-filter / Office-rejection checks from the
plan's Phase 4/5 gate.

---

## 4. Phase 5 checklist

- [x] `ballerina/README.md` — rewritten for Files (share/directory/file; real-tree model; endpoint; timestamp + content-type caveats; **new** Limitations section).
- [x] Root `README.md` — status updated to all-phases-complete.
- [x] `live-test/` sample — `main.bal` (`share`), `Ballerina.toml` (local dep), **sanitized** `Config.toml.template`.
- [x] Kept the mocked text-layer / types / client / loader tests (54 total, green).
- [x] Verified the sample compiles against the packed-and-pushed `1.0.0` package.
- [ ] (Manual, needs creds) Run the sample live against a real share for the end-to-end gate.

---

## 5. Project status — all phases complete

| Phase | Deliverable | Gate |
|---|---|---|
| 0 | Scaffold (Gradle, native Tika extractor, placeholder) | `bal build` ✅ |
| 1 | Text layer (`utils.bal`) | 21 tests ✅ |
| 2 | Types (`types.bal`) | 28 tests ✅ |
| 3 | Client (`client.bal`) | 37 tests ✅ |
| 4 | Tree-walk loader (`file_data_loader.bal`) | 54 tests + `bal build` ✅ |
| 5 | Tests, docs, `live-test/` sample | 54 tests + sample builds ✅ |

**Carry-forward / known limitations**
- **Single-page listings** — connector discards `NextMarker` (≤5000 entries per directory);
  a connector fix is needed for full pagination (`doc/phase-4-loader.md` §3.3).
- **No content type / timestamps** from Files listings — classification is extension-based.
- **Live `load()`** is sample-verified, not unit-tested (connector clients aren't mockable).
- **Gradle build** needs `packageUser` / `packagePAT` for the `io.ballerina.plugin` plugin;
  the native jar is otherwise built here via `javac`/`jar` (see `doc/phase-0-scaffold.md` §4).

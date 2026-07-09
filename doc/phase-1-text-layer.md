# Phase 1 — Text-Conversion Layer

**Status:** ✅ Complete & verified (21/21 unit tests passing)
**Goal:** Port the service-agnostic text-conversion layer from the sibling Azure **Blob**
loader (`buildDocument` / `classify` / format constants / native `extractText`) into
`ballerinax/ai.azure.storage.file`, and unit-test PDF + plain-text extraction from raw
bytes — with **no HTTP, no connector, no live calls** (that arrives in Phases 3–4).

---

## 1. What was built

`ballerina/utils.bal` now holds the text layer, copied **verbatim** from the Blob
`utils.bal` except for the acquisition-only helpers (dropped) and two name edits:

- The `extractText` external binding points at the renamed Java class
  `io.ballerina.lib.ai.azure.storage.file.TextExtractor` (Phase 0's native jar).
- Two doc comments were retargeted from "blob"/"container" wording to Azure Files:
  `toUtc` now cites "Azure Files' directory/file listings" for the RFC 1123 caveat, and
  `dedupeStrings` cites de-duping "share names returned by a paginated `listShares`".

The Phase 0 placeholder `file_data_loader.bal` (which held a throwaway `API_VERSION`
const to make the empty package compile) was **left in place** for now — it still compiles
alongside `utils.bal` and will be superseded by the real loader in Phase 4. It carries no
text-layer logic.

### Functions & types ported
| Symbol | Role |
|---|---|
| `enum DocumentKind` | `PLAIN_TEXT` / `EXTRACTABLE` / `UNSUPPORTED_OFFICE` / `UNSUPPORTED` |
| `buildDocument(content, fileName, mimeType, fileSize, created, modified)` | `byte[]` → `ai:TextDocument?` \| `ai:Error`; the entry point |
| `classify(fileName, mimeType)` | MIME-then-extension routing to a `DocumentKind` |
| `extractText(content, fileName)` | `external` → native Apache Tika PDF extractor |
| `isUnsupportedOfficeDocument(fileName, mimeType)` | Office-format predicate |
| `getExtension(fileName)` | lower-cased extension without the dot |
| `matchesExtensionFilter(fileName, includeExtensions)` | case-insensitive, dot-tolerant allowlist; `()`/`[]` = all |
| `toUtc(dateTime)` | ISO 8601 → `time:Utc?` (drops unparseable) |
| `dedupeStrings(values)` | order-preserving de-dup (used by Phase 4's `"*"` share resolution) |
| `TEXT_*`, `EXTRACTABLE_*`, `OFFICE_*` constant lists | classification tables |

### Imports
Only `ballerina/ai`, `ballerina/jballerina.java`, `ballerina/time` — no `ballerina/http`
or connector import in the text layer.

---

## 2. What was intentionally NOT ported (Blob-only acquisition helpers)

Per the plan, the flat-namespace Blob helpers were **dropped** — Azure Files exposes a real
`Share → Directory → File` tree, so the prefix gymnastics disappear:

| Blob helper | Why dropped |
|---|---|
| `normalizeBlobPath` | Blob names are a flat namespace with simulated folders via `/`; Files has real directories, so path handling moves into the Phase 4 tree-walk. |
| `isDirectChild` | Non-recursive filtering of a flat prefix listing; unnecessary because `getFileList` / `getDirectoryList` return files and sub-directories from **separate** calls. |
| `propString` (`map<json>`) | Reads a blob's `Properties` JSON map; the `files` connector returns typed records, so JSON property-readers aren't needed. |
| `propDecimal` (`map<json>`) | Same — typed `Content-Length` etc. come straight off the connector's records (revisited in Phase 4). |

`dedupeStrings` was **kept** (generic, and reused by Phase 4's `listShares` de-dup).

---

## 3. Tests ported (`ballerina/tests/`)

| File | Notes |
|---|---|
| `fixtures.bal` | **Verbatim.** The PDFBox-generated `PDF_BYTES` fixture + its `PDF_TEXT` marker, exercised through the real native Tika extractor. |
| `text_layer_test.bal` | **Verbatim.** 21 `@test:Config` cases over `getExtension`, `classify`, `isUnsupportedOfficeDocument`, `matchesExtensionFilter`, `toUtc`, native `extractText`, and every `buildDocument` branch (plain text, PDF, invalid UTF-8 error, timestamp population/drop, unsupported binary/Office → `()`). |

### Deferred: `types_test.bal`
The Blob repo's `types_test.bal` was **not** ported in this phase. It imports
`ballerinax/azure_storage_service.blobs` and exercises `Source` / `ConnectionConfig` /
`toConnectorAuthMethod` / `toConnectorConfig` / `newBlobClient` / `BlobEntry` — none of
which exist yet. Including it now would break the build. It lands with its subjects:
`Source` / `ConnectionConfig` / `FileEntry` shape tests in **Phase 2**, and the
auth-mapping / client-construction tests in **Phase 3**.

---

## 4. Build & verification

The native jar from Phase 0 (`native/build/libs/ai.azure.storage.file-native-1.0.0.jar`,
containing `…/storage/file/TextExtractor.class`) is the compile/runtime target of the
`@java:Method` binding. With it in place:

```bash
cd ballerina && bal test
```

Result:

```
Compiling source
	ballerinax/ai.azure.storage.file:1.0.0
Running Tests
	ai.azure.storage.file
		[pass] testExtractTextFromPdfBytes
		[pass] testBuildDocumentPdfExtractsText
		... (21 total)
		21 passing
		0 failing
		0 skipped
```

The PDF cases prove the native Apache Tika path end-to-end (bytes → extracted text
containing the marker), so Phase 0's native wiring is confirmed correct in addition to the
pure Ballerina logic. **Gate met: `bal test` passes with no live calls.**

> As in Phase 0, the native jar is a git-ignored build artifact; `./gradlew build`
> regenerates it when creds (`packageUser`/`packagePAT`) are set.

---

## 5. Phase 1 checklist

- [x] Copy `utils.bal`; retarget `@java:Method` `'class` to `…storage.file.TextExtractor`.
- [x] Retarget the two "blob"/"container" doc comments (`toUtc`, `dedupeStrings`) to Files.
- [x] Drop Blob-only helpers (`normalizeBlobPath`, `isDirectChild`, `propString`, `propDecimal`).
- [x] Keep the text layer unchanged (`classify`, tables, `matchesExtensionFilter`, `getExtension`, `toUtc`, `dedupeStrings`, `buildDocument`).
- [x] Copy `tests/fixtures.bal` + `tests/text_layer_test.bal`.
- [x] `bal test` — 21/21 passing, no live calls. **Gate met.**
- [ ] (Deferred to Phase 2/3) Port `types_test.bal` alongside `types.bal` / `client.bal`.

**Next:** Phase 2 — `types.bal`: the `AuthorizationMethod` enum (identical), `ConnectionConfig`
(identical shape), `Source` (rename `container` → `share`), and `FileEntry` (replacing
`BlobEntry`: `name` / `directoryPath` / `contentLength` / optional `lastModified`).

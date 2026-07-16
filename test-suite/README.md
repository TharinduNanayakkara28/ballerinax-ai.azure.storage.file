# Azure Files Loader — Integration Test Suite

A standalone Ballerina package that exercises the `ballerinax/ai.azure.storage.file`
`TextDataLoader` end-to-end against a **real** Azure Storage account, through the
loader's **public API only**. The suite never creates, seeds, or deletes anything in
the account — you upload the fixtures once, manually, and the tests only read them.

## Layout

| Piece | Purpose |
| --- | --- |
| `manifest.bal` | **Source of truth**: every fixture path + its unique content marker, and the helpers all expectations derive from. |
| `fixtures/` | The generated fixture files, mirroring the exact share layout to upload. |
| `tests/integration_tests.bal` | The scenarios (test group `integration`). |
| `tests/Config.toml.template` | Copy to `tests/Config.toml` and fill in credentials. |

## One-time setup

### 1. Publish the loader to the local repository

The suite consumes the loader from the `local` Ballerina repository:

```sh
cd ../ballerina
bal pack
bal push --repository=local
```

Re-publishing after a loader change: delete the stale copy first, then repeat —

```sh
rm -rf ~/.ballerina/repositories/local/bala/ballerinax/ai.azure.storage.file \
       ~/.ballerina/repositories/local/cache-2201.12.0/ballerinax/ai.azure.storage.file
```

### 2. Create the test share and upload the fixtures

Create a **dedicated** file share (default name `loader-it`) — the whole-share
scenarios assume it contains exactly the fixture set, nothing else.

Upload `fixtures/` **preserving the directory structure**:

**Option A — Azure CLI (one command, paths preserved):**

```sh
az storage file upload-batch \
  --account-name <your-account> --account-key '<key1>' \
  --destination loader-it --source fixtures
```

**Option B — Azure Portal:** in the share's *Browse* view, create each directory
(`formats`, `pdfs`, `nested`, `nested/child`, `nested/child/grandchild`,
`unsupported`) with *+ Add directory*, then open each one and *Upload* the matching
files from `fixtures/`. Upload `root-marker.txt` at the share root.

**Then (both options): create one EMPTY directory named `empty`** at the share root
(*+ Add directory* in the portal — `upload-batch` cannot create it because it holds
no files). The empty-directory scenario needs it.

Expected final share contents (33 files + 1 empty directory):

```
root-marker.txt
formats/sample.{txt,text,md,markdown,csv,tsv,json,xml,html,htm,
                yaml,yml,log,ini,conf,properties,css,js,ts}   (19 files)
pdfs/single-page.pdf
pdfs/multi-page.pdf                                           (12 pages)
pdfs/scanned.pdf                                              (image-only, no text layer)
nested/root-note.txt
nested/child/child-note.txt
nested/child/grandchild/deep-note.txt
office/report.docx  office/report.xlsx  office/report.pptx   (POI OOXML)
office/legacy.doc   office/legacy.xls   office/legacy.ppt    (POI OLE2)
unsupported/pixel.png
empty/                                                        (no files)
```

### 3. Configure credentials

```sh
cp tests/Config.toml.template tests/Config.toml
# edit tests/Config.toml
```

> **Gotcha:** in this Ballerina distribution `bal test` reads `Config.toml` from the
> `tests/` **directory**, not the package root — keep it there. It is git-ignored.

## Running

```sh
bal test --groups integration
```

To eyeball every loaded document (name, mime, size, full extracted text), either
uncomment `printContent = true` in `tests/Config.toml`, or pass it on the CLI (note:
no `--` separator — this `bal` version treats `--` as a package path):

```sh
bal test --groups integration -CprintContent=true
```

## What is covered

- Whole-share loads, recursive and non-recursive.
- Direct decoding of all 19 supported text extensions (unique marker per format).
- Tika PDF extraction: a single-page PDF and a 12-page PDF asserted **page by page**
  (heading + `Page N of 12.` per page, unique sentinel on the last page).
- Apache POI Office extraction: all six formats — `.docx`/`.xlsx`/`.pptx` (OOXML) and
  legacy `.doc`/`.xls`/`.ppt` (OLE2) — each asserted to yield a document with its marker.
- Scanned (image-only) PDF handling: a descriptive error when named explicitly, and a
  warn-and-skip (not an abort) when discovered in a directory listing.
- The single-document-vs-array return contract.
- Extension filters, including dotted and mixed-case entries, and the rule that an
  explicitly named file bypasses the filter.
- Recursion into a direct child and a two-level-deep grandchild directory.
- Ambiguous file-or-directory path resolution (`/nested/child`).
- Metadata: `fileName` and `fileSize` populated; `mimeType`/`createdAt`/`modifiedAt`
  **absent** (Azure Files listings carry no content type, and their RFC-1123
  timestamps are dropped by the loader).
- Error paths: named image (non-text), missing named file, missing directory. Skip
  paths: unsupported files in listings, an empty directory, `paths: []`, multiple
  paths, and multiple sources.

Every count and marker assertion derives from `manifest.bal` — if you change a
fixture, change the manifest (and regenerate the file) in the same commit.

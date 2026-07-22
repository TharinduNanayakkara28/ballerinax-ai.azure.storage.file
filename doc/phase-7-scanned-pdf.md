# Phase 7 — Text-less PDF Detection (Scanned or Blank)

**Status:** ✅ Complete & verified (56/56 unit tests passing)
**Goal:** Stop text-less PDFs from silently producing **empty documents**. A scanned PDF is page
*images* wrapped in a PDF container — there is no text layer, and PDFBox extracts only the text
layer — so before this phase such a file parsed "successfully" and yielded an `ai:TextDocument`
with empty content, invisibly polluting downstream chunking/embedding. A genuinely **blank**
PDF (no text, no images) behaves identically.

---

## 1. Behavior

| Situation | Result |
|---|---|
| Text-less PDF **named explicitly** in `paths` | `ai:Error` — *"Failed to extract text from 'scan.pdf': the PDF contains no extractable text content (it may be a scanned/image-only document or an empty one); OCR is not supported"* |
| Text-less PDF **discovered in a directory listing** | Skipped with a `log:printWarn` (like other non-text content); the walk continues |

One **neutral message covers both cases** (scanned and blank): the loader cannot know which it
is without OCR, so it reports the fact — no extractable text — without guessing the cause.
This mirrors the loader's existing philosophy: explicitly naming an unreadable file is an error
worth surfacing; encountering one while sweeping a directory is a skip.

## 2. Implementation

- **`native/TextExtractor.java`** — after a successful parse by `PDFParser`, if the extracted
  text is empty (trimmed), return a descriptive error (`TEXTLESS_PDF_MESSAGE`) instead of the
  empty string. Detection is deliberately simple: parsed OK + zero text.
- **OCR fallback disabled explicitly** — Tika 3.x's `PDFParser` defaults to an *auto* OCR
  strategy: on image-only pages it reaches for its Tesseract integration, which is not shipped,
  and **NPEs** (`this.ocrParser is null`). `TextExtractor` now sets
  `PDFParserConfig.OCR_STRATEGY.NO_OCR` in the `ParseContext`, so the parser returns cleanly and
  the empty-text detection above takes over.
- **`ballerina/utils.bal`** — `isTextlessPdfError` recognises the sentinel phrase
  (`"no extractable text"`), the same message-matching pattern as `isEmptyListing`.
- **`ballerina/file_data_loader.bal`** — `listDirectory` catches a text-less-PDF error from
  `toDocument` and converts it to warn-and-skip; every other extraction error still aborts, and
  the explicit-file path (`loadPath`) propagates the error unchanged.

## 3. Tests & fixtures

- `tests/fixtures.bal` — `SCANNED_PDF_BYTES`: a hand-built one-page PDF containing a single
  image XObject and **no text operators** (structurally what a scanner produces); verified to
  parse with 0 extracted characters via PDFBox before being trusted. `BLANK_PDF_BYTES`: a
  one-page PDF with an empty content stream — no text, no images.
- Unit tests: `testExtractTextFromScannedPdfErrors`, `testExtractTextFromBlankPdfErrors`,
  `testBuildDocumentScannedPdfErrors`, `testIsTextlessPdfErrorRejectsOtherErrors`.
- Integration suite: `pdfs/scanned.pdf` fixture (manifest `supported: false`) with
  `testNamedScannedPdfIsAnError` and `testScannedPdfIsSkippedInDirectoryListing`.

## 4. Reading scanned PDFs for real (future work)

Detection tells you a scan exists; *reading* one needs OCR:
- **Tesseract via Tika** (`tika-parser-ocr-module` + the native `tesseract` binary installed on
  the host) — free/local, but a deployment burden for a library.
- **Azure AI Document Intelligence** — managed OCR, a natural fit for an Azure loader, at the
  cost of credentials, latency, and per-page pricing.

Neither is pure-Java; that is why the default posture is detect-and-report rather than OCR.

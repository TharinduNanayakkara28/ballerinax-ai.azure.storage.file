// Integration tests for the ballerinax/ai.azure.storage.file TextDataLoader, run
// against a REAL Azure Storage account. The suite only uses the loader's public API
// and only READS the share — the fixtures (see ../fixtures and ../manifest.bal) are
// uploaded manually, and nothing is created, seeded, or deleted here.
//
// Configuration comes from Config.toml in THIS directory (tests/) — in this Ballerina
// distribution `bal test` reads Config.toml from the tests/ directory, not the package
// root. Copy Config.toml.template to Config.toml and fill it in.
//
// Run:   bal test --groups integration
// Debug: bal test --groups integration -- -CprintContent=true   (prints every document)

import ballerina/ai;
import ballerina/io;
import ballerina/test;
import ballerinax/ai.azure.storage.file;
import ballerinax/azure_storage_service.files;

configurable string accountName = "";
configurable string accessKeyOrSAS = "";
configurable string authMethod = "ACCESS_KEY"; // "ACCESS_KEY" or "SAS"
configurable string testShare = "";
// When true, every loaded document is printed (name, mime, chars, full text)
// so results can be eyeballed. Off by default to keep test output readable.
configurable boolean printContent = false;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function newLoader(file:Source[] sources) returns file:TextDataLoader|ai:Error {
    if accountName == "" || accessKeyOrSAS == "" || testShare == "" {
        panic error("Missing test configuration: copy tests/Config.toml.template to " +
            "tests/Config.toml and set accountName, accessKeyOrSAS, authMethod, and testShare");
    }
    files:ConnectionConfig config = {
        accountName,
        accessKeyOrSAS,
        authorizationMethod: authMethod == "SAS" ? files:SAS : files:ACCESS_KEY
    };
    file:TextDataLoader loader = check new (config, sources);
    return loader;
}

// Builds a loader over the test share with a single source and loads it.
function load(string[] paths, boolean recursive = false, string[]? includeExtensions = ())
        returns ai:Document[]|ai:Document|ai:Error {
    file:TextDataLoader loader = check newLoader([
        {share: testShare, paths, recursive, includeExtensions}
    ]);
    ai:Document[]|ai:Document result = check loader.load();
    dump(result);
    return result;
}

function toArray(ai:Document[]|ai:Document result) returns ai:Document[] =>
    result is ai:Document[] ? result : [result];

function contentOf(ai:Document doc) returns string {
    if doc is ai:TextDocument {
        return doc.content;
    }
    panic error("Expected an ai:TextDocument in the loaded results");
}

function dump(ai:Document[]|ai:Document result) {
    if !printContent {
        return;
    }
    foreach ai:Document doc in toArray(result) {
        if doc is ai:TextDocument {
            string name = doc.metadata?.fileName ?: "<unnamed>";
            string mime = doc.metadata?.mimeType ?: "-";
            io:println("--------------------------------------------------");
            io:println("file  : ", name);
            io:println("mime  : ", mime);
            io:println("size  : ", doc.metadata?.fileSize ?: "-");
            io:println("chars : ", doc.content.length());
            io:println(doc.content);
        }
    }
}

// Asserts the loaded documents are EXACTLY the expected fixtures: same count, and each
// fixture's unique marker appears in exactly one document whose fileName matches.
function assertDocsMatch(ai:Document[] docs, Fixture[] expected) {
    test:assertEquals(docs.length(), expected.length(),
        string `Expected ${expected.length()} documents but loaded ${docs.length()}`);
    foreach Fixture fixture in expected {
        int matches = 0;
        foreach ai:Document doc in docs {
            if contentOf(doc).includes(fixture.marker) {
                matches += 1;
                if doc is ai:TextDocument {
                    test:assertEquals(doc.metadata?.fileName, leafOf(fixture.path),
                        string `Document carrying '${fixture.marker}' has the wrong fileName`);
                }
            }
        }
        test:assertEquals(matches, 1,
            string `Marker '${fixture.marker}' (${fixture.path}) found in ${matches} documents, expected exactly 1`);
    }
}

function assertIsError(ai:Document[]|ai:Document|ai:Error result, string expectedFragment) {
    if result is ai:Error {
        test:assertTrue(result.message().includes(expectedFragment),
            string `Error message '${result.message()}' does not mention '${expectedFragment}'`);
        return;
    }
    test:assertFail(string `Expected an error mentioning '${expectedFragment}', got ${toArray(result).length()} document(s)`);
}

// ---------------------------------------------------------------------------
// Whole-share loads
// ---------------------------------------------------------------------------

@test:Config {groups: ["integration"]}
function testWholeShareRecursive() returns error? {
    ai:Document[] docs = toArray(check load(["/"], recursive = true));
    assertDocsMatch(docs, expectedInDirectory("", true));
}

@test:Config {groups: ["integration"]}
function testWholeShareNonRecursiveLoadsOnlyRootFiles() returns error? {
    // Only root-marker.txt sits at the share root, so this resolves to a single
    // document — and the loader's contract returns it BARE, not as an array.
    ai:Document[]|ai:Document result = check load(["/"]);
    test:assertTrue(result !is ai:Document[], "A single resolved file must be returned bare");
    assertDocsMatch(toArray(result), expectedInDirectory("", false));
}

// ---------------------------------------------------------------------------
// Text formats
// ---------------------------------------------------------------------------

@test:Config {groups: ["integration"]}
function testEveryTextFormatDecodes() returns error? {
    // formats/ holds one file per supported text extension; a directory load of it
    // must decode all of them, each carrying its FORMAT_MARKER_<EXT>.
    ai:Document[] docs = toArray(check load(["/formats/"]));
    assertDocsMatch(docs, expectedInDirectory("formats", false));
}

// ---------------------------------------------------------------------------
// PDF extraction (Apache Tika)
// ---------------------------------------------------------------------------

@test:Config {groups: ["integration"]}
function testSinglePagePdfExtracts() returns error? {
    ai:Document[]|ai:Document result = check load(["/pdfs/single-page.pdf"]);
    test:assertTrue(result !is ai:Document[], "A single named file must be returned bare");
    assertDocsMatch(toArray(result), [fixtureAt("pdfs/single-page.pdf")]);
}

@test:Config {groups: ["integration"]}
function testMultiPagePdfExtractsEveryPage() returns error? {
    ai:Document[]|ai:Document result = check load(["/pdfs/multi-page.pdf"]);
    ai:Document[] docs = toArray(result);
    test:assertEquals(docs.length(), 1, "The multi-page PDF is one file, hence one document");
    string text = contentOf(docs[0]);

    test:assertTrue(text.includes("PDF_MARKER_MULTI_PAGE"), "Shared per-page marker missing");
    foreach int page in 1 ... MULTI_PAGE_COUNT {
        test:assertTrue(text.includes(string `Page ${page} of ${MULTI_PAGE_COUNT}.`),
            string `Extracted text is missing page ${page} of ${MULTI_PAGE_COUNT}`);
        test:assertTrue(text.includes(string `${MULTI_PAGE_HEADING_PREFIX} ${page}: Quarterly Findings`),
            string `Extracted text is missing the page-${page} heading`);
    }
    test:assertTrue(text.includes(MULTI_PAGE_FINAL_SENTINEL),
        "The last page's unique sentinel is missing — extraction may have been truncated");
}

// ---------------------------------------------------------------------------
// Single-vs-array contract
// ---------------------------------------------------------------------------

@test:Config {groups: ["integration"]}
function testMultipleFilesReturnAnArray() returns error? {
    ai:Document[]|ai:Document result = check load(["/formats/"]);
    test:assertTrue(result is ai:Document[], "Multiple resolved files must come back as an array");
}

// ---------------------------------------------------------------------------
// Extension filters
// ---------------------------------------------------------------------------

@test:Config {groups: ["integration"]}
function testExtensionFilterSingleType() returns error? {
    ai:Document[] docs = toArray(check load(["/formats/"], includeExtensions = ["json"]));
    assertDocsMatch(docs, expectedInDirectory("formats", false, ["json"]));
}

@test:Config {groups: ["integration"]}
function testExtensionFilterDottedAndMixedCase() returns error? {
    // The loader normalizes allowlist entries: case-insensitive, leading dot optional.
    string[] filter = [".Md", "TXT"];
    ai:Document[] docs = toArray(check load(["/"], recursive = true, includeExtensions = filter));
    assertDocsMatch(docs, expectedInDirectory("", true, filter));
}

@test:Config {groups: ["integration"]}
function testExplicitlyNamedFileBypassesExtensionFilter() returns error? {
    // sample.json does not match the ["txt"] filter, but an explicitly named file is
    // always loaded — the filter applies only to directory listings.
    ai:Document[]|ai:Document result = check load(["/formats/sample.json"], includeExtensions = ["txt"]);
    assertDocsMatch(toArray(result), [fixtureAt("formats/sample.json")]);
}

// ---------------------------------------------------------------------------
// Nested directories & recursion
// ---------------------------------------------------------------------------

@test:Config {groups: ["integration"]}
function testNestedNonRecursiveStopsAtFirstLevel() returns error? {
    ai:Document[] docs = toArray(check load(["/nested/"]));
    assertDocsMatch(docs, expectedInDirectory("nested", false));
}

@test:Config {groups: ["integration"]}
function testNestedRecursiveDescendsTwoLevels() returns error? {
    ai:Document[] docs = toArray(check load(["/nested/"], recursive = true));
    assertDocsMatch(docs, expectedInDirectory("nested", true));
}

@test:Config {groups: ["integration"]}
function testAmbiguousPathResolvesToDirectory() returns error? {
    // "/nested/child" has no trailing slash and no extension: the loader first probes
    // it as a file, gets a 404, and falls back to listing it as a directory.
    ai:Document[] docs = toArray(check load(["/nested/child"]));
    assertDocsMatch(docs, expectedInDirectory("nested/child", false));
}

// ---------------------------------------------------------------------------
// Metadata
// ---------------------------------------------------------------------------

@test:Config {groups: ["integration"]}
function testDocumentMetadata() returns error? {
    ai:Document[]|ai:Document result = check load(["/formats/sample.json"]);
    ai:Document doc = toArray(result)[0];
    if doc !is ai:TextDocument {
        return error("Expected an ai:TextDocument");
    }
    test:assertEquals(doc.metadata?.fileName, "sample.json");
    decimal? fileSize = doc.metadata?.fileSize;
    if fileSize is decimal {
        test:assertTrue(fileSize > 0d, "fileSize must be positive");
        test:assertEquals(fileSize, <decimal>doc.content.toBytes().length(),
            "fileSize must equal the file's byte length");
    } else {
        test:assertFail("fileSize missing from metadata");
    }
    // Azure Files listings/downloads surface NO content type, and their timestamps are
    // RFC 1123 (dropped by the loader) — so these must be ABSENT, per the loader's code.
    test:assertTrue(doc.metadata?.mimeType is (), "mimeType must be absent for Azure Files");
    test:assertTrue(doc.metadata?.createdAt is (), "createdAt must be absent for Azure Files");
    test:assertTrue(doc.metadata?.modifiedAt is (), "modifiedAt must be absent for Azure Files");
}

// ---------------------------------------------------------------------------
// Error & skip paths
// ---------------------------------------------------------------------------

@test:Config {groups: ["integration"]}
function testNamedOfficeFileIsAnError() {
    assertIsError(load(["/unsupported/summary.docx"]), "Microsoft Office");
}

@test:Config {groups: ["integration"]}
function testNamedImageIsAnError() {
    assertIsError(load(["/unsupported/pixel.png"]), "non-text");
}

@test:Config {groups: ["integration"]}
function testMissingNamedFileIsAnError() {
    // The path looks like a file (has an extension) and doesn't exist -> typo detection.
    assertIsError(load(["/no-such-dir/ghost.pdf"]), "file not found");
}

@test:Config {groups: ["integration"]}
function testMissingDirectoryIsAnError() {
    assertIsError(load(["/no-such-dir/"]), "was not found");
}

@test:Config {groups: ["integration"]}
function testUnsupportedFilesAreSkippedInDirectoryListings() returns error? {
    // unsupported/ holds only an image and Office documents: listing it must SKIP all
    // of them (with logged warnings) and produce zero documents — not an error.
    ai:Document[] docs = toArray(check load(["/unsupported/"]));
    test:assertEquals(docs.length(), 0, "All files in unsupported/ must be skipped");
}

@test:Config {groups: ["integration"]}
function testEmptyDirectoryYieldsNoDocuments() returns error? {
    // Requires the manually created, file-less "empty" directory in the share.
    ai:Document[] docs = toArray(check load([string `/${EMPTY_DIRECTORY}/`]));
    test:assertEquals(docs.length(), 0, "An existing-but-empty directory yields no documents");
}

@test:Config {groups: ["integration"]}
function testEmptyPathsLoadNothing() returns error? {
    ai:Document[] docs = toArray(check load([]));
    test:assertEquals(docs.length(), 0, "paths: [] must load nothing");
}

// ---------------------------------------------------------------------------
// Multiple paths & multiple sources
// ---------------------------------------------------------------------------

@test:Config {groups: ["integration"]}
function testMultiplePathsInOneSource() returns error? {
    ai:Document[] docs = toArray(check load(["/root-marker.txt", "/pdfs/single-page.pdf"]));
    assertDocsMatch(docs, [fixtureAt("root-marker.txt"), fixtureAt("pdfs/single-page.pdf")]);
}

@test:Config {groups: ["integration"]}
function testMultipleSourcesCombine() returns error? {
    file:TextDataLoader loader = check newLoader([
        {share: testShare, paths: ["/formats/"], includeExtensions: ["json"]},
        {share: testShare, paths: ["/nested/"], recursive: true}
    ]);
    ai:Document[]|ai:Document result = check loader.load();
    dump(result);
    Fixture[] expected = expectedInDirectory("formats", false, ["json"]);
    expected.push(...expectedInDirectory("nested", true));
    assertDocsMatch(toArray(result), expected);
}

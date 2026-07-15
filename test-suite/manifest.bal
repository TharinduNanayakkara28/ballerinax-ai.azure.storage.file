// The single source of truth for the integration-test fixtures: every file the suite
// expects to find in the Azure Files test share, with the unique content marker each
// one carries. All scenario expectations are DERIVED from this manifest via the
// helpers below — tests never hard-code counts or paths.
//
// The files themselves are generated into `fixtures/` (mirroring these paths) and are
// uploaded manually — this suite only ever READS from the share.

# One fixture file in the test share.
public type Fixture record {|
    # Share-relative path, e.g. `formats/sample.txt` (no leading slash).
    string path;
    # A unique marker string embedded in the file's content; `""` for files the
    # loader cannot represent as text (they never produce a document).
    string marker;
    # Whether the loader can load this file as a text document.
    boolean supported;
|};

# Every file expected in the test share. Markers are stable — do not edit them
# without regenerating the fixture files.
public final readonly & Fixture[] FIXTURES = [
    // --- share root -----------------------------------------------------------
    {path: "root-marker.txt", marker: "ROOT_MARKER_SHARE_ROOT", supported: true},

    // --- formats/: one file per text extension the loader supports -------------
    {path: "formats/sample.txt", marker: "FORMAT_MARKER_TXT", supported: true},
    {path: "formats/sample.text", marker: "FORMAT_MARKER_TEXT", supported: true},
    {path: "formats/sample.md", marker: "FORMAT_MARKER_MD", supported: true},
    {path: "formats/sample.markdown", marker: "FORMAT_MARKER_MARKDOWN", supported: true},
    {path: "formats/sample.csv", marker: "FORMAT_MARKER_CSV", supported: true},
    {path: "formats/sample.tsv", marker: "FORMAT_MARKER_TSV", supported: true},
    {path: "formats/sample.json", marker: "FORMAT_MARKER_JSON", supported: true},
    {path: "formats/sample.xml", marker: "FORMAT_MARKER_XML", supported: true},
    {path: "formats/sample.html", marker: "FORMAT_MARKER_HTML", supported: true},
    {path: "formats/sample.htm", marker: "FORMAT_MARKER_HTM", supported: true},
    {path: "formats/sample.yaml", marker: "FORMAT_MARKER_YAML", supported: true},
    {path: "formats/sample.yml", marker: "FORMAT_MARKER_YML", supported: true},
    {path: "formats/sample.log", marker: "FORMAT_MARKER_LOG", supported: true},
    {path: "formats/sample.ini", marker: "FORMAT_MARKER_INI", supported: true},
    {path: "formats/sample.conf", marker: "FORMAT_MARKER_CONF", supported: true},
    {path: "formats/sample.properties", marker: "FORMAT_MARKER_PROPERTIES", supported: true},
    {path: "formats/sample.css", marker: "FORMAT_MARKER_CSS", supported: true},
    {path: "formats/sample.js", marker: "FORMAT_MARKER_JS", supported: true},
    {path: "formats/sample.ts", marker: "FORMAT_MARKER_TS", supported: true},

    // --- pdfs/: the Tika extraction path ---------------------------------------
    {path: "pdfs/single-page.pdf", marker: "PDF_MARKER_SINGLE_PAGE", supported: true},
    {path: "pdfs/multi-page.pdf", marker: "PDF_MARKER_MULTI_PAGE", supported: true},

    // --- nested/: recursion (direct child + 2-level-deep child) ----------------
    {path: "nested/root-note.txt", marker: "NESTED_MARKER_ROOT_NOTE", supported: true},
    {path: "nested/child/child-note.txt", marker: "NESTED_MARKER_CHILD_NOTE", supported: true},
    {path: "nested/child/grandchild/deep-note.txt", marker: "NESTED_MARKER_DEEP_NOTE", supported: true},

    // --- unsupported/: skipped in listings, error when named explicitly --------
    {path: "unsupported/pixel.png", marker: "", supported: false},
    {path: "unsupported/summary.docx", marker: "", supported: false},
    {path: "unsupported/legacy.doc", marker: "", supported: false}
];

# The multi-page PDF's page count (each page carries `Page N of 12.`).
public const int MULTI_PAGE_COUNT = 12;
# The sentinel sentence that appears ONLY on the multi-page PDF's last page.
public const string MULTI_PAGE_FINAL_SENTINEL = "MULTI_PAGE_FINAL_SENTINEL_7F3D9A";
# Heading prefix on every page of the multi-page PDF (`Section N: Quarterly Findings`).
public const string MULTI_PAGE_HEADING_PREFIX = "Section";

# The name of a directory that must exist in the share but contain NO files
# (created manually in the portal: File shares -> Browse -> Add directory).
public const string EMPTY_DIRECTORY = "empty";

// ---------------------------------------------------------------------------
// Expectation helpers — these replicate the loader's own matching semantics
// (see ballerina/utils.bal and file_data_loader.bal in the loader package).
// ---------------------------------------------------------------------------

# Returns the directory portion of a share-relative path.
#
# + path - a share-relative path, e.g. `formats/sample.txt`
# + return - the directory part (`""` for the share root)
public isolated function directoryOf(string path) returns string {
    int? lastSlash = path.lastIndexOf("/");
    return lastSlash is () ? "" : path.substring(0, lastSlash);
}

# Returns the leaf file name of a share-relative path.
#
# + path - a share-relative path, e.g. `formats/sample.txt`
# + return - the file name, e.g. `sample.txt`
public isolated function leafOf(string path) returns string {
    int? lastSlash = path.lastIndexOf("/");
    return lastSlash is () ? path : path.substring(lastSlash + 1);
}

// Lower-cased extension without the dot, mirroring the loader's `getExtension`.
isolated function extensionOf(string fileName) returns string {
    int? lastDot = fileName.lastIndexOf(".");
    return lastDot is () ? "" : fileName.substring(lastDot + 1).toLowerAscii();
}

// Mirrors the loader's `matchesExtensionFilter`: `()`/empty matches all; entries are
// case-insensitive and a leading dot is optional.
isolated function matchesFilter(string fileName, string[]? includeExtensions) returns boolean {
    if includeExtensions is () || includeExtensions.length() == 0 {
        return true;
    }
    string extension = extensionOf(fileName);
    foreach string allowed in includeExtensions {
        string normalized = allowed.toLowerAscii();
        if normalized.startsWith(".") {
            normalized = normalized.substring(1);
        }
        if normalized == extension {
            return true;
        }
    }
    return false;
}

# The fixtures a DIRECTORY load of `directory` must produce as documents.
#
# + directory - share-relative directory (`""` for the share root), no slashes at either end
# + recursive - whether sub-directories are traversed
# + includeExtensions - the loader's extension allowlist (applies to directory loads only)
# + return - the expected fixtures, in manifest order
public isolated function expectedInDirectory(string directory, boolean recursive,
        string[]? includeExtensions = ()) returns Fixture[] {
    Fixture[] expected = [];
    foreach Fixture fixture in FIXTURES {
        if !fixture.supported || !matchesFilter(leafOf(fixture.path), includeExtensions) {
            continue;
        }
        string fixtureDir = directoryOf(fixture.path);
        boolean inScope = recursive
            ? fixtureDir == directory || directory == "" || fixtureDir.startsWith(directory + "/")
            : fixtureDir == directory;
        if inScope {
            expected.push(fixture);
        }
    }
    return expected;
}

# Looks a fixture up by its share-relative path (panics on a typo in a test).
#
# + path - the share-relative fixture path, exactly as listed in `FIXTURES`
# + return - the matching manifest entry
public isolated function fixtureAt(string path) returns Fixture {
    foreach Fixture fixture in FIXTURES {
        if fixture.path == path {
            return fixture;
        }
    }
    panic error(string `No fixture at '${path}' — check the test against the manifest`);
}

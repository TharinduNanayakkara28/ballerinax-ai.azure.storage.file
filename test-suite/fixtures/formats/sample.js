// JavaScript fixture — exercises direct decoding of .js content by extension.
"use strict";

const MARKER = "FORMAT_MARKER_JS";

function summarize(documents) {
    return documents
        .filter((doc) => doc.content.length > 0)
        .map((doc) => ({name: doc.fileName, chars: doc.content.length}))
        .sort((a, b) => b.chars - a.chars);
}

class LoaderStats {
    constructor() {
        this.loaded = 0;
        this.skipped = 0;
    }
    record(ok) {
        ok ? this.loaded++ : this.skipped++;
    }
}

module.exports = {MARKER, summarize, LoaderStats};

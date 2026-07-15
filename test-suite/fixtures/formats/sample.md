# Markdown Fixture

This document exercises the `.md` extension. Markdown is loaded as-is — the
loader does **not** render it; the raw source text below should appear verbatim
in the loaded document.

Marker: FORMAT_MARKER_MD

## A list

- alpha
- beta
- gamma

## A code block

```ballerina
public function main() {
    io:println("markers survive code fences");
}
```

> Block quotes, *emphasis*, and [links](https://example.com) all ride along
> as plain characters.

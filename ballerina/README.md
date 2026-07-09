# Ballerina Azure Files Data Loader

The `ballerinax/ai.azure.storage.file` module provides a `TextDataLoader` that retrieves documents from Azure Files shares and returns them as `ai:TextDocument` values, ready to be chunked, embedded, and indexed by the [Ballerina AI](https://central.ballerina.io/ballerina/ai) module. Inherently textual files are decoded directly, while PDF documents have their text extracted with Apache Tika.

It implements the `ai:DataLoader` abstraction, so it can be used anywhere an `ai:DataLoader` is expected (for example, in a Retrieval-Augmented Generation ingestion pipeline).

The acquisition layer — authentication, directory/file listing, and download — is delegated to the [`ballerinax/azure_storage_service.files`](https://central.ballerina.io/ballerinax/azure_storage_service.files) connector.

## Overview

- Reads files from one or more Azure Files **shares** in a storage account.
- Loads individual files as well as entire **directories**, optionally recursively.
- Reads from multiple shares — including **every** share in the account — with a single loader instance.
- Walks the real `Share → Directory → File` tree: files and sub-directories are listed separately, so recursion is a genuine tree-walk (no blob-name-prefix simulation).
- Returns every file as an `ai:TextDocument`, based on its extension:
  - Inherently textual files (e.g. `txt`, `md`, `html`, `json`, `csv`, `xml`) are decoded directly.
  - `pdf` files have their text extracted with Apache Tika.
  - Other files that cannot be represented as text (e.g. images, audio, archives) are skipped with a
    logged warning; explicitly naming such a file as a path is an error.
  - Microsoft Office documents (`.doc`, `.docx`, `.ppt`, `.pptx`, `.xls`, `.xlsx`) are **not** supported —
    they are skipped in directory listings and rejected with an error when named explicitly.

## Authentication

Azure Files is accessed through the `ballerinax/azure_storage_service.files` connector, which supports two authorization mechanisms. Both are configured through `ConnectionConfig.accessKeyOrSAS` together with `ConnectionConfig.authorizationMethod`:

| Mechanism | `authorizationMethod` | `accessKeyOrSAS` holds | Best for |
| --- | --- | --- | --- |
| Shared Access Signature (SAS) | `SAS` | A SAS token (the query string, e.g. `sv=...&sig=...`) | Scoped, time-limited, pre-signed access without sharing an account key |
| Shared Key (account access key) | `ACCESS_KEY` | One of the storage account's access keys | Full-account, server-to-server access; the connector signs each request with HMAC-SHA256 |

> **Note:** Azure AD / Microsoft Entra ID (OAuth2) is **not** supported in this version, as the underlying connector authorizes with Shared Key and SAS only.

The service endpoint is derived from the account name as `https://{accountName}.file.core.windows.net`.

## Usage

### Initialization

```ballerina
import ballerina/ai;
import ballerinax/ai.azure.storage.file;

final file:TextDataLoader loader = check new (
    {
        accountName: "contosostorage",
        accessKeyOrSAS: "sv=2022-11-02&ss=f&srt=co&sp=rl&sig=...",
        authorizationMethod: file:SAS
    },
    [
        {
            // Load one explicit file plus everything under /onboarding (recursively),
            // restricted to PDFs.
            share: "documents",
            paths: ["/policies/leave-policy.pdf", "/onboarding"],
            recursive: true,
            includeExtensions: ["pdf"]
        },
        {
            // A bare share name loads the whole share (non-recursive).
            share: "specs",
            paths: ["/api-design.md"]
        }
    ]
);
```

### The share / directory model

Unlike Azure Blob Storage's flat namespace, an Azure Files share is a real directory tree: a share holds directories, directories hold files and further sub-directories (e.g. `reports/2026/q1.pdf`). This loader maps a configured **path** onto a directory or a file:

- **A path with a trailing `/`, or the share root (`/`)** is treated as a directory and listed.
- **A path without a trailing `/`** is first tried as an explicitly named file. If an exact file exists it is loaded directly (and always loaded, regardless of the extension filter). If no such file exists, the path is treated as a directory — unless it looks like a file (has an extension), in which case a missing file is reported as an error to help catch typos.
- **A deliberately named non-text file** (an image, an Office document, etc.) is an **error**, whereas the same file discovered while listing a directory is skipped with a warning.

`paths` defaults to `["/"]`, so a `Source` with only a `share` loads the whole share; set `paths` to `[]` to load nothing.

### Recursion

By default a directory loads only the files **directly** inside it. Set `recursive: true` to include files in every sub-directory beneath it:

```ballerina
{share: "documents", paths: ["/reports"], recursive: true}
```

### Reading from every share

Set `share` to `"*"` to read from **every** share in the storage account. Because the `paths` are then applied to all shares, a path that does not exist in a given share is **skipped** for it rather than treated as an error:

```ballerina
{share: "*", paths: ["/shared"], recursive: true}
```

### Filtering by file type

Each `Source` has its own `includeExtensions` to restrict which files are loaded from directories:

- `includeExtensions: ["pdf"]` — only PDF files.
- `includeExtensions: ["pdf", ".md", "TXT"]` — case-insensitive; a leading dot is optional.
- omitted / `()` (the default) — load all types.

The filter applies to files discovered while listing a directory. A file listed **explicitly** in `paths` is always loaded, even if its extension isn't in the list.

### Loading documents

```ballerina
public function main() returns error? {
    ai:Document[]|ai:Document documents = check loader.load();
    // Pass the documents to a chunker / embedding provider / vector store ...
}
```

`load()` returns a single `ai:Document` when exactly one file is resolved, and an `ai:Document[]` otherwise (mirroring `ai:TextDataLoader`).

Each returned `ai:TextDocument` carries metadata including the file name (`fileName`) and — when reported by Azure — the `fileSize`.

> **Note:** Azure Files' directory/file listings do not report a content type or per-file timestamps. Classification therefore relies on the file extension, and `mimeType` / `createdAt` / `modifiedAt` are omitted from the document metadata.

## Limitations

- **Single-page listings.** The underlying connector (`azure_storage_service` 4.3.4) does not surface the Azure continuation marker (`NextMarker`) for directory, file, or share listings, so each listing returns a single page — Azure's default of up to 5000 entries per directory. Shares or directories with more than 5000 immediate entries are not paged fully. Recursion into sub-directories is unaffected.
- **No content type from listings.** As noted above, classification is extension-based.
- **PDF and text only.** Microsoft Office formats are not supported (see the Overview).

## Configuration reference

### `ConnectionConfig`

| Field | Type | Default | Description |
| --- | --- | --- | --- |
| `accountName` | `string` | — | The Azure Storage account name; used to build the file service endpoint |
| `accessKeyOrSAS` | `string` | — | An account access key or a SAS token, interpreted per `authorizationMethod` |
| `authorizationMethod` | `AuthorizationMethod` | — | `ACCESS_KEY` (Shared Key) or `SAS` |
| `httpVersion` | `http:HttpVersion` | `http:HTTP_1_1` | HTTP version understood by the client |
| `http2Settings` | `http:ClientHttp2Settings` | — | HTTP/2 protocol settings |
| `timeout` | `decimal` | `30` | Response timeout, in seconds |
| `forwarded` | `string` | `"disable"` | Handling of the `forwarded`/`x-forwarded` header |
| `poolConfig` | `http:PoolConfiguration` | — | Request pooling configuration |
| `cache` | `http:CacheConfig` | — | HTTP caching configuration |
| `compression` | `http:Compression` | `http:COMPRESSION_AUTO` | `accept-encoding` handling |
| `circuitBreaker` | `http:CircuitBreakerConfig` | — | Circuit breaker configuration |
| `retryConfig` | `http:RetryConfig` | — | Retry configuration |
| `responseLimits` | `http:ResponseLimitConfigs` | — | Inbound response size limits |
| `secureSocket` | `http:ClientSecureSocket` | — | SSL/TLS options |
| `proxy` | `http:ProxyConfig` | — | Proxy server options |
| `validation` | `boolean` | `true` | Inbound payload validation |

The HTTP-level fields are forwarded to the underlying `ballerinax/azure_storage_service.files` client.

### `Source`

| Field | Type | Default | Description |
| --- | --- | --- | --- |
| `share` | `string` | — | The share name to read from, or `"*"` for every share in the account |
| `paths` | `string[]` | `["/"]` | Directory paths and/or explicit file names. The default `["/"]` loads the whole share; `[]` loads nothing |
| `recursive` | `boolean` | `false` | Whether directories are traversed into sub-directories |
| `includeExtensions` | `string[]?` | `()` | Extension allowlist applied to directory contents (e.g. `["pdf"]`). Case-insensitive; `()` loads all types. Explicit file paths bypass it |

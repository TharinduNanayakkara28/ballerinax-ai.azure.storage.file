# module-ballerinax-ai.loader.azurefile

A Ballerina data loader that ingests documents from **Azure Files** shares and returns them
as `ai:TextDocument` values for the Ballerina AI module (chunking, embedding, RAG ingestion).

- **Package:** `ballerinax/ai.azure.storage.file`
- **Acquisition layer:** the [`ballerinax/azure_storage_service.files`](https://central.ballerina.io/ballerinax/azure_storage_service.files) connector (auth, directory/file listing, download, pagination).
- **Text extraction:** direct decode for textual files; Apache Tika for PDFs.
- **Authentication:** Shared Access Signature (SAS) and Shared Key (account access key). Azure AD / OAuth2 is not supported in this version.

See the [module README](ballerina/README.md) for the full usage guide and configuration
reference, and [`doc/`](doc/) for the per-phase implementation records.

## Status

**Phase 0 (scaffold) complete.** The repository builds an empty-logic package skeleton: the
Gradle multi-project wiring, the native Apache Tika text extractor, and the Tika/PDFBox
platform-dependency block are all in place. The acquisition and loader logic (text layer,
types, client, tree-walk loader) arrive in Phases 1–4. Overall design:
[`azure-file-data-loader-plan.md`](azure-file-data-loader-plan.md).

## Building

```bash
./gradlew build
```

The Gradle build requires the `packageUser`/`packagePAT` environment variables (a GitHub
account + PAT with `read:packages`) to resolve the `io.ballerina.plugin` Gradle plugin from
GitHub Packages.

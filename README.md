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

**All phases (0–5) complete.** Scaffold, text-extraction layer, types, connector client, and
the `Share → Directory → File` tree-walk loader are implemented; the text layer and all pure
loader logic are unit-tested (`bal test`, 54 cases). The connector-backed `load()`
orchestration is exercised by the [`live-test/`](live-test/) sample rather than unit tests
(see [`doc/phase-4-loader.md`](doc/phase-4-loader.md) §5). Overall design:
[`azure-file-data-loader-plan.md`](azure-file-data-loader-plan.md); per-phase implementation
records are in [`doc/`](doc/).

## Building

```bash
./gradlew build
```

The Gradle build requires the `packageUser`/`packagePAT` environment variables (a GitHub
account + PAT with `read:packages`) to resolve the `io.ballerina.plugin` Gradle plugin from
GitHub Packages.

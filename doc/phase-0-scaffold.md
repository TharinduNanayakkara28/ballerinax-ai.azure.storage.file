# Phase 0 — Scaffold

**Status:** ✅ Complete & verified
**Goal:** Stand up the full repository structure for `ballerinax/ai.azure.storage.file` by porting the scaffolding of the sibling Azure **Blob** loader (`ballerinax/ai.azure.storage.blob`), bring over the native Apache Tika text-extractor under the new Java package, and prove the package builds.

---

## 1. What was built

A complete, compiling Ballerina package skeleton — **no acquisition or loader logic yet** (that arrives in Phases 1–4). Concretely:

- Repo/Gradle multi-project scaffolding renamed from the Blob module (`blob` → `file`).
- Both `Ballerina.toml` files (the committed manifest + the `build-config` placeholder template) carrying the identical Tika/PDFBox platform-dependency block.
- The native `TextExtractor.java` (Apache Tika PDF text extraction) ported verbatim to the new Java package `io.ballerina.lib.ai.azure.storage.file`.
- A minimal placeholder Ballerina module (`file_data_loader.bal`) so the package has valid public source.
- Verified: the native jar compiles and `bal build` produces an executable.

This mirrors the Blob repo's own Phase 0 approach — scaffold first, port the text/types/client/loader in later phases.

---

## 2. Naming map applied everywhere

Per the plan's naming map (`azure-file-data-loader-plan.md`), `blob` → `file` throughout:

| Aspect | Blob (source) | This package |
|---|---|---|
| Repo directory / `rootProject.name` | `module-ballerinax-ai.loader.azureblob` | `module-ballerinax-ai.loader.azurefile` |
| Ballerina package | `ai.azure.storage.blob` | `ai.azure.storage.file` |
| Org | `ballerinax` | `ballerinax` (unchanged) |
| Java package | `io.ballerina.lib.ai.azure.storage.blob` | `io.ballerina.lib.ai.azure.storage.file` |
| Native artifactId | `ai.azure.storage.blob-native` | `ai.azure.storage.file-native` |
| Native-image config dir | `.../ai.azure.storage.blob-native/` | `.../ai.azure.storage.file-native/` |
| Gradle subprojects | `:ai.azure.storage.blob-{native,ballerina}` | `:ai.azure.storage.file-{native,ballerina}` |
| Keywords | `... "azure", "blob", "storage"` | `... "azure", "file", "storage"` |
| Repository URL | `.../module-ballerinax-ai.loader.azureblob` | `.../module-ballerinax-ai.loader.azurefile` |

> The **repo directory** name (`module-ballerinax-ai.loader.azurefile`) drives `rootProject.name`; everything else follows the **package** name (`ai.azure.storage.file`).

The upstream connector target also changes: `azure_storage_service.blobs` → `azure_storage_service.files` (wired in Phase 3, not yet imported).

---

## 3. Files created

### Root
| File | Origin | Notes |
|---|---|---|
| `gradlew`, `gradlew.bat`, `gradle/wrapper/*` | copied verbatim | Gradle wrapper |
| `LICENSE`, `.gitignore`, `.gitattributes` | copied verbatim | generic |
| `gradle.properties` | copied verbatim | `group=io.ballerina.lib`, `version=1.0.1-SNAPSHOT`, dep versions (Tika 3.2.2, PDFBox 3.0.5, jempbox 1.8.17, commons-io 2.20.0) — **unchanged** |
| `settings.gradle` | renamed | `rootProject.name` + the two `include` / `projectDir` lines (`blob` → `file`) |
| `build.gradle` | renamed | root aggregation; `build` depends on `:ai.azure.storage.file-ballerina:build` |
| `README.md` | new | project overview + Phase 0 status + build note |

### `ballerina/`
| File | Notes |
|---|---|
| `Ballerina.toml` | Committed manifest. `org=ballerinax`, `name=ai.azure.storage.file`, `version=1.0.0`, distribution `2201.12.0`. Full `[[platform.java21.dependency]]` block: native jar + tika-core + tika-parser-pdf-module + pdfbox/pdfbox-io/fontbox/jempbox + commons-io (identical versions to Blob). |
| `build.gradle` | `io.ballerina.plugin`; `packageName="ai.azure.storage.file"`, `isConnector=true`, `platform="java21"`. `build`/`test` depend on `:ai.azure.storage.file-native:build`. |
| `file_data_loader.bal` | **Placeholder module.** License header + module doc + one public const `API_VERSION`. Superseded by `types.bal` / `utils.bal` / `client.bal` / the real loader in Phases 1–4. |
| `icon.png` | copied verbatim from Blob. |

### `build-config/resources/`
| File | Notes |
|---|---|
| `Ballerina.toml` | Template with `@toml.version@` / `@project.version@` / `@tikaVersion@` … placeholders, expanded by the Gradle `updateTomlFiles` task at build time. Artifact path renamed to `ai.azure.storage.file-native-@project.version@.jar`. |

### `native/`
| File | Notes |
|---|---|
| `build.gradle` | `java` plugin, Java 21; deps: `ballerina-runtime` + `tika-core` + `tika-parser-pdf-module`. `description` → "Azure Files document data loader - Java native utils". |
| `src/main/java/io/ballerina/lib/ai/azure/storage/file/TextExtractor.java` | **Ported verbatim** except the `package` line and one doc comment ("Azure Blob Storage" → "Azure Files"). Uses `PDFParser` directly, reads in-memory bytes via `ByteArrayInputStream`, returns `BString` or a Ballerina error. Logic untouched. |
| `src/main/resources/META-INF/native-image/io.ballerina.lib/ai.azure.storage.file-native/native-image.properties` | `Args = -H:+AddAllCharsets` (path segment renamed). |

---

## 4. Build verification (how Phase 0 was proven)

The full Gradle build needs the `packageUser` / `packagePAT` credentials to resolve the
`io.ballerina.plugin` plugin from GitHub Packages. So — as with the Blob Phase 0 — the
package was verified **without Gradle**, by reproducing what Gradle would do.

### 4.1 Build the native jar with `javac` + `jar`
Classpath sources available on this machine:
- Ballerina runtime API classes: `/Library/Ballerina/distributions/ballerina-2201.12.0/bre/lib/ballerina-rt-2201.12.0.jar` (the `io.ballerina.runtime.api.*` classes live here, **not** in `runtime-*.jar`).
- Tika jars from the local Ballerina cache (pulled by the sibling Blob build): `tika-core-3.2.2.jar`, `tika-parser-pdf-module-3.2.2.jar`.

```bash
javac -cp "<ballerina-rt>:<tika-core>:<tika-pdf>" \
  -d native/build/classes \
  native/src/main/java/io/ballerina/lib/ai/azure/storage/file/TextExtractor.java

jar --create --file native/build/libs/ai.azure.storage.file-native-1.0.0.jar \
  -C native/build/classes . -C native/src/main/resources .
```

Result: `javac OK`, `jar OK`. The jar contains `…/storage/file/TextExtractor.class` and the
`ai.azure.storage.file-native/native-image.properties` resource, and its path/name match the
`path` declared in `ballerina/Ballerina.toml`.

### 4.2 Build the Ballerina package
```bash
cd ballerina && bal build
```
Result: Maven platform deps downloaded (tika, pdfbox, fontbox, jempbox, commons-io),
`Compiling source ballerinax/ai.azure.storage.file:1.0.0`, and
**`Generating executable → target/bin/ai.azure.storage.file.jar`**. ✅

> When the real Gradle build is available (creds set), `./gradlew build` regenerates the
> native jar automatically and the manual `javac`/`jar` step is unnecessary.

---

## 5. Notes, deviations & carry-forward

- **Placeholder module.** `file_data_loader.bal` only exists so the package has a public
  construct to compile; it (and `API_VERSION`) will be superseded in Phases 1–4.
- **Logic files not yet ported.** `types.bal`, `utils.bal`, `client.bal`, the real
  `file_data_loader.bal`, the tests, and `live-test/` are intentionally **not** present yet —
  they belong to their respective phases (text layer → Phase 1, types → Phase 2, client →
  Phase 3, loader → Phase 4, docs/sample → Phase 5).
- **Native jar is a build artifact.** `native/build/` is git-ignored; it was materialised
  locally only to verify `bal build`. CI/release rebuilds it via Gradle.
- **`Dependencies.toml`** is `bal`-generated on first build; it now lists only the package
  itself (no connector import yet).
- **Connector not yet wired.** `ballerinax/azure_storage_service.files` (v4.3.4) is **not**
  imported yet — that is Phase 3.
- **Gradle build prerequisite:** set `packageUser` / `packagePAT` (GitHub account + PAT with
  `read:packages`) before `./gradlew build`.

---

## 6. Phase 0 checklist

- [x] Copy repo scaffolding; rename package / repo / Java package / artifacts (`blob` → `file`).
- [x] `settings.gradle` — `rootProject.name` + the two `include`/`projectDir` lines.
- [x] `gradle.properties` — left unchanged (same Tika/PDFBox/lang versions).
- [x] `build.gradle`, `native/build.gradle` — `description` / task-dependency strings renamed.
- [x] `native/…/native-image.properties` — path segment `…/storage/blob` → `…/storage/file`.
- [x] Move native Java package `…/storage/blob/` → `…/storage/file/`; port `TextExtractor.java`.
- [x] `ballerina/Ballerina.toml` (+ `build-config` template) — name, repository, native-jar
      artifactId + path, keywords renamed; Tika/PDFBox deps identical.
- [x] Minimal placeholder module so the package compiles.
- [x] Native jar builds; `bal build` produces an executable. **Gate met.**
- [ ] (Deferred to Phase 3) Import + resolve `ballerinax/azure_storage_service.files`.

**Next:** Phase 1 — copy the text-conversion layer (`utils.bal`: `buildDocument` / `classify` /
MIME+extension tables / `matchesExtensionFilter` / `getExtension` / `toUtc` / `dedupeStrings`)
verbatim, retarget the `@java:Method` class to `…storage.file.TextExtractor`, drop the
Blob-only path helpers, and bring the mocked text-layer + fixture tests (`bal test`).

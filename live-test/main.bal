import ballerina/ai;
import ballerina/io;
import ballerinax/ai.azure.storage.file;
import ballerinax/azure_storage_service.files;

// These are read from Config.toml (see Config.toml.template).
configurable string accountName = ?;
configurable string accessKeyOrSAS = ?;
configurable string authMethod = "ACCESS_KEY"; // "ACCESS_KEY" or "SAS"
configurable string share = ?;
// Paths to load: directories (e.g. "/", "/reports/") and/or explicit files
// (e.g. "/pdfs/scanned_1.pdf"). Defaults to the whole share.
configurable string[] paths = ["/office/presentation.pptx"];
// Whether directories are traversed into sub-directories.
configurable boolean recursive = false;

public function main() {
    files:AuthorizationMethod method = authMethod == "SAS" ? files:SAS : files:ACCESS_KEY;

    io:println("Connecting to account '", accountName, "', share '", share, "', paths ", paths, " ...");

    file:TextDataLoader|ai:Error loader = new (
        {
            accountName,
            accessKeyOrSAS,
            authorizationMethod: method
        },
        [{share, paths, recursive}]
    );
    if loader is ai:Error {
        io:println("\nFAILED TO INITIALIZE THE LOADER:\n  ", loader.message());
        return;
    }

    ai:Document[]|ai:Document|ai:Error result = loader.load();
    if result is ai:Error {
        // e.g. a named scanned (image-only) PDF, a named non-text file, or a missing path.
        io:println("\nTHE LOADER RETURNED AN ERROR:\n  ", result.message());
        return;
    }

    ai:Document[] documents = result is ai:Document[] ? result : [result];
    io:println("\n=== Loaded ", documents.length(), " document(s) ===\n");
    foreach ai:Document doc in documents {
        if doc is ai:TextDocument {
            anydata metadata = doc.metadata;
            string content = doc.content;
            io:println("--------------------------------------------------");
            io:println("metadata : ", metadata.toString());
            io:println("chars    : ", content.length());
            io:println("content  :\n", content);
        }
    }
    io:println("\nDone.");
}

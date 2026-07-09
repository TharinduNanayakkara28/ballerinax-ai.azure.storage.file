// Copyright (c) 2026, WSO2 LLC. (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/http;
import ballerina/test;

// ---- Source defaults ---------------------------------------------------------

@test:Config {}
isolated function testSourceDefaults() {
    Source src = {share: "documents"};
    test:assertEquals(src.paths, ["/"], "paths defaults to the whole share");
    test:assertFalse(src.recursive, "recursive defaults to false");
    test:assertTrue(src.includeExtensions is (), "includeExtensions defaults to () (all types)");
}

@test:Config {}
isolated function testSourceExplicitValues() {
    Source src = {
        share: "specs",
        paths: ["/api", "/design.md"],
        recursive: true,
        includeExtensions: ["pdf", ".md"]
    };
    test:assertEquals(src.share, "specs");
    test:assertEquals(src.paths.length(), 2);
    test:assertTrue(src.recursive);
    test:assertEquals(src.includeExtensions, ["pdf", ".md"]);
}

@test:Config {}
isolated function testSourceWildcardShare() {
    Source src = {share: "*"};
    test:assertEquals(src.share, "*", "'*' selects every share in the account");
    test:assertEquals(src.paths, ["/"], "wildcard share still defaults to the whole tree");
}

// ---- ConnectionConfig defaults ----------------------------------------------

@test:Config {}
isolated function testConnectionConfigDefaults() {
    ConnectionConfig config = {
        accountName: "acct",
        accessKeyOrSAS: "token",
        authorizationMethod: SAS
    };
    test:assertEquals(config.httpVersion, http:HTTP_1_1, "httpVersion defaults to HTTP/1.1 (matches the connector)");
    test:assertEquals(config.timeout, <decimal>30);
    test:assertEquals(config.forwarded, "disable");
    test:assertEquals(config.compression, http:COMPRESSION_AUTO);
    test:assertTrue(config.validation);
}

@test:Config {}
isolated function testAuthorizationMethodValues() {
    AuthorizationMethod key = ACCESS_KEY;
    AuthorizationMethod sas = SAS;
    test:assertEquals(key, ACCESS_KEY);
    test:assertEquals(sas, SAS);
    test:assertNotEquals(key, sas);
}

// ---- FileEntry shape ---------------------------------------------------------

@test:Config {}
isolated function testFileEntryDefaults() {
    FileEntry entry = {name: "q1.pdf", directoryPath: "reports"};
    test:assertEquals(entry.name, "q1.pdf");
    test:assertEquals(entry.directoryPath, "reports");
    test:assertTrue(entry.contentLength is (), "Optional metadata defaults to ()");
    test:assertTrue(entry.lastModified is ());
}

@test:Config {}
isolated function testFileEntryAtShareRoot() {
    FileEntry entry = {name: "readme.txt", directoryPath: "", contentLength: 42};
    test:assertEquals(entry.directoryPath, "", "A file at the share root has an empty directoryPath");
    test:assertEquals(entry.contentLength, <decimal>42);
}

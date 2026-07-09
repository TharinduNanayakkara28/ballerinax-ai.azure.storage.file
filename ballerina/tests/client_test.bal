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
import ballerinax/azure_storage_service.files;

// ---- AuthorizationMethod mapping --------------------------------------------

@test:Config {}
isolated function testAuthMethodMapping() {
    test:assertEquals(toConnectorAuthMethod(ACCESS_KEY), files:ACCESS_KEY);
    test:assertEquals(toConnectorAuthMethod(SAS), files:SAS);
}

// ---- toConnectorConfig forwarding -------------------------------------------

@test:Config {}
isolated function testToConnectorConfigForwardsIdentityAndAuth() {
    ConnectionConfig config = {
        accountName: "contosostorage",
        accessKeyOrSAS: "sv=2022-11-02&sig=abc",
        authorizationMethod: SAS
    };
    files:ConnectionConfig mapped = toConnectorConfig(config);
    test:assertEquals(mapped.accountName, "contosostorage");
    test:assertEquals(mapped.accessKeyOrSAS, "sv=2022-11-02&sig=abc");
    test:assertEquals(mapped.authorizationMethod, files:SAS);
    test:assertEquals(mapped.httpVersion, http:HTTP_1_1);
    test:assertEquals(mapped.timeout, <decimal>30);
}

@test:Config {}
isolated function testToConnectorConfigForwardsOptionalHttpOptions() {
    ConnectionConfig config = {
        accountName: "acct",
        accessKeyOrSAS: "key",
        authorizationMethod: ACCESS_KEY,
        timeout: 45,
        retryConfig: {count: 3, interval: 1},
        proxy: {host: "proxy.example", port: 8080},
        secureSocket: {enable: false}
    };
    files:ConnectionConfig mapped = toConnectorConfig(config);
    test:assertEquals(mapped.authorizationMethod, files:ACCESS_KEY);
    test:assertEquals(mapped.timeout, <decimal>45);
    test:assertEquals(mapped.retryConfig?.count, 3);
    test:assertEquals(mapped.proxy?.host, "proxy.example");
    test:assertEquals(mapped.proxy?.port, 8080);
    test:assertTrue(mapped.secureSocket is http:ClientSecureSocket);
}

@test:Config {}
isolated function testToConnectorConfigOmitsUnsetOptionalOptions() {
    ConnectionConfig config = {
        accountName: "acct",
        accessKeyOrSAS: "key",
        authorizationMethod: ACCESS_KEY
    };
    files:ConnectionConfig mapped = toConnectorConfig(config);
    test:assertTrue(mapped.retryConfig is (), "An unset retryConfig is not forwarded");
    test:assertTrue(mapped.proxy is (), "An unset proxy is not forwarded");
    test:assertTrue(mapped.circuitBreaker is (), "An unset circuitBreaker is not forwarded");
}

// ---- newFileClient construction (no network call at init) -------------------

@test:Config {}
isolated function testNewFileClientWithSas() returns error? {
    ConnectionConfig config = {
        accountName: "contosostorage",
        accessKeyOrSAS: "sv=2022-11-02&ss=f&srt=co&sp=rl&sig=abc",
        authorizationMethod: SAS
    };
    files:FileClient _ = check newFileClient(config);
}

@test:Config {}
isolated function testNewFileClientWithAccessKey() returns error? {
    ConnectionConfig config = {
        accountName: "contosostorage",
        // A syntactically valid base64 access key; no network call is made at construction.
        accessKeyOrSAS: "dGhpcy1pcy1hLWZha2Uta2V5LWZvci10ZXN0aW5n",
        authorizationMethod: ACCESS_KEY
    };
    files:FileClient _ = check newFileClient(config);
}

// ---- newManagementClient construction (used for share: "*") -----------------

@test:Config {}
isolated function testNewManagementClientWithSas() returns error? {
    ConnectionConfig config = {
        accountName: "contosostorage",
        accessKeyOrSAS: "sv=2022-11-02&ss=f&srt=s&sp=l&sig=abc",
        authorizationMethod: SAS
    };
    files:ManagementClient _ = check newManagementClient(config);
}

// ---- isNotFoundError ---------------------------------------------------------

@test:Config {}
isolated function testIsNotFoundErrorForNotFound() {
    files:NotFoundError notFound = error("Resource not found.",
        httpStatus = 404, errorCode = "ShareNotFound", message = "The specified share does not exist.");
    test:assertTrue(isNotFoundError(notFound), "A connector NotFoundError is recognised");
}

@test:Config {}
isolated function testIsNotFoundErrorForOtherErrors() {
    files:BadRequestError badRequest = error("Bad request received.",
        httpStatus = 400, errorCode = "InvalidUri", message = "The request URI is invalid.");
    test:assertFalse(isNotFoundError(badRequest), "A 400 is not a not-found");
    test:assertFalse(isNotFoundError(error("some unrelated failure")), "A generic error is not a not-found");
}

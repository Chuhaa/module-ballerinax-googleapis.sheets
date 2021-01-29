// Copyright (c) 2018 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
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

function sendRequestWithPayload(http:Client httpClient, string path, json jsonPayload = ())
returns @tainted json | error {
    http:Request httpRequest = new;
    if (jsonPayload != ()) {
        httpRequest.setJsonPayload(<@untainted>jsonPayload);
    }
    var httpResponse = httpClient->post(<@untainted>path, httpRequest);
    if (httpResponse is http:Response) {
        int statusCode = httpResponse.statusCode;
        json | http:ClientError jsonResponse = httpResponse.getJsonPayload();
        if (jsonResponse is json) {
            error? validateStatusCodeRes = validateStatusCode(jsonResponse, statusCode);
            if (validateStatusCodeRes is error) {
                return validateStatusCodeRes;
            }
            return jsonResponse;
        } else {
            return getSpreadsheetError(jsonResponse);
        }
    } else {
        return getSpreadsheetError(<json|error>httpResponse);
    }
}

function sendRequest(http:Client httpClient, string path) returns @tainted json | error {
    var httpResponse = httpClient->get(<@untainted>path);
    if (httpResponse is http:Response) {
        int statusCode = httpResponse.statusCode;
        json | http:ClientError jsonResponse = httpResponse.getJsonPayload();
        if (jsonResponse is json) {
            error? validateStatusCodeRes = validateStatusCode(jsonResponse, statusCode);
            if (validateStatusCodeRes is error) {
                return validateStatusCodeRes;
            }
            return jsonResponse;
        } else {
            return getSpreadsheetError(jsonResponse);
        }
    } else {
        return getSpreadsheetError(<json|error>httpResponse);
    }
}

isolated function getConvertedValue(json value) returns string | int | float {
    if (value is int) {
        return value;
    } else if (value is float) {
        return value;
    } else {
        return value.toString();
    }
}

isolated function validateResponse(json jsonResponse, int statusCode, Client cli) returns Spreadsheet | error {
    if (statusCode == http:STATUS_OK) {
        return convertToSpreadsheet(jsonResponse, cli);
    }
    return getSpreadsheetError(jsonResponse);
}

isolated function validateStatusCode(json response, int statusCode) returns error? {
    if (statusCode != http:STATUS_OK) {
        return getSpreadsheetError(response);
    }
}

isolated function setResponse(json jsonResponse, int statusCode) returns error? {
    if (!(statusCode == http:STATUS_OK)) {
        return getSpreadsheetError(jsonResponse);
    }
}

isolated function equalsIgnoreCase(string stringOne, string stringTwo) returns boolean {
    if (stringOne.toLowerAscii() == stringTwo.toLowerAscii()) {
        return true;
    }
    return false;
}

isolated function getSpreadsheetError(json|error errorResponse) returns error {
  if (errorResponse is json) {
        return error(errorResponse.toString());
  } else {
        return errorResponse;
  }
}

# Get files stream.
# 
# + driveClient - Drive client
# + files - File array
# + pageToken - Token for retrieving next page
# + return - File stream on success, else an error
function getFilesStream(http:Client driveClient, @tainted File[] files, string? pageToken = ()) returns @tainted stream<File>|error {
    string drivePath = DRIVE_PATH + FILES + QUESTION_MARK + Q + EQUAL + MIME_TYPE + EQUAL + APPLICATION;
    if (pageToken is string) {
        drivePath = DRIVE_PATH + FILES + QUESTION_MARK + Q + EQUAL + MIME_TYPE + EQUAL + APPLICATION + AND + PAGE_TOKEN + EQUAL + pageToken;
    }
    json | error resp = sendRequest(driveClient, drivePath);
    if resp is json {
        FilesResponse|error res = resp.cloneWithType(FilesResponse);
        if (res is FilesResponse) {
            int i = files.length();
            foreach File item in res.files {
                files[i] = item;
                i = i + 1;
            }        
            stream<File> filesStream = (<@untainted>files).toStream();
            string? nextPageToken = res?.nextPageToken;
            if (nextPageToken is string) {
                var streams = check getFilesStream(driveClient, files, nextPageToken);
            }
            return filesStream;
        } else {
            return error(ERR_FILE_RESPONSE, res);
        }
    } else {
        return resp;
    }
}

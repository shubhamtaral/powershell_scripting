// NPM
const fs = require("fs");
const { parse } = require("csv-parse");
const Promise = require("bluebird");
const request = require('request-promise');

// Varibales
const file = "./AI_Rerun1.csv";
let domain = "TEST";
let AiRequestURL = `https://cpaiuat.contractpod.com/cpaimt_api/api/${domain}/v1/contractfile/airequest`;
let RequestorUsername, RequestId, StorageFilename, IsFinalSignedCopy, IsPDF;
let concurrency = 10;
let TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1laWQiOiJGRERGMTQ0OUNGMDg0QzRCOEQzNzg5MDg2QkMxNzk3OSIsInJvbGUiOiJTdXBlciBBZG1pbiIsIlVzZXJJZCI6IjEwODMiLCJuYmYiOjE2NjA4MDY2MTUsImV4cCI6MTY2MTg4NjYxNSwiaWF0IjoxNjYwODA2NjE1LCJpc3MiOiJDb250cmFjdFBvZEFpIiwiYXVkIjoidGVzdCJ9.shvD4q1FTwa_r_-x9a9NfRe-lyrfq8FNOQRoG3WwxKs"

// Funtions
function createAPICalls(CSV_File, callback) {

    let APICalls = [];

    fs.createReadStream(CSV_File)
        .pipe(parse({ delimiter: ",", from_line: 2 }))
        .on("data", function (row) {
            RequestorUsername = row[0]
            RequestId = row[1]
            StorageFilename = row[2]
            IsFinalSignedCopy = row[3]
            IsPDF = row[4]
            let options = {
                url: AiRequestURL,
                method: 'POST',
                json: {
                    "RequestorUsername": RequestorUsername,
                    "RequestId": RequestId,
                    "IsFinalSignedCopy": IsFinalSignedCopy,
                    "IsPDF": IsPDF,
                    "StorageFilename": StorageFilename
                },
                headers: {
                    'User-Agent': 'my request',
                    'Authorization': `Bearer ${TOKEN}`,
                    'Content-Type': 'application/json',
                    'Accept': 'application/json'
                }
            };

            APICalls.push(options);

        })
        .on("end", function () {
            console.log("All records finished");
            callback(APICalls)
        })
        .on("error", function (error) {
            console.log(error.message);
            callback(null)
        });

}
function createChunk(array, size) {
    let result = []
    for (let i = 0; i < array.length; i += size) {
        let chunk = array.slice(i, i + size)
        result.push(chunk)
    }
    return result
}

// Main
createAPICalls(file, (options) => {
    console.time("INFO: Execution Started");
    let totalChunks = createChunk(options, concurrency);
    (async function () {
        for (i = 0; i < totalChunks.length; i++) {
            let currentChunck = totalChunks[i]
            console.log(`INFO: Sending requests batch no ${i} of ${totalChunks.length} contains ${currentChunck.length} requests`);

            const promises = currentChunck.map(chunk => request(chunk));

            await Promise.all(promises).then((data) => {
                console.log("Res ==> \n", data)
            }).catch(err => console.log(`Error: ${err.statusCode} : ${err.error.message}`));
        }
    })()
    console.timeEnd("INFO: Execution Started");
});

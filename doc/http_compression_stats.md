# Monitoring a Compressed HTTP Resource

This document shows how to use one of the bash tools (`http_compression_stats.bash`) to monitor an HTTP resource. The tool is essentially a wrapper around the `curl` command-line tool, which has extensive timing capabilities.

This tool also checks the server’s ability to compress the resource and the integrity of the compressed response. It does this by making two separate requests for the resource, one that indicates the client’s support for HTTP compression and one that does not. The response times are recorded separately for each response.

If the server does not support [HTTP compression](https://en.wikipedia.org/wiki/HTTP_compression) for the resource of interest, or you trust the server to maintain the integrity of the compressed response, consider using the [http_response_stats.bash](./http_response_stats.md) tool instead. The latter makes a single request for the resource (with or without compression, your choice).

The `http_compression_stats.bash` tool persists the timing values for both requests to a log file. It then converts a portion of the log file to JSON. Here is the simplest example of a JSON array with one element:

```javascript
[
  {
    "requestInstant": "2018-04-09T14:59:28Z"
    ,
    "friendlyDate": "April 09, 2018"
    ,
    "diffExitCode": "1"
    ,
    "UncompressedResponse":
    {
      "curlExitCode": "0"
      ,
      "responseCode": "200"
      ,
      "sizeDownload": 44442
      ,
      "speedDownload": 75162.000
      ,
      "timeTotal": 0.591277
    }
    ,
    "CompressedResponse":
    {
      "curlExitCode": "0"
      ,
      "responseCode": "200"
      ,
      "sizeDownload": 13317
      ,
      "speedDownload": 24942.000
      ,
      "timeTotal": 0.533898
    }
  }
]
```

In the JSON output, the value of the `requestInstant` field indicates the actual time instant the script was run. Its value has the canonical form of an ISO 8601 dateTime string.

The `friendlyDate` field indicates the date of the request. The time subfield is omitted from the `friendlyDate` field.

The two response bodies are compared byte-by-byte using the `diff` command-line tool. The `diffExitCode` records the result of this comparison. The response bodies are identical if (and only if) the value of the `diffExitCode` field is zero.

The `curlExitCode` field is just that. Normally this code will be zero. Nonzero exit codes indicate an error occurred. The semantics of [curl exit codes](https://curl.haxx.se/docs/manpage.html#EXIT) are documented on the curl man page.

Note that the documentation for each exit code is individually addressable. For example, the online documentation explains that [exit code 28](https://curl.haxx.se/docs/manpage.html#28) indicates a network timeout.

# Monitoring HTTP Compression

This document shows how to use one of the bash tools (`http_compression_stats.bash`) to measure the effects of [HTTP compression](https://en.wikipedia.org/wiki/HTTP_compression). The tool is essentially a wrapper around the `curl` command-line tool, which supports compression out-of-the-box.

The `http_compression_stats.bash` tool computes and persists the response info to a log file. It then converts a portion of the log file to JSON. Here is the simplest example of a JSON array with one element:

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

The `curlExitCode` field is just that. Normally this code will be zero. Nonzero exit codes indicate an error occurred. The semantics of [curl exit codes](https://curl.haxx.se/docs/manpage.html#EXIT) are documented on the curl man page.

Note that the documentation for each exit code is individually addressable. For example, the online documentation explains that [exit code 28](https://curl.haxx.se/docs/manpage.html#28) indicates a network timeout.

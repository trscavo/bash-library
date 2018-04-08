# Monitoring HTTP Response

This document shows how to use one of the bash tools (`http_response_stats.bash`) to measure response times from an HTTP server. The tool is essentially a wrapper around the `curl` command-line tool, which has extensive timing capabilities.

The tool persists the response time values to a log file. It then converts a portion of the log file to JSON. Here is the simplest example of a JSON array with one element:

```javascript
[
  {
    "requestInstant": "2018-04-07T14:31:50Z"
    ,
    "friendlyDate": "April 07, 2018"
    ,
    "curlExitCode": "0"
    ,
    "responseCode": "200"
    ,
    "sizeDownload": 50078966
    ,
    "speedDownload": 12648218.000
    ,
    "timeNamelookup": 0.271865
    ,
    "timeConnect": 0.298768
    ,
    "timeAppconnect": 0.400534
    ,
    "timePretransfer": 0.400674
    ,
    "timeStarttransfer": 0.452934
    ,
    "timeTotal": 3.959369
  }
]
```

In the JSON output, the value of the `requestInstant` field indicates the actual time instant the script was run. Its value has the canonical form of an ISO 8601 dateTime string.
	
The `friendlyDate` field indicates the date of the request. The time subfield is omitted from the `friendlyDate` field.

The `curlExitCode` field is just that. Normally this code will be zero. Nonzero exit codes indicate an error occurred. The semantics of [curl exit codes](https://curl.haxx.se/docs/manpage.html#EXIT) are documented on the curl man page.
	
Note that the documentation for each exit code is individually addressable. For example, the link to the documentation for exit code 28 (timeout) is: https://curl.haxx.se/docs/manpage.html#28
	
The remaining fields in the JSON output are computed by curl. In particular, the timing values start with the word “time”. They were obtained by invoking the `curl --write-out` option. The semantics of each [`--write-out` parameter](https://curl.haxx.se/docs/manpage.html#-w) are documented on the curl man page. 

The timing values are listed chronologically in the output. Each timing value gives the cumulative elapsed time in seconds. For example, the value of `timeConnect` (0.298768) is the cumulative time for both DNS resolution (`timeNamelookup`) and TCP connection (`timeConnect`). Finally the total time is given by the `timeTotal` value.

The output data are sufficient to construct a time-series plot. The `requestInstant` field is intended to be the independent variable. Any of the numerical `--write-out` parameters are potential dependent variables of interest. In particular, either of the `speedDownload` or `timeTotal` fields give rise to interesting time-series plots.

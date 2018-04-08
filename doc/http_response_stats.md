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

## Timing the response

First specify the HTTP resource of interest:

```shell
$ location=https://github.com/trscavo/bash-library/blob/master/doc/http_response_stats.md
```

Now invoke the script as follows:

```shell
$ $BIN_DIR/http_response_stats.bash $location
```

Every invocation of the script performs the following steps:

1. Issue an HTTP GET request
1. Update the corresponding response log file with the results
1. Print a tail of the response log file in JSON format

The log file is maintained in the cache directory:

```shell
$ echo $CACHE_DIR 
/tmp/http_cache
$ $BIN_DIR/http_cache_ls.bash $location 
/tmp/http_cache/63d19f0b58162ed82be8bd8cb663e46bfad56d47_request_headers
/tmp/http_cache/63d19f0b58162ed82be8bd8cb663e46bfad56d47_response_body
/tmp/http_cache/63d19f0b58162ed82be8bd8cb663e46bfad56d47_response_headers
/tmp/http_cache/63d19f0b58162ed82be8bd8cb663e46bfad56d47_response_log
```

The filename prefix (`63d19f0b58162ed82be8bd8cb663e46bfad56d47`) is the SHA-1 hash of the location URL. In that way, each URL gives rise to a unique set of cache files.

## Requesting a compressed response

The `-z` option causes the client to request [HTTP Compression](https://en.wikipedia.org/wiki/HTTP_compression):

```shell
# request HTTP compression
$ $BIN_DIR/http_response_stats.bash -z $location
# do not request HTTP compression
$ $BIN_DIR/http_response_stats.bash $location
```

It is then up to the server to send a compressed resource (or not). In any case, the script treats the two requests as different requests. In particular, the script uses different log files in each case. The output is completely separate.

NOTE. The response times for a compressed response may or may not be significantly different from the response times of an uncompressed response. Even if the the server compresses the response, the file may be too small to produce a noticeable difference.

TIP. The server indicates a compressed response by including a `Content-Encoding` header. For example:

```shell
$ curl --silent --head --compressed $location | grep -F Content-Encoding
Content-Encoding: gzip
```

If compression was not used, the `Content-Encoding` header will be missing.

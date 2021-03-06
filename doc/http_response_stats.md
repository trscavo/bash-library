# Monitoring an HTTP Resource

This document shows how to use one of the bash tools (`http_response_stats.bash`) to monitor an HTTP resource. The tool is essentially a wrapper around the `curl` command-line tool, which has extensive timing capabilities.

If the server supports [HTTP compression](https://en.wikipedia.org/wiki/HTTP_compression), and you wish to monitor the integrity of the compressed response, consider using the [http_compression_stats.bash](./http_compression_stats.md) tool instead. The latter makes two separate requests for the resource (with and without compression).

The `http_response_stats.bash` tool computes and persists the response time values to a log file. It then converts a portion of the log file to JSON. Here is the simplest example of a JSON array with one element:

```javascript
[
  {
    "requestInstant": "2018-04-08T20:46:53Z"
    ,
    "friendlyDate": "April 08, 2018"
    ,
    "curlExitCode": "0"
    ,
    "responseCode": "200"
    ,
    "sizeDownload": 43730
    ,
    "speedDownload": 88461.000
    ,
    "timeTotal": 0.494339
  }
]
```

In the JSON output, the value of the `requestInstant` field indicates the actual time instant the script was run. Its value has the canonical form of an [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601) dateTime string.

The `friendlyDate` field indicates the date of the request. The time of the initial request is omitted from the `friendlyDate` field for readability.

The `curlExitCode` field is just that. Normally this code will be zero, indicating that curl was successful. Nonzero exit codes indicate an error occurred. The semantics of [curl exit codes](https://curl.haxx.se/docs/manpage.html#EXIT) are documented on the curl man page.

Note that the documentation for each exit code is individually addressable. For example, the online documentation for [exit code 28](https://curl.haxx.se/docs/manpage.html#28) indicates a network timeout.

The remaining fields are computed by curl. The values were obtained by invoking the `curl --write-out` option. The semantics of each [write-out parameter](https://curl.haxx.se/docs/manpage.html#-w) are documented on the curl man page.

In particular, the `responseCode` field is the HTTP response code. Normally this is 200 but other responses are possible of course. If the `curlExitCode` is nonzero, and the HTTP response did not complete, the `responseCode` will be 000.

The output data are sufficient to construct a time-series plot. The `requestInstant` field is intended to be the independent variable. Any of the numerical `--write-out` parameters are potential dependent variables of interest. In particular, either  the `speedDownload` field or the `timeTotal` field gives rise to interesting time-series plots.

## Timing the response

The `http_response_stats.bash` script has one required command-line argument:

Usage: `http_response_stats.bash [-hqDWaz] [-n NUM_OBJECTS] [-d OUT_DIR] LOCATION`

The `LOCATION` argument is the URL of interest. Specify a location as follows:

```shell
$ location=https://github.com/trscavo/bash-library/blob/master/doc/http_response_stats.md
```

Now invoke the script like this:

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
$ url=https://letsencrypt.org
$ $BIN_DIR/chead.bash -z $url | grep -F Content-Encoding
Content-Encoding: gzip
```

If compression was not used, the `Content-Encoding` header will be missing.

## Creating a JSON file

By default, the script directs its output to stdout. To redirect the output to a particular directory, use the `-d` option:

```shell
$ out_dir=/tmp/out/
$ $BIN_DIR/http_response_stats.bash -d $out_dir $location
$ ls $out_dir 
63d19f0b58162ed82be8bd8cb663e46bfad56d47_response_stats.json
```

Typically the output directory is a web directory. For illustration, the above example outputs a JSON file to a temporary directory.

The script automatically determines the filename based on the SHA-1 hash of the location URL, and so the filename is unique. This uniqueness is maintained with or without the `-z` option.

By default, the JSON array will have 10 elements. To specify some other array size, add option `-n` to the command line. For example, the following command generated the output shown at the beginning of this document:

```shell
$ $BIN_DIR/http_response_stats.bash -n 1 $location
```

Here's another, more realistic example:

```shell
$ $BIN_DIR/http_response_stats.bash -n 30 -d $out_dir $location
```

The above command will output a JSON array of at most 30 objects. These objects correspond to the last 30 lines in the log file.

Every JSON object includes a `timeTotal` field. To output additional timing data per JSON object, use the -a option, which outputs all available timing data. For example:

```shell
$ $BIN_DIR/http_response_stats.bash -n 1 -a $location
[
  {
    "requestInstant": "2018-04-08T20:46:53Z"
    ,
    "friendlyDate": "April 08, 2018"
    ,
    "curlExitCode": "0"
    ,
    "responseCode": "200"
    ,
    "sizeDownload": 43730
    ,
    "speedDownload": 88461.000
    ,
    "timeNamelookup": 0.030218
    ,
    "timeConnect": 0.062788
    ,
    "timeAppconnect": 0.148901
    ,
    "timePretransfer": 0.148989
    ,
    "timeStarttransfer": 0.425072
    ,
    "timeTotal": 0.494339
  }
]
```

The timing values (each starting with the word “time” in the output) were obtained by invoking the `curl --write-out` option. The semantics of each [write-out parameter](https://curl.haxx.se/docs/manpage.html#-w) are documented on the curl man page. 

The timing values are listed chronologically in the output. Each timing value gives the cumulative elapsed time in seconds. For example, the value of `timeConnect` (0.298768 secs) is the cumulative time for both DNS resolution (`timeNamelookup`) and TCP connection (`timeConnect`). The final time listed is the total time, given by the `timeTotal` value, which is always included in the output, even if option `-a` is omitted.

Be careful, though, depending on the total number of JSON objects, the use of option `-a` could bloat the JSON file considerably.

That’s it! To keep the JSON file up to date, you can of course automate the previous process with cron.

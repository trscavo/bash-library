# Monitoring a Compressed HTTP Resource

This document shows how to use one of the bash tools (`http_compression_stats.bash`) to monitor an HTTP resource. The tool is essentially a wrapper around the `curl` command-line tool, which has extensive timing capabilities.

This tool also checks the server’s ability to compress the resource and the integrity of the compressed response. It does this by making two separate requests for the resource, one that indicates the client’s support for HTTP compression and one that does not. The response times are recorded separately for each response.

If the server does not support [HTTP compression](https://en.wikipedia.org/wiki/HTTP_compression) for the resource of interest, or you trust the server to maintain the integrity of the compressed response, consider using the [http_response_stats.bash](./http_response_stats.md) tool instead. The latter makes a single request for the resource (with or without compression, your choice).

The `http_compression_stats.bash` tool persists the timing values for both requests to a log file. It then converts a portion of the log file to JSON. Here is the simplest example of a JSON array with one element:

```javascript
[
  {
    "requestInstant": "2018-04-10T15:52:38Z"
    ,
    "friendlyDate": "April 10, 2018"
    ,
    "areResponsesEqual": true
    ,
    "isResponseCompressed": true
    ,
    "UncompressedResponse":
    {
      "curlExitCode": "0"
      ,
      "responseCode": "200"
      ,
      "sizeDownload": 437
      ,
      "speedDownload": 1299.000
      ,
      "timeTotal": 0.336224
    }
    ,
    "CompressedResponse":
    {
      "curlExitCode": "0"
      ,
      "responseCode": "200"
      ,
      "sizeDownload": 439
      ,
      "speedDownload": 2883.000
      ,
      "timeTotal": 0.152244
    }
  }
]
```

In the JSON output, the value of the `requestInstant` field indicates the actual time instant the script was run. Its value has the canonical form of an [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601) dateTime string.

The `friendlyDate` field indicates the date of the request. The time of the initial request is omitted from the `friendlyDate` field for readability.

The tool compares the content of the two responses byte-by-byte. The result of this comparison is recorded in the `areResponsesEqual` boolean field: The response bodies are identical if (and only if) the value of the `areResponsesEqual` field is true.

Since a server compresses a particular response at its discretion, the tool determines if the request with compression actually resulted in a compressed response. If so, the value of the `isResponseCompressed` boolean field will be true.

The rest of the JSON output consists of two JavaScript objects, one for the uncompressed response and the other for the compressed response (resp.). The two objects contain the same fields.

The `curlExitCode` field is just that. Normally this code will be zero, indicating that curl was successful. Nonzero exit codes indicate an error occurred. The semantics of [curl exit codes](https://curl.haxx.se/docs/manpage.html#EXIT) are documented on the curl man page.

Note that the documentation for each exit code is individually addressable. For example, the online documentation for [exit code 28](https://curl.haxx.se/docs/manpage.html#28) indicates a network timeout.

The remaining fields are computed by curl. The values were obtained by invoking the `curl --write-out` option. The semantics of each [write-out parameter](https://curl.haxx.se/docs/manpage.html#-w) are documented on the curl man page.

In particular, the `responseCode` field is the HTTP response code. Normally this is 200 but other responses are possible of course. If the `curlExitCode` is nonzero, and the HTTP response did not complete, the `responseCode` will be 000.

The output data are sufficient to construct a time-series plot. The `requestInstant` field is intended to be the independent variable. Any of the numerical `--write-out` parameters are potential dependent variables of interest. In particular, either  the `speedDownload` field or the `timeTotal` field gives rise to interesting time-series plots.

## Timing the response

The `http_compression_stats.bash` script has one required command-line argument:

Usage: `http_compression_stats.bash [-hqDWa] [-n NUM_OBJECTS] [-d OUT_DIR] LOCATION`

The `LOCATION` argument is the URL of interest. First specify a location as follows:

```shell
$ location=http://crl.tcs.terena.org/TERENASSLCA.crl
```

Do a quick check on the resource using the following command:

```shell
$ /usr/bin/cmp -s <(/usr/bin/curl --silent $location) <(/usr/bin/curl --silent --compressed $location)
$ echo $?
0
```

The exit code of the `cmp` command indicates whether or not the two requests produce the same resource. In this case, the exit code is 0, which confirms the integrity of the compressed resource.

Let's double-check this result by invoking the script like this:

```shell
$ $BIN_DIR/http_compression_stats.bash $location
```

Every invocation of the script performs the following steps:

1. Issue an HTTP GET request (without compression)
1. Update the corresponding response log file with the results
1. Issue an HTTP GET request (with compression)
1. Update the corresponding response log file with the results
1. Compare the two resources
1. Determine if the last response was actually compressed
1. Update the compression log file with the overall results
1. Print a tail of the compression log file in JSON format
1. Print a tail of the (uncompressed) response log file in JSON format
1. Print a tail of the (compressed) response log file in JSON format

The compression log file is maintained in the cache directory:

```shell
$ echo $CACHE_DIR 
/tmp/http_cache
$ $BIN_DIR/http_cache_ls.bash $location
/tmp/http_cache/330c712018edbc68c11fa4b7994307c132e4edf1_compression_log
/tmp/http_cache/330c712018edbc68c11fa4b7994307c132e4edf1_request_headers
/tmp/http_cache/330c712018edbc68c11fa4b7994307c132e4edf1_request_headers_z
/tmp/http_cache/330c712018edbc68c11fa4b7994307c132e4edf1_response_body
/tmp/http_cache/330c712018edbc68c11fa4b7994307c132e4edf1_response_body_z
/tmp/http_cache/330c712018edbc68c11fa4b7994307c132e4edf1_response_headers
/tmp/http_cache/330c712018edbc68c11fa4b7994307c132e4edf1_response_headers_z
/tmp/http_cache/330c712018edbc68c11fa4b7994307c132e4edf1_response_log
/tmp/http_cache/330c712018edbc68c11fa4b7994307c132e4edf1_response_log_z
```

The filename prefix (`330c712018edbc68c11fa4b7994307c132e4edf1`) is the SHA-1 hash of the location URL. In this way, each URL gives rise to a unique set of cache files.

Note the suffix `_z` on some of the filenames. This is the compressed response.

## Creating JSON output files

By default, the script directs its output to stdout. To redirect the output to a particular directory, use the `-d` option:

```shell
$ out_dir=/tmp/out/
$ $BIN_DIR/http_compression_stats.bash -d $out_dir $location
$ ls $out_dir 
330c712018edbc68c11fa4b7994307c132e4edf1_compression_stats.json
330c712018edbc68c11fa4b7994307c132e4edf1_response_stats.json
330c712018edbc68c11fa4b7994307c132e4edf1_response_stats_z.json
```

Typically the output directory is a web directory. For illustration, the above example outputs the JSON files to a temporary directory.

The script automatically determines the filenames of the JSON files based on the SHA-1 hash of the location URL, and so the filenames are unique.

By default, the JSON array will have 10 elements. To specify some other array size, add option `-n` to the command line. For example, the following command generated the output shown at the beginning of this document:

```shell
$ $BIN_DIR/http_compression_stats.bash -n 1 $location
```

Here's another, more realistic example:

```shell
$ $BIN_DIR/http_compression_stats.bash -n 30 -d $out_dir $location
```

The above command will output a JSON array of at most 30 elements. These elements correspond to the last 30 lines in the log file.

Every JSON object (both compressed and uncompressed) includes a `timeTotal` field. To output additional timing data per JSON object, use the -a option, which outputs all available timing data. For example:

```shell
$ $BIN_DIR/http_compression_stats.bash -n 1 -a $location
[
  {
    "requestInstant": "2018-04-10T23:13:41Z"
    ,
    "friendlyDate": "April 10, 2018"
    ,
    "areResponsesEqual": true
    ,
    "isResponseCompressed": true
    ,
    "UncompressedResponse":
    {
      "curlExitCode": "0"
      ,
      "responseCode": "200"
      ,
      "sizeDownload": 437
      ,
      "speedDownload": 4009.000
      ,
      "timeNamelookup": 0.033307
      ,
      "timeConnect": 0.055921
      ,
      "timeAppconnect": 0.000000
      ,
      "timePretransfer": 0.056022
      ,
      "timeStarttransfer": 0.108300
      ,
      "timeTotal": 0.108986
    }
    ,
    "CompressedResponse":
    {
      "curlExitCode": "0"
      ,
      "responseCode": "200"
      ,
      "sizeDownload": 439
      ,
      "speedDownload": 5620.000
      ,
      "timeNamelookup": 0.004517
      ,
      "timeConnect": 0.024798
      ,
      "timeAppconnect": 0.000000
      ,
      "timePretransfer": 0.024845
      ,
      "timeStarttransfer": 0.077468
      ,
      "timeTotal": 0.078103
    }
  }
]
```

The timing values (each starting with the word “time” in the output) were obtained by invoking the `curl --write-out` option. The semantics of each [write-out parameter](https://curl.haxx.se/docs/manpage.html#-w) are documented on the curl man page. 

The timing values are listed chronologically in the output. Each timing value gives the cumulative elapsed time in seconds. For example, the value of `timeConnect` (0.298768 secs) is the cumulative time for both DNS resolution (`timeNamelookup`) and TCP connection (`timeConnect`). The final time listed is the total time, given by the `timeTotal` value, which is always included in the output, even if option `-a` is omitted.

Be careful, though, depending on the total number of JSON objects, the use of option `-a` could bloat the JSON file considerably.

That’s it! To keep the JSON file up to date, you can of course automate the previous process with cron.

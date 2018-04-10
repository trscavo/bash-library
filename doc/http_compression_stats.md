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
    "diffExitCode": "0"
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

The tool compares the content of the two responses byte-by-byte. The `diffExitCode` field records the result of this comparison. The response bodies are identical if (and only if) the value of the `diffExitCode` field is zero.

Note: The tool uses the `/usr/bin/cmp` command-line tool (not `/usr/bin/diff`) to compare content. The former is more versatile since it works on both text and binary resources.

The rest of the JSON output consists of two JavaScript objects, one for the uncompressed response and the other for the compressed response (resp.). The two objects contain the same fields.

The `curlExitCode` field is just that. Normally this code will be zero, indicating that curl was successful. Nonzero exit codes indicate an error occurred. The semantics of [curl exit codes](https://curl.haxx.se/docs/manpage.html#EXIT) are documented on the curl man page.

Note that the documentation for each exit code is individually addressable. For example, the online documentation for [exit code 28](https://curl.haxx.se/docs/manpage.html#28) indicates a network timeout.

The `responseCode` field is the HTTP response code. Normally this is 200 but other responses are possible of course. If the `curlExitCode` is nonzero, and the HTTP response did not complete, the `responseCode` will be 000.

The remaining fields are computed by curl. The values were obtained by invoking the `curl --write-out` option. The semantics of each [option parameter](https://curl.haxx.se/docs/manpage.html#-w) are documented on the curl man page.

The output data are sufficient to construct a time-series plot. The `requestInstant` field is intended to be the independent variable. Any of the numerical `--write-out` parameters are potential dependent variables of interest. In particular, either  the `speedDownload` field or the `timeTotal` field gives rise to interesting time-series plots.

## Timing the response

The `http_compression_stats.bash` script has one required command-line argument:

Usage: `http_compression_stats.bash [-hqDW] [-n NUM_OBJECTS] [-d OUT_DIR] LOCATION`

The `LOCATION` argument is the URL of interest. For example, a location may be specified as follows:

```shell
$ location=http://crl.tcs.terena.org/TERENASSLCA.crl
```

Now invoke the script like this:

```shell
$ $BIN_DIR/http_compression_stats.bash $location
```

Every invocation of the script performs the following steps:

1. Issue an HTTP GET request (without compression)
1. Update the corresponding response log file with the results
1. Issue an HTTP GET request (with compression)
1. Update the corresponding response log file with the results
1. Compute the diff of the two resources
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

Here's another example:

```shell
$ $BIN_DIR/http_compression_stats.bash -n 30 -d $out_dir $location
```

The above command will output a JSON array of at most 30 elements. These elements correspond to the last 30 lines in the log file.

That’s it! To keep the JSON file up to date, you can of course automate the previous process with cron.

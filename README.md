# Bash Library

A library of re-usable bash scripts

## Installation

Download the source, change directory to the source directory, and install the source into `/tmp` as follows:

```Shell
$ export BIN_DIR=/tmp/bin
$ export LIB_DIR=/tmp/lib
$ ./install.sh $BIN_DIR $LIB_DIR
```

or install into your home directory:

```Shell
$ export BIN_DIR=$HOME/dev/bin
$ export LIB_DIR=$HOME/dev/lib
$ ./install.sh $BIN_DIR $LIB_DIR
```

A given target directory will be created if one doesn't already exist. Confirm that the files were installed:

```Shell
$ ls -1 $BIN_DIR | head -n 5
cget.bash
chead.bash
http_cache_check.bash
http_cache_diff.bash
http_cache_file.bash

$ ls -1 $LIB_DIR | head -n 5
add_validUntil_attribute.xsl
compatible_date.bash
config_tools.bash
core_lib.bash
entity_endpoints_txt.xsl
```

## Environment

Overall the scripts leverage the following environment variables (including `BIN_DIR` and `LIB_DIR` above):

| Variable | | |
| --- | --- | --- |
| `BIN_DIR` | A directory of executable scripts | REQUIRED |
| `LIB_DIR` | A directory of library source code | REQUIRED |
| `CACHE_DIR` | A persistent HTTP cache directory | REQUIRED |
| `TMPDIR` | A temporary directory | REQUIRED |
| `LOG_FILE` | A persistent log file | REQUIRED |
| `LOG_LEVEL` | The global log level [0..5] | OPTIONAL |

All but `LOG_LEVEL` are REQUIRED. See the following section for more info about logging.

Note: Some OSes define `TMPDIR` and some do not. In any case, a temporary directory by that name is required to use these scripts.

```Shell
export BIN_DIR="/path/to/bin/dir"
export LIB_DIR="/path/to/lib/dir"
export CACHE_DIR="/path/to/cache/dir"
export TMPDIR="/path/to/tmp/dir"   # may or may not be necessary
export LOG_FILE="/path/to/log/file"
```

## Logging

For convenience, we will log directly to the terminal in the examples below:

```Shell
$ export LOG_FILE=/dev/tty
$ export LOG_LEVEL=3
```

Various log levels are supported:

| | `LOG_LEVEL` |
| --- | :---: |
| TRACE | 5 |
| DEBUG | 4 |
| INFO  | 3 |
| WARN  | 2 |
| ERROR | 1 |
| FATAL | 0 |

The default log level is INFO (i.e., if you do not explicitly set the optional `LOG_LEVEL` environment variable, the value `LOG_LEVEL=3` is assumed by default).

Note: Some of the scripts have command-line options that set the log level on-the-fly. See the script help file for details.

## Overview

The following HTTP resources are used repeatedly in the examples below:

```Shell
$ url1=http://md.incommon.org/InCommon/InCommon-metadata-preview.xml
$ url2=http://md.incommon.org/InCommon/InCommon-metadata-fallback.xml
```

### `cget.sh`

Bash script `cget.sh` retrieves and caches HTTP resources on disk. A previously cached resource is retrieved via HTTP Conditional GET [RFC 7232]. If the web server responds with HTTP 200 OK, the resource is cached and written to stdout. If the web server responds with 304 Not Modified, the cached resource is output instead.

First define a cache:

```Shell
$ export CACHE_DIR=/tmp/http_cache
```

Now GET the first resource:

```Shell
$ $BIN_DIR/cget.sh $url1 > /dev/null
2017-05-07T20:33:25Z INFO cget.sh requesting resource: http://md.incommon.org/InCommon/InCommon-metadata-preview.xml
2017-05-07T20:33:30Z INFO conditional_get received response code: 200
2017-05-07T20:33:30Z INFO conditional_get writing cached content file: /tmp/http_cache/1e6b844a49d1850b82feded72cf83ed7_content
2017-05-07T20:33:30Z INFO conditional_get reading cached content file: /tmp/http_cache/1e6b844a49d1850b82feded72cf83ed7_content
$ echo $?
0
$ ls -1 $CACHE_DIR
1e6b844a49d1850b82feded72cf83ed7_content
1e6b844a49d1850b82feded72cf83ed7_headers
$ cat $CACHE_DIR/1e6b844a49d1850b82feded72cf83ed7_headers
HTTP/1.1 200 OK
Date: Sun, 07 May 2017 20:30:37 GMT
Server: Apache
Last-Modified: Fri, 05 May 2017 19:21:06 GMT
ETag: "29d99bc-54ecbca81c111"
Accept-Ranges: bytes
Content-Length: 43882940
Content-Type: application/samlmetadata+xml
```

Assuming the resource doesn't change on the server, subsequent requests will return the cached resource.

```Shell
$ $BIN_DIR/cget.sh -C $url1 | wc -c
2017-05-07T20:35:30Z INFO cget.sh requesting resource: http://md.incommon.org/InCommon/InCommon-metadata-preview.xml
2017-05-07T20:35:30Z INFO conditional_get reading cached content file: /tmp/http_cache/1e6b844a49d1850b82feded72cf83ed7_content
 43882940
```

Of course the `-C` option will fail if the resource is not cached:

```Shell
# illustrate "quiet failure mode"
$ $BIN_DIR/cget.sh -C $url2
2017-05-07T20:36:07Z INFO cget.sh requesting resource: http://md.incommon.org/InCommon/InCommon-metadata-fallback.xml
2017-05-07T20:36:07Z WARN conditional_get: resource not cached: http://md.incommon.org/InCommon/InCommon-metadata-fallback.xml
$ echo $?
1
```

OTOH, the `-F` option forces the return of a fresh resource from the server. If the resource is cached and unchanged on the server (304), such a request will fail, however:

```Shell
# further illustrate "quiet failure mode"
$ $BIN_DIR/cget.sh -F $url1
2017-05-07T20:36:58Z INFO cget.sh requesting resource: http://md.incommon.org/InCommon/InCommon-metadata-preview.xml
2017-05-07T20:36:58Z INFO conditional_get received response code: 304
2017-05-07T20:36:58Z WARN conditional_get: resource not modified: http://md.incommon.org/InCommon/InCommon-metadata-preview.xml
$ echo $?
1
```

The `-F` option will work on the other URL, however:

```Shell
$ $BIN_DIR/cget.sh -F $url2 > /dev/null
2017-05-07T20:37:50Z INFO cget.sh requesting resource: http://md.incommon.org/InCommon/InCommon-metadata-fallback.xml
2017-05-07T20:37:54Z INFO conditional_get received response code: 200
2017-05-07T20:37:54Z INFO conditional_get writing cached content file: /tmp/http_cache/1727196e5b7593f3b7528c539e7169d2_content
2017-05-07T20:37:54Z INFO conditional_get reading cached content file: /tmp/http_cache/1727196e5b7593f3b7528c539e7169d2_content
$ echo $?
0
$ ls -1 $CACHE_DIR
1727196e5b7593f3b7528c539e7169d2_content
1727196e5b7593f3b7528c539e7169d2_headers
1e6b844a49d1850b82feded72cf83ed7_content
1e6b844a49d1850b82feded72cf83ed7_headers
$ cat $CACHE_DIR/1727196e5b7593f3b7528c539e7169d2_headers
HTTP/1.1 200 OK
Date: Sun, 07 May 2017 20:35:01 GMT
Server: Apache
Last-Modified: Fri, 05 May 2017 19:21:06 GMT
ETag: "29d99bc-54ecbca8059e8"
Accept-Ranges: bytes
Content-Length: 43882940
Content-Type: application/samlmetadata+xml
```

See the inline help file for details:

```Shell
$ $BIN_DIR/cget.sh -h
```

## Compatibility

The shell scripts are compatible with both GNU/Linux and Mac OS. The XSLT scripts are written in XSLT 1.0.

## Dependencies

None

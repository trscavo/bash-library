# Bash Library

A library of re-usable bash scripts

## Overview

Bash Library features:

* implements an HTTP conditional request (RFC 7232) client
* monitors an HTTP resource that supports HTTP Compression
* monitors an HTTP resource for responsiveness
* includes a compatibility layer (Linux and Mac OS)
* has a built-in logging facility
* is cron-friendly

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

A given target directory will be created if one doesn't already exist. The following commands confirm that the files were installed:

```Shell
$ ls -1 $BIN_DIR | head -n 5
cget.bash
chead.bash
http_cache_check.bash
http_cache_diff.bash
http_cache_file.bash

$ ls -1 $LIB_DIR | head -n 5
compatible_date.bash
config_tools.bash
core_lib.bash
http_cache_tools.bash
http_log_tools.bash
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

Assuming your OS defines `TMPDIR`, the following environment variables will suffice:

```Shell
export BIN_DIR=/tmp/bin
export LIB_DIR=/tmp/lib
export CACHE_DIR=/tmp/http_cache
export LOG_FILE=/tmp/bash_log.txt
```

## Logging

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

## Compatibility

The shell scripts are compatible with both GNU/Linux and Mac OS.

## Dependencies

None

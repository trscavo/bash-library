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

TBD

## Compatibility

The shell scripts are compatible with both GNU/Linux and Mac OS. The XSLT scripts are written in XSLT 1.0.

## Dependencies

None

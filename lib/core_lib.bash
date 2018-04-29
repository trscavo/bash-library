#!/bin/bash

#######################################################################
# Copyright 2013--2018 Tom Scavo
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#######################################################################

#######################################################################
# Specify the absolute path to each shell command file.
# 
# For example, instead of writing code such as:
# 
#   cat $file | grep $pattern
# 
# we write this instead:
# 
#   $_CAT $file | $_GREP $pattern
# 
# Scripts written in this way do not depend on the underlying PATH
# and therefore function well across platforms and as cron jobs.
#
# This script is compatible with Mac OS and GNU/Linux.
#######################################################################

# commands with compatible paths
_BASE64=/usr/bin/base64
_BC=/usr/bin/bc
_CAT=/bin/cat
_CMP=/usr/bin/cmp
_CP=/bin/cp
_CURL=/usr/bin/curl
_DATE=/bin/date
_DD=/bin/dd
_DIFF=/usr/bin/diff
_DIRNAME=/usr/bin/dirname
_ECHO=/bin/echo  # also a bash builtin
_FIND=/usr/bin/find
_HEAD=/usr/bin/head
_LS=/bin/ls
_MKDIR=/bin/mkdir
_MV=/bin/mv
_OPENSSL=/usr/bin/openssl
_PRINTF=/usr/bin/printf  # also a bash builtin
_RM=/bin/rm
_RMDIR=/bin/rmdir
_RSYNC=/usr/bin/rsync
_TAIL=/usr/bin/tail
_TEE=/usr/bin/tee
_TR=/usr/bin/tr
_UNIQ=/usr/bin/uniq
_WC=/usr/bin/wc
_XARGS=/usr/bin/xargs
_XSLTPROC=/usr/bin/xsltproc

# commands with incompatible paths
if [[ ${OSTYPE} = darwin* ]] ; then

	_AWK=/usr/bin/awk
	_BASENAME=/usr/bin/basename
	_CUT=/usr/bin/cut
	_GREP=/usr/bin/grep
	_GZIP=/usr/bin/gzip
	_GUNZIP=/usr/bin/gunzip
	_MKTEMP=/usr/bin/mktemp
	_MORE=/usr/bin/more
	_SED=/usr/bin/sed
	_SEDEXT="/usr/bin/sed -E"
	_SORT=/usr/bin/sort
	_TOUCH=/usr/bin/touch

elif [[ ${OSTYPE} = linux* ]] ; then

	_AWK=/bin/awk
	_BASENAME=/bin/basename
	_CUT=/bin/cut
	_GREP=/bin/grep
	_GZIP=/bin/gzip
	_GUNZIP=/bin/gunzip
	_MKTEMP=/bin/mktemp
	_MORE=/bin/more
	_SED=/bin/sed
	_SEDEXT="/bin/sed -r"
	_SORT=/bin/sort
	_TOUCH=/bin/touch

else
	echo "ERROR: OS not supported: ${OSTYPE}" >&2
	exit 1
fi

#######################################################################
# A simple compatibility wrapper around the mktemp command.
#
# Usage:
#   $ make_temp_file [-d] [PREFIX]
#
# By default, creates a temporary file (use the -d option to
# create a directory). Takes an optional prefix argument that
# is used to construct the temporary file (or directory) name
# (defaults to some unspecified prefix if the argument is omitted).
#
# This script is compatible with Mac OS and GNU/Linux.
#######################################################################

make_temp_file () {
	local prefix
	local _path_mktemp
	local mktemp_arg
	local temp_file
	local return_code

	# process command-line options (if any)
	local OPTARG
	local OPTIND
	local local_opts=
	while getopts "d" opt; do
		case $opt in
			d)
				local_opts=-d
				;;
			\?)
				echo "ERROR: $FUNCNAME: Unrecognized option: -$OPTARG" >&2
				return 1
				;;
		esac
	done

	# determine the prefix
	shift $((OPTIND-1))
	if [ $# -eq 0 ]; then
		prefix="temp"
	else
		prefix="$1"
	fi

	if [[ ${OSTYPE} = darwin* ]] ; then
		_path_mktemp=/usr/bin/mktemp
		# on Mac OS, mktemp takes a prefix
		mktemp_arg="${prefix}"
	elif [[ ${OSTYPE} = linux* ]] ; then
		_path_mktemp=/bin/mktemp
		# on Linux, mktemp takes a template
		mktemp_arg="${prefix}.XXXXXXXX"
	else
		echo "ERROR: OS not supported: ${OSTYPE}" >&2
		return 1
	fi

	# create temporary file
	temp_file=$( ${_path_mktemp} ${local_opts} -t ${mktemp_arg} )
	return_code=$?
	if [ $return_code -ne 0 ] ; then
		echo "ERROR: $FUNCNAME: failed to make temp file" >&2
		return $return_code
	fi

	echo $temp_file
	return 0
}

#######################################################################
# Prints a message to a log file.
#
# Usage:
#   $ print_log_message [-TDIWEF] LOG_MESSAGE
#
# Computes and prepends a timestamp to the LOG_MESSAGE
# before appending the message to a log file.
#
# Options:
#   -T  enable TRACE logging
#   -D  enable DEBUG logging
#   -I  enable INFO logging (default)
#   -W  enable WARN logging
#   -E  enable ERROR logging
#   -F  enable FATAL logging
#
# The command-line options are mutually exclusive. If no option is
# given on the command line, the -I option is assumed.
#
# Two environment variables are consulted:
#
#   LOG_FILE:  Path to the log file (REQUIRED)
#   LOG_LEVEL: Global log level [0..5] (OPTIONAL)
#
# If LOG_FILE is not set or the file is not found, the script
# immediately terminates. If LOG_LEVEL is not set, the value 
# LOG_LEVEL=3 is used by default.
#
# The command-line options interact with the global log level.
# A message may or may not be logged depending on the chosen 
# option in relation to the global log level. Specifically, if
# the log level indicated on the command line is greater than
# the global log level, the log operation is short-circuited.
#
# This script is compatible with Mac OS and GNU/Linux.
#######################################################################

print_log_message () {

	# determine the log file
	if [ -z "$LOG_FILE" ]; then
		echo "FATAL: $FUNCNAME requires env var LOG_FILE" >&2
		exit 2
	fi
	if [ ! -f "$LOG_FILE" ] && [[ $LOG_FILE != /dev/* ]]; then
		echo "FATAL: $FUNCNAME: file does not exist: $LOG_FILE" >&2
		exit 2
	fi

	local error_message
	local log_message
	local tstamp
	
	# compute timestamp
	tstamp=$( /bin/date -u +%Y-%m-%dT%TZ )
	if [ $? -ne 0 ]; then 
		tstamp=0000-00-00T00:00:00Z
		error_message="$FUNCNAME: unable to compute timestamp"
		printf "%s %s %s\n" "$tstamp" ERROR "$error_message" >> "$LOG_FILE"
	fi
	
	# default log level
	local prefix=INFO
	local log_level=3

	# process command-line options and arguments
	local opt
	local OPTARG
	local OPTIND
	while getopts ":TDIWEF" opt; do
		case $opt in
			T)
				prefix=TRACE; log_level=5
				;;
			D)
				prefix=DEBUG; log_level=4
				;;
			I)
				prefix=INFO; log_level=3
				;;
			W)
				prefix=WARN; log_level=2
				;;
			E)
				prefix=ERROR; log_level=1
				;;
			F)
				prefix=FATAL; log_level=0
				;;
			\?)
				error_message="$FUNCNAME: Unrecognized option: -$OPTARG"
				printf "%s %s %s\n" "$tstamp" ERROR "$error_message" >> "$LOG_FILE"
				;;
			:)
				error_message="$FUNCNAME: Option -$OPTARG requires an argument"
				printf "%s %s %s\n" "$tstamp" ERROR "$error_message" >> "$LOG_FILE"
				;;
		esac
	done
	
	# make sure there is one command-line argument
	shift $(( OPTIND - 1 ))
	if [ $# -lt 1 ]; then
		error_message="$FUNCNAME: no arguments (1 required)"
		printf "%s %s %s\n" "$tstamp" ERROR "$error_message" >> "$LOG_FILE"
		log_message=NULL
	elif [ $# -gt 1 ]; then
		error_message="$FUNCNAME: too many arguments: $# (1 required)"
		printf "%s %s %s\n" "$tstamp" ERROR "$error_message" >> "$LOG_FILE"
		log_message="$1"
	else
		log_message="$1"
	fi
	
	# if insufficient log level, short-circuit the log operation
	if [ -z "$LOG_LEVEL" ]; then
		if [ "$log_level" -gt 3 ]; then return 0; fi
	else
		if [ "$log_level" -gt "$LOG_LEVEL" ]; then return 0; fi
	fi
	
	printf "%s %s %s\n" "$tstamp" "$prefix" "$log_message" >> "$LOG_FILE"
}

#######################################################################
# Clean up and exit the script.
#
# Usage:
#   $ clean_up_and_exit [-d DIR_TO_BE_DELETED] EXIT_CODE
#
# This script is compatible with Mac OS and GNU/Linux.
#######################################################################

clean_up_and_exit () {

	local unwanted_dir
	local final_msg
	local exit_code

	local opt
	local save_opt
	local OPTARG
	local OPTIND
	while getopts ":d:T:D:I:W:E:F:" opt; do
		case $opt in
			d)
				unwanted_dir="$OPTARG"
				;;
			[TDIWEF])
				save_opt=$opt
				final_msg="$OPTARG"
				;;
			\?)
				print_log_message -E "$FUNCNAME: Unrecognized option: -$OPTARG"
				;;
			:)
				print_log_message -E "$FUNCNAME: Option -$OPTARG requires an argument"
				;;
		esac
	done
	
	# determine the exit code
	shift $(( OPTIND - 1 ))
	if [ $# -ne 1 ]; then
		print_log_message -F "$FUNCNAME: wrong number of arguments: $# (1 required)"
		exit 2
	fi
	exit_code="$1"
	if [ ! "$exit_code" -ge 0 ] ; then
		print_log_message -F "$FUNCNAME: illegal exit code: $exit_code"
		exit 2
	fi
	
	if [ -n "$unwanted_dir" ]; then
		if [ ! -d "$unwanted_dir" ]; then
			print_log_message -E "$FUNCNAME: directory does not exist: $unwanted_dir"
		else
			# remove the unwanted directory (!)
			print_log_message -D "$FUNCNAME removing dir: $unwanted_dir"
			/bin/rm -rf "$unwanted_dir"
			if [ $? -ne 0 ]; then
				print_log_message -E "$FUNCNAME failed to remove dir: $unwanted_dir"
			fi
		fi
	fi
	
	# print final message (if any)
	[ -n "$final_msg" ] && print_log_message -$save_opt "$final_msg"
	
	exit $exit_code
}

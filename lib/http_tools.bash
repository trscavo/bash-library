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
#
# This function takes a file containing an HTTP response header and  
# returns the HTTP response code.
#
# Usage: get_response_code FILE
#
# Dependencies:
#   core_lib.bash
#
#######################################################################

get_response_code () {

	# external dependencies
	if [ "$(type -t print_log_message)" != function ]; then
		echo "ERROR: $FUNCNAME: function print_log_message not found" >&2
		exit 2
	fi

	# check the number of arguments
	if [ $# -ne 1 ]; then
		print_log_message -E "$FUNCNAME: incorrect number of arguments: $# (1 required)"
		return 2
	fi
	
	# make sure the file exists
	if [ ! -f "$1" ]; then
		print_log_message -E "$FUNCNAME: file does not exist: $1"
		return 2
	fi
	
	# extract the response code from the header
	/bin/cat "$1" \
		| /usr/bin/head -1 \
		| $_SED -e 's/^[^ ]* \([^ ]*\) .*$/\1/'
		
	return 0
}

#######################################################################
#
# This function takes a file containing an HTTP response header and
# a header name, and then returns the header value (if any).
#
# Usage: get_header_value FILE HEADER_NAME
#
# Dependencies:
#   core_lib.bash
#
#######################################################################

get_header_value () {

	# external dependencies
	if [ "$(type -t print_log_message)" != function ]; then
		echo "ERROR: $FUNCNAME: function print_log_message not found" >&2
		exit 2
	fi

	# check the number of arguments
	if [ $# -ne 2 ]; then
		print_log_message -E "$FUNCNAME: incorrect number of arguments: $# (2 required)"
		return 2
	fi
	
	# make sure the file exists
	if [ ! -f "$1" ]; then
		print_log_message -E "$FUNCNAME: file does not exist: $1"
		return 2
	fi
	
	# extract the desired value from the header
#	/bin/cat "$1" \
#		| $_GREP -F "$2" \
#		| /usr/bin/tr -d "\r" \
#		| $_SED -e 's/^[^:]*: [ ]*//' -e 's/[ ]*$//'
	/bin/cat "$1" \
		| $_GREP "^$2:" \
		| $_SEDEXT -e 's/^[^:]+:[[:space:]]+//' \
		| $_SEDEXT -e 's/[[:space:]]*$//'
		
	return 0
}

#######################################################################
#
# This function percent-encodes all characters in its string argument
# except the "Unreserved Characters" defined in section 2.3 of RFC 3986.
#
# See: https://gist.github.com/cdown/1163649
#      https://en.wikipedia.org/wiki/Percent-encoding
#
#######################################################################
percent_encode () {
    # percent_encode <string>
	
	# make sure there is one (and only one) command-line argument
	if [ $# -ne 1 ]; then
		echo "ERROR: $FUNCNAME: incorrect number of arguments: $# (1 required)" >&2
		return 2
	fi
	
	# this implementation assumes a particular collating sequence
	local LC_COLLATE=C
	
	local length
	local c

	length="${#1}"
	for (( i = 0; i < length; i++ )); do
		c="${1:i:1}"
		case "$c" in
			[a-zA-Z0-9.~_-]) printf "$c" ;;
			*) printf '%%%02X' "'$c"
		esac
	done
}

#######################################################################
#
# This function is the inverse of the percent_encode function, that 
# is, it percent-decodes all percent-encoded characters in its string 
# argument.
#
#######################################################################
percent_decode () {
    # percent_decode <string>

	# make sure there is one (and only one) command-line argument
	if [ $# -ne 1 ]; then
		echo "ERROR: $FUNCNAME: incorrect number of arguments: $# (1 required)" >&2
		return 2
	fi
	
    printf '%b' "${1//%/\\x}"
}

#######################################################################
#
# This helper function computes a prefix of the absolute path
# to a file corresponding to the given HTTP location.
#
# Usage: opaque_path_prefix -d PREFIX_DIR HTTP_LOCATION
#
# To construct the path prefix, the HTTP location is hashed using
# an unspecified hash function.
#
# Dependencies:
#   core_lib.bash
#
#######################################################################
opaque_path_prefix () {

	# external dependencies
	if [ "$(type -t print_log_message)" != function ]; then
		echo "ERROR: $FUNCNAME: function print_log_message not found" >&2
		exit 2
	fi

	local prefix_dir
	local location
	local hash
	local status_code
	
	local opt
	local OPTARG
	local OPTIND
	
	while getopts ":d:" opt; do
		case $opt in
			d)
				prefix_dir="$OPTARG"
				;;
			\?)
				print_log_message -E "$FUNCNAME: Unrecognized option: -$OPTARG"
				return 2
				;;
			:)
				print_log_message -E "$FUNCNAME: Option -$OPTARG requires an argument"
				return 2
				;;
		esac
	done
	
	# a prefix directory is required
	if [ -z "$prefix_dir" ]; then
		echo "ERROR: $FUNCNAME: no prefix directory specified" >&2
		return 2
	fi
	if [ ! -d "$prefix_dir" ]; then
		echo "ERROR: $FUNCNAME: directory does not exist: $prefix_dir" >&2
		return 2
	fi

	# check the number of command-line arguments
	shift $(( OPTIND - 1 ))
	if [ $# -ne 1 ]; then
		print_log_message -E "$FUNCNAME: incorrect number of arguments: $# (1 required)"
		return 2
	fi
	location="$1"
	
	# compute the hash of the location
	hash=$( echo -n $location | /usr/bin/openssl sha1 )
	status_code=$?
	if [ $status_code -ne 0 ]; then
		print_log_message -E "$FUNCNAME failed ($status_code) to hash the location URL"
		return 3
	fi

	echo "${prefix_dir%%/}/$hash"
}

#######################################################################
#
# This helper function computes the absolute path to a file
# corresponding to the given HTTP location and base filename.
#
# Usage: opaque_file_path [-z] [-e FILE_EXT] -d PREFIX_DIR HTTP_LOCATION BASE_FILENAME
#
# Option -z indicates that the HTTP resource is intended to be
# retrieved via HTTP Conditional GET.
#
# To construct the file path, the HTTP location is hashed using
# an unspecified hash function.
#
# Dependencies:
#   core_lib.bash
#
#######################################################################
opaque_file_path () {

	# external dependencies
	if [ "$(type -t print_log_message)" != function ]; then
		echo "ERROR: $FUNCNAME: function print_log_message not found" >&2
		exit 2
	fi

	local compressed_mode
	local file_ext
	local prefix_dir
	local location
	local base_filename
	local file_path
	local status_code
	
	local opt
	local OPTARG
	local OPTIND
	
	compressed_mode=false
	
	while getopts ":ze:d:" opt; do
		case $opt in
			z)
				compressed_mode=true
				;;
			e)
				file_ext="$OPTARG"
				;;
			d)
				prefix_dir="$OPTARG"
				;;
			\?)
				print_log_message -E "$FUNCNAME: Unrecognized option: -$OPTARG"
				return 2
				;;
			:)
				print_log_message -E "$FUNCNAME: Option -$OPTARG requires an argument"
				return 2
				;;
		esac
	done
	
	# check the number of command-line arguments
	shift $(( OPTIND - 1 ))
	if [ $# -ne 2 ]; then
		print_log_message -E "$FUNCNAME: incorrect number of arguments: $# (2 required)"
		return 2
	fi
	location="$1"
	base_filename="$2"
	
	file_path=$( opaque_path_prefix -d "$prefix_dir" "$location" )_$base_filename
	status_code=$?
	if [ $status_code -ne 0 ]; then
		print_log_message -E "$FUNCNAME failed ($status_code) to compute the file path"
		return 3
	fi
	$compressed_mode && file_path="${file_path}_z"
	[ -n "$file_ext" ] && file_path="${file_path}.$file_ext"
	
	echo "$file_path"
}

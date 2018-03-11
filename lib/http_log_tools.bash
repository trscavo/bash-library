#!/bin/bash

#######################################################################
# Copyright 2018 Tom Scavo
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
#######################################################################
#
# Timestamp log file
#
#######################################################################
#######################################################################

#######################################################################
#
# This function computes the absolute path to a particular
# timestamp log file in the cache.
#
# Usage: timestamp_log_file [-z] -d CACHE_DIR LOCATION
#
# Dependencies:
#   core_lib.bash
#   http_tools.bash
#
#######################################################################
timestamp_log_file () {
	opaque_file_path "$@" timestamp_log
}

#######################################################################
#
# This function updates a particular timestamp log file.
#
# Usage: update_timestamp_log [-z] -T TMP_DIR -d CACHE_DIR LOCATION TIMESTAMP
#
# Dependencies:
#   core_lib.bash
#   http_tools.bash
#   http_cache_tools.bash
#   xsl_wrappers.bash
#
#######################################################################
update_timestamp_log () {
	
	# external dependencies 
	if [ "$(type -t print_log_message)" != function ]; then
		echo "ERROR: $FUNCNAME: function print_log_message not found" >&2
		return 2
	fi
	if [ "$(type -t cache_response_body_file)" != function ]; then
		echo "ERROR: $FUNCNAME: function cache_response_body_file not found" >&2
		return 2
	fi
	if [ "$(type -t parse_saml_metadata)" != function ]; then
		echo "ERROR: $FUNCNAME: function parse_saml_metadata not found" >&2
		return 2
	fi
	
	local local_opts
	local cache_dir
	local tmp_dir
	local timestamp
	local location
	local md_file
	local doc_info
	local creationInstant
	local validUntil
	local cached_log_file
	
	local status_code

	local opt
	local OPTARG
	local OPTIND
	
	while getopts ":zd:T:" opt; do
		case $opt in
			z)
				#compressed_mode=true
				local_opts="$local_opts -$opt"
				;;
			d)
				cache_dir="$OPTARG"
				local_opts="$local_opts -$opt $OPTARG"
				;;
			T)
				tmp_dir="$OPTARG"
				;;
			\?)
				echo "ERROR: $FUNCNAME: Unrecognized option: -$OPTARG" >&2
				return 2
				;;
			:)
				echo "ERROR: $FUNCNAME: Option -$OPTARG requires an argument" >&2
				return 2
				;;
		esac
	done
		
	# a temporary directory is required
	if [ -z "$tmp_dir" ]; then
		echo "ERROR: $FUNCNAME: no temporary directory specified" >&2
		return 2
	fi
	if [ ! -d "$tmp_dir" ]; then
		echo "ERROR: $FUNCNAME: directory does not exist: $tmp_dir" >&2
		return 2
	fi

	# a cache directory is required
	if [ -z "$cache_dir" ]; then
		echo "ERROR: $FUNCNAME: no cache directory specified" >&2
		return 2
	fi
	if [ ! -d "$cache_dir" ]; then
		echo "ERROR: $FUNCNAME: directory does not exist: $cache_dir" >&2
		return 2
	fi

	# determine the HTTP location
	shift $(( OPTIND - 1 ))
	if [ $# -ne 2 ]; then
		echo "ERROR: $FUNCNAME: wrong number of arguments: $# (2 required)" >&2
		return 2
	fi
	location="$1"
	timestamp="$2"
	
	# check arguments
	if [ -z "$location" ] ; then
		echo "ERROR: $FUNCNAME: empty LOCATION argument" >&2
		return 2
	fi
	if [ -z "$timestamp" ]; then
		echo "ERROR: $FUNCNAME: empty TIMESTAMP argument" >&2
		return 2
	fi
	
	# check the metadata file
	md_file=$( cache_response_body_file $local_opts $location )
	if [ ! -f "$md_file" ]; then
		print_log_message -E "$FUNCNAME: file not found: $md_file"
		return 4
	fi
	print_log_message -D "$FUNCNAME md_file: $md_file"
	
	# parse the metadata
	doc_info=$( parse_saml_metadata "$md_file" )
	status_code=$?
	if [ $status_code -ne 0 ]; then
		print_log_message -E "$FUNCNAME: parse_saml_metadata failed ($status_code)"
		return 3
	fi

	# get @creationInstant
	creationInstant=$( echo "$doc_info" | $_GREP '^creationInstant' | $_CUT -f2 )
	if [ -z "$creationInstant" ]; then
		print_log_message -E "$FUNCNAME: creationInstant not found"
		return 4
	fi
	print_log_message -I "$FUNCNAME: creationInstant: $creationInstant"

	# get @validUntil
	validUntil=$( echo "$doc_info" | $_GREP '^validUntil' | $_CUT -f2 )
	if [ -z "$validUntil" ]; then
		print_log_message -E "$FUNCNAME: validUntil not found"
		return 4
	fi
	print_log_message -I "$FUNCNAME: validUntil: $validUntil"

	# determine the timestamp log file path
	cached_log_file=$( timestamp_log_file $local_opts $location )
	status_code=$?
	if [ $status_code -ne 0 ]; then
		print_log_message -E "$FUNCNAME timestamp_log_file failed ($status_code) on location: $location"
		return 3
	fi

	# compute and log the timestamps
	echo "$timestamp $creationInstant $validUntil" \
		| /usr/bin/xargs printf "%s\t%s\t%s\n" >> "$cached_log_file"
	status_code=$?
	if [ $status_code -ne 0 ]; then
		print_log_message -E "$FUNCNAME failed ($status_code) to append to log file: $cached_log_file"
		return 3
	fi
	
	echo "$cached_log_file"
}

append_timestamp_object () {

	local currentDateTime
	local creationInstant
	local validUntil
	local secsSinceEpoch
	local secsSinceCreation
	local secsUntilExpiration
	local validityIntervalSecs
	local status_code
	
	currentDateTime=$1
	creationInstant=$2
	validUntil=$3
	
	# convert current time is secs past the Epoch
	secsSinceEpoch=$( dateTime_canonical2secs $currentDateTime )
	status_code=$?
	if [ $status_code -ne 0 ]; then
		print_log_message -E "$FUNCNAME: dateTime_canonical2secs failed ($status_code) to compute secsSinceEpoch"
		return 3
	fi
	
	# compute secs since creation of metadata
	secsSinceCreation=$( secsBetween $creationInstant $currentDateTime )
	status_code=$?
	if [ $status_code -ne 0 ]; then
		print_log_message -E "$FUNCNAME: secsBetween failed ($status_code) to compute secsSinceCreation"
		return 3
	fi
	
	# compute secs until expiration of metadata
	secsUntilExpiration=$( secsBetween $currentDateTime $validUntil )
	status_code=$?
	if [ $status_code -ne 0 ]; then
		print_log_message -E "$FUNCNAME: secsBetween failed ($status_code) to compute secsUntilExpiration"
		return 3
	fi

	# compute the length of the validity interval in secs
	validityIntervalSecs=$( secsBetween $creationInstant $validUntil )
	status_code=$?
	if [ $status_code -ne 0 ]; then
		print_log_message -E "$FUNCNAME: secsBetween failed ($status_code) to compute validityIntervalSecs"
		return 3
	fi

	/bin/cat <<- JSON_OBJECT
	  {
	    "currentDateTime": "$currentDateTime"
	    ,
	    "friendlyDate": "$( dateTime_canonical2friendlyDate $currentDateTime )"
	    ,
	    "creationInstant": "$creationInstant"
	    ,
	    "validUntil": "$validUntil"
	    ,
	    "sinceEpoch": {
	      "secs": $secsSinceEpoch,
	      "hours": $( secs2hours $secsSinceEpoch ),
	      "days": $( secs2days $secsSinceEpoch )
	    }
	    ,
	    "sinceCreation": {
	      "secs": $secsSinceCreation,
	      "hours": $( secs2hours $secsSinceCreation ),
	      "days": $( secs2days $secsSinceCreation )
	    }
	    ,
	    "untilExpiration": {
	      "secs": $secsUntilExpiration,
	      "hours": $( secs2hours $secsUntilExpiration ),
	      "days": $( secs2days $secsUntilExpiration )
	    }
	    ,
	    "validityInterval": {
	      "secs": $validityIntervalSecs,
	      "hours": $( secs2hours $validityIntervalSecs ),
	      "days": $( secs2days $validityIntervalSecs )
	    }
	  }
JSON_OBJECT
}

#######################################################################
#######################################################################
#
# Response log file
#
#######################################################################
#######################################################################

#######################################################################
#
# This function computes the absolute path to a particular
# response log file in the cache.
#
# Usage: response_log_file [-z] -d CACHE_DIR LOCATION
#
# Dependencies:
#   core_lib.bash
#   http_tools.bash
#
#######################################################################
response_log_file () {
	opaque_file_path "$@" response_log
}

#######################################################################
#
# This function updates a particular response log file.
#
# Usage: update_response_log [-z] -T TMP_DIR -d CACHE_DIR LOCATION TIMESTAMP
#
# Dependencies:
#   core_lib.bash
#   http_tools.bash
#   http_cache_tools.bash
#
#######################################################################
update_response_log () {
	
	# external dependencies
	if [ "$(type -t print_log_message)" != function ]; then
		echo "ERROR: $FUNCNAME: function print_log_message not found" >&2
		return 2
	fi
	if [ "$(type -t tmp_curl_results_filename)" != function ]; then
		echo "ERROR: $FUNCNAME: function tmp_curl_results_filename not found" >&2
		return 2
	fi
	
	local local_opts
	local cache_dir
	local tmp_dir
	local timestamp
	local location
	local curl_results_file
	local curl_results
	local cached_log_file
	
	local status_code

	local opt
	local OPTARG
	local OPTIND
	
	while getopts ":zd:T:" opt; do
		case $opt in
			z)
				#compressed_mode=true
				local_opts="$local_opts -$opt"
				;;
			d)
				cache_dir="$OPTARG"
				local_opts="$local_opts -$opt $OPTARG"
				;;
			T)
				tmp_dir="$OPTARG"
				;;
			\?)
				echo "ERROR: $FUNCNAME: Unrecognized option: -$OPTARG" >&2
				return 2
				;;
			:)
				echo "ERROR: $FUNCNAME: Option -$OPTARG requires an argument" >&2
				return 2
				;;
		esac
	done
	
	# a temporary directory is required
	if [ -z "$tmp_dir" ]; then
		echo "ERROR: $FUNCNAME: no temporary directory specified" >&2
		return 2
	fi
	if [ ! -d "$tmp_dir" ]; then
		echo "ERROR: $FUNCNAME: directory does not exist: $tmp_dir" >&2
		return 2
	fi
	print_log_message -D "$FUNCNAME using temporary directory $tmp_dir"

	# a cache directory is required
	if [ -z "$cache_dir" ]; then
		echo "ERROR: $FUNCNAME: no cache directory specified" >&2
		return 2
	fi
	if [ ! -d "$cache_dir" ]; then
		echo "ERROR: $FUNCNAME: directory does not exist: $cache_dir" >&2
		return 2
	fi
	print_log_message -D "$FUNCNAME using cache directory $cache_dir"

	# determine the HTTP location
	shift $(( OPTIND - 1 ))
	if [ $# -ne 2 ]; then
		echo "ERROR: $FUNCNAME: wrong number of arguments: $# (2 required)" >&2
		return 2
	fi
	location="$1"
	timestamp="$2"
	
	# check arguments
	if [ -z "$location" ] ; then
		echo "ERROR: $FUNCNAME: empty LOCATION argument" >&2
		return 2
	fi
	if [ -z "$timestamp" ]; then
		echo "ERROR: $FUNCNAME: empty TIMESTAMP argument" >&2
		return 2
	fi
	print_log_message -D "$FUNCNAME using location $location"
	print_log_message -D "$FUNCNAME using timestamp $timestamp"
	
	# check curl results
	curl_results_file="$tmp_dir/$( tmp_curl_results_filename )"
	if [ ! -f "$curl_results_file" ]; then
		print_log_message -E "$FUNCNAME: file not found: $curl_results_file"
		return 4
	fi
	
	# the file should have only one line but...
	curl_results=$( /usr/bin/head -n 1 "$curl_results_file" )
	status_code=$?
	if [ $status_code -ne 0 ]; then
		print_log_message -E "$FUNCNAME head failed ($status_code)"
		return 3
	fi
	
	# determine the log file for the response
	cached_log_file=$( response_log_file $local_opts $location )
	status_code=$?
	if [ $status_code -ne 0 ]; then
		print_log_message -E "$FUNCNAME response_log_file failed ($status_code) on location: $location"
		return 3
	fi

	# append the curl results to the log file
	echo -e "$timestamp $curl_results" \
		| /usr/bin/xargs printf "%s\t%s\t%s\n" >> "$cached_log_file"
	status_code=$?
	if [ $status_code -ne 0 ]; then
		print_log_message -E "$FUNCNAME failed ($status_code) to append to log file: $cached_log_file"
		return 3
	fi
	
	echo "$cached_log_file"
}

append_response_object () {

	local requestInstant
	local exitCode
	local response_code
	local size_download
	local speed_download
	local time_namelookup
	local time_connect
	local time_appconnect
	local time_pretransfer
	local time_starttransfer
	local time_total
	
	requestInstant=$1
	exitCode=$2
	eval "$3"
	
	/bin/cat <<- JSON_OBJECT
	  {
	    "requestInstant": "$requestInstant"
	    ,
	    "friendlyDate": "$( dateTime_canonical2friendlyDate $requestInstant )"
	    ,
	    "curlExitCode": "$exitCode"
	    ,
	    "responseCode": "$response_code"
	    ,
	    "sizeDownload": $size_download
	    ,
	    "speedDownload": $speed_download
	    ,
	    "timeNamelookup": $time_namelookup
	    ,
	    "timeConnect": $time_connect
	    ,
	    "timeAppconnect": $time_appconnect
	    ,
	    "timePretransfer": $time_pretransfer
	    ,
	    "timeStarttransfer": $time_starttransfer
	    ,
	    "timeTotal": $time_total
	  }
JSON_OBJECT
}

#######################################################################
#######################################################################
#
# Compression log file
#
#######################################################################
#######################################################################

#######################################################################
#
# This function computes the absolute path to a particular
# compression log file in the cache.
#
# Usage: compression_log_file -d CACHE_DIR LOCATION
#
# Compression is controlled internally, which is why option -z
# isn't supported.
#
# Dependencies:
#   core_lib.bash
#   http_tools.bash
#
#######################################################################
compression_log_file () {
	opaque_file_path "$@" compression_log
}

#######################################################################
#
# This function updates a particular compression log file.
#
# Usage: update_compression_log -T TMP_DIR -d CACHE_DIR LOCATION TIMESTAMP EXIT_CODE
#
# Dependencies:
#   core_lib.bash
#   http_tools.bash
#   http_cache_tools.bash
#
#######################################################################
update_compression_log () {
	
	# external dependencies
	if [ "$(type -t print_log_message)" != function ]; then
		echo "ERROR: $FUNCNAME: function print_log_message not found" >&2
		return 2
	fi
	if [ "$(type -t tmp_curl_results_filename)" != function ]; then
		echo "ERROR: $FUNCNAME: function tmp_curl_results_filename not found" >&2
		return 2
	fi
	
	local cache_dir
	local tmp_dir
	local location
	local timestamp
	local diff_exit_code
	local curl_results_file
	local num_lines
	local uncompressed_results
	local compressed_results
	local curl_result_string
	local cached_log_file
	
	local status_code

	local opt
	local OPTARG
	local OPTIND
	
	while getopts ":d:T:" opt; do
		case $opt in
			d)
				cache_dir="$OPTARG"
				;;
			T)
				tmp_dir="$OPTARG"
				;;
			\?)
				echo "ERROR: $FUNCNAME: Unrecognized option: -$OPTARG" >&2
				return 2
				;;
			:)
				echo "ERROR: $FUNCNAME: Option -$OPTARG requires an argument" >&2
				return 2
				;;
		esac
	done
	
	# a temporary directory is required
	if [ -z "$tmp_dir" ]; then
		echo "ERROR: $FUNCNAME: no temporary directory specified" >&2
		return 2
	fi
	if [ ! -d "$tmp_dir" ]; then
		echo "ERROR: $FUNCNAME: directory does not exist: $tmp_dir" >&2
		return 2
	fi
	print_log_message -D "$FUNCNAME using temporary directory $tmp_dir"

	# a cache directory is required
	if [ -z "$cache_dir" ]; then
		echo "ERROR: $FUNCNAME: no cache directory specified" >&2
		return 2
	fi
	if [ ! -d "$cache_dir" ]; then
		echo "ERROR: $FUNCNAME: directory does not exist: $cache_dir" >&2
		return 2
	fi
	print_log_message -D "$FUNCNAME using cache directory $cache_dir"

	# determine the LOCATION
	shift $(( OPTIND - 1 ))
	if [ $# -ne 3 ]; then
		echo "ERROR: $FUNCNAME: wrong number of arguments: $# (3 required)" >&2
		return 2
	fi
	location="$1"
	timestamp="$2"
	diff_exit_code="$3"
	
	# check arguments
	if [ -z "$location" ] ; then
		echo "ERROR: $FUNCNAME: empty LOCATION argument" >&2
		return 2
	fi
	if [ -z "$timestamp" ]; then
		echo "ERROR: $FUNCNAME: empty TIMESTAMP argument" >&2
		return 2
	fi
	if [ -z "$diff_exit_code" ]; then
		echo "ERROR: $FUNCNAME: empty EXIT_CODE argument" >&2
		return 2
	fi
	print_log_message -D "$FUNCNAME using location $location"
	print_log_message -D "$FUNCNAME using timestamp $timestamp"
	print_log_message -D "$FUNCNAME using exit code $diff_exit_code"
	
	# check curl results
	curl_results_file="$tmp_dir/$( tmp_curl_results_filename )"
	if [ ! -f "$curl_results_file" ]; then
		print_log_message -E "$FUNCNAME: file not found: $curl_results_file"
		return 4
	fi
	
	# make sure the curl results file has two lines
	num_lines=$( /bin/cat "$curl_results_file" | /usr/bin/wc -l )
	if [ "$num_lines" -ne 2 ]; then
		print_log_message -E "$FUNCNAME unexpected number of lines in results file: $num_lines (2 expected)"
		return 4
	fi
	
	# assume the first line of the file contains the uncompressed results
	uncompressed_results=$( /usr/bin/head -n 1 "$curl_results_file" )
	status_code=$?
	if [ $status_code -ne 0 ]; then
		print_log_message -E "$FUNCNAME head failed ($status_code)"
		return 3
	fi
	
	# assume the second line of the file contains the compressed results
	compressed_results=$( /usr/bin/tail -n 1 "$curl_results_file" )
	status_code=$?
	if [ $status_code -ne 0 ]; then
		print_log_message -E "$FUNCNAME tail failed ($status_code)"
		return 3
	fi
	
	# process the compressed results
	read -r curl_exit_code curl_result_string <<< "$compressed_results"
	# add "_z" suffix to each parameter name in the result string
	curl_result_string=$( echo "$curl_result_string" | $_SED -e 's/\([^=]*\)=/\1_z=/g' )
	print_log_message -D "$FUNCNAME modified curl_result_string: $curl_result_string"
	
	# determine the log file
	cached_log_file=$( compression_log_file -d "$cache_dir" $location )
	status_code=$?
	if [ $status_code -ne 0 ]; then
		print_log_message -E "$FUNCNAME compression_log_file failed ($status_code) on location: $location"
		return 3
	fi

	# append the curl results to the log file
	echo -e "$timestamp $diff_exit_code $uncompressed_results $curl_exit_code $curl_result_string" \
		| /usr/bin/xargs printf "%s\t%s\t%s\t%s\t%s\t%s\n" >> "$cached_log_file"	
	status_code=$?
	if [ $status_code -ne 0 ]; then
		print_log_message -E "$FUNCNAME failed ($status_code) to append to log file: $cached_log_file"
		return 3
	fi
	
	echo "$cached_log_file"
}

append_compression_object () {

	local requestInstant
	local diff_exit_code
	
	local curl_exit_code
	local response_code
	local size_download
	local speed_download
	local time_namelookup
	local time_connect
	local time_appconnect
	local time_pretransfer
	local time_starttransfer
	local time_total
	
	local curl_exit_code_z
	local response_code_z
	local size_download_z
	local speed_download_z
	local time_namelookup_z
	local time_connect_z
	local time_appconnect_z
	local time_pretransfer_z
	local time_starttransfer_z
	local time_total_z
	
	requestInstant=$1
	diff_exit_code=$2
	
	curl_exit_code=$3
	eval "$4"
	
	curl_exit_code_z=$5
	eval "$6"
	
	/bin/cat <<- JSON_OBJECT
	  {
	    "requestInstant": "$requestInstant"
	    ,
	    "friendlyDate": "$( dateTime_canonical2friendlyDate $requestInstant )"
	    ,
	    "diffExitCode": "$diff_exit_code"
	    ,
	    "UncompressedResponse":
	    {
	      "curlExitCode": "$curl_exit_code"
	      ,
	      "responseCode": "$response_code"
	      ,
	      "sizeDownload": $size_download
	      ,
	      "speedDownload": $speed_download
	      ,
	      "timeTotal": $time_total
	    }
	    ,
	    "CompressedResponse":
	    {
	      "curlExitCode": "$curl_exit_code_z"
	      ,
	      "responseCode": "$response_code_z"
	      ,
	      "sizeDownload": $size_download_z
	      ,
	      "speedDownload": $speed_download_z
	      ,
	      "timeTotal": $time_total_z
	    }
	  }
JSON_OBJECT
}

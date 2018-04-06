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
# Help message
#######################################################################

display_help () {
/bin/cat <<- HELP_MSG
	Given the location of an HTTP resource, this script requests 
	the resource, records various details regarding the server
	response, and then logs the response data for future reference.
	
	$usage_string
	
	By default the script outputs a JSON array of 10 elements to 
	stdout. The elements in the array correspond to the last 10 
	lines in the response log file. See the OUTPUT section below 
	for details.
	
	The script is intended to be run as a cron job. Each run of
	the script appends a line to the log file and outputs a new 
	JSON file. In this way, the JSON file always contains the 
	latest information.
	
	Options:
	   -h      Display this help message
	   -q      Enable Quiet Mode; suppress normal output
	   -D      Enable DEBUG level logging
	   -W      Enable WARN level logging
	   -z      Enable HTTP Compression
	   -n      Specify the number of JSON objects to output
	   -d      Specify the directory to hold an output file

	Option -h is mutually exclusive of all other options.
	
	Option -q enables Quiet Mode. In this case, the log file is
	updated as usual but normal output is suppressed, that is, no 
	output is produced when the script is run in Quiet Mode.
	
	Options -D or -W enable DEBUG or WARN level logging, respectively.
	This temporarily overrides the LOG_LEVEL environment variable,
	whatever it may be.
		
	Option -z enables HTTP Compression by adding an Accept-Encoding 
	header to the HTTP request; that is, if option -z is enabled, the 
	client indicates its support for HTTP Compression in the request. 
	The server may or may not compress the response.
	
	Important! This implementation treats compressed and uncompressed 
	resources as two distinct resources.
	
	By default, the JSON array has 10 elements. Use the -n option to
	specify the desired number of objects in the JSON array. If the
	log file has fewer lines than the specified number of objects, the
	script outputs as many objects as possible.
	
	By default, the JSON array is output to stdout. Use the -d option
	to specify a directory in which to write the JSON file. Typically 
	the output directory is a web directory.
	
	When using the -d option, the actual filename is computed by the
	script. Specifically, the filename is the SHA-1 hash of the 
	location argument appended with "_response_stats_z.json" or 
	"_response_stats.json", depending on whether HTTP Compression is 
	enabled or not (resp.). Thus each resource gives rise to a unique 
	filename.
	
	Note: in Quiet Mode, both the -n and -d options are ignored.
	
	RESPONSE LOG FILE
	
	The timestamp log file is a flat text file where each row of the
	text file consists of the following tab-delimited fields:
	
	  currentTime
	  curlResultString
	
	The currentTime field contains a timestamp whose value format is 
	the canonical form of an ISO 8601 dateTime string:
	
	  YYYY-MM-DDThh:mm:ssZ
	
	where 'T' and 'Z' are literals.
	
	The curlResultString field encodes the results of a single 
	invocation of the curl command-line tool. The following values
	are encoded in the curlResultString value:
	
	  response_code
	  size_download
	  speed_download
	  time_namelookup
	  time_connect
	  time_appconnect
	  time_pretransfer
	  time_starttransfer
	  time_total
	
	See the curl documentation for details:
	https://curl.haxx.se/docs/manpage.html#-w
	
	OUTPUT
	
	Here is the simplest example of a JSON array with one element:
	
	  [
	    {
	      "requestInstant": "2018-02-18T19:16:56Z"
	      ,
	      "friendlyDate": "February 18, 2018"
	      ,
	      "curlExitCode": "0"
	      ,
	      "responseCode": "200"
	      ,
	      "sizeDownload": 50184424
	      ,
	      "speedDownload": 1478694.000
	      ,
	      "timeNamelookup": 0.266499
	      ,
	      "timeConnect": 0.425296
	      ,
	      "timeAppconnect": 0.000000
	      ,
	      "timePretransfer": 0.425344
	      ,
	      "timeStarttransfer": 0.461383
	      ,
	      "timeTotal": 33.938329
	    }
	  ]

	As you can see, an array element is a flat JSON object 
	consisting of response timings and other relevant data.
	
	The value of the requestInstant field indicates the actual time 
	instant the script was run. Its value has the canonical form of 
	an ISO 8601 dateTime string.
	
	The friendlyDate field indicates the date of the request. The
	time subfield is omitted from the friendlyDate.
	
	The curlExitCode field is the curl exit code. The semantics of 
	curl exit codes are documented on the curl web site:
	https://curl.haxx.se/docs/manpage.html#EXIT
	
	Note that the documentation for each exit code is individually
	addressable. For example, the link to the documentation for exit
	code 28 is:
	https://curl.haxx.se/docs/manpage.html#28
	
	The remaining fields are computed by curl. They were obtained by
	invoking the curl --write-out command-line option. The semantics
	of each --write-out parameter are documented on the curl web site:
	https://curl.haxx.se/docs/manpage.html#-w
	
	The output data are sufficient to construct a time-series plot. 
	The requestInstant field is intended to be the independent variable.
	Any of the numerical --write-out parameters are potential dependent 
	variables of interest. In particular, either of the speedDownload 
	or timeTotal fields give rise to interesting time-series plots.
	
	ENVIRONMENT
	
	The following environment variables are REQUIRED:
	
	$( printf "  %s\n" ${env_vars[*]} )
	
	The optional LOG_LEVEL variable defaults to LOG_LEVEL=3.
	
	The following directories will be used:
	
	$( printf "  %s\n" ${dir_paths[*]} )
	
	The following log file will be used:
	
	$( printf "  %s\n" $LOG_FILE )
	
	INSTALLATION
	
	At least the following source library files MUST be installed 
	in LIB_DIR:
	
	$( printf "  %s\n" ${lib_filenames[*]} )
	
	EXAMPLES
	
	  \$ url=https://md.incommon.org/InCommon/InCommon-metadata.xml
	  \$ ${0##*/} \$url
	  \$ ${0##*/} -z \$url    # HTTP Compression enabled
	  \$ ${0##*/} -n 1 \$url
	  
	The latter would produce a JSON array with one element, as shown
	in the OUTPUT section above.
HELP_MSG
}

#######################################################################
# Bootstrap
#######################################################################

script_name=${0##*/}  # equivalent to basename $0

# required environment variables
env_vars[1]="LIB_DIR"
env_vars[2]="CACHE_DIR"
env_vars[3]="TMPDIR"
env_vars[4]="LOG_FILE"

# check environment variables
for env_var in ${env_vars[*]}; do
	eval "env_var_val=\${$env_var}"
	if [ -z "$env_var_val" ]; then
		echo "ERROR: $script_name requires env var $env_var" >&2
		exit 2
	fi
done

# required directories
dir_paths[1]="$LIB_DIR"
dir_paths[2]="$CACHE_DIR"
dir_paths[3]="$TMPDIR"

# check required directories
for dir_path in ${dir_paths[*]}; do
	if [ ! -d "$dir_path" ]; then
		echo "ERROR: $script_name: directory does not exist: $dir_path" >&2
		exit 2
	fi
done

# check the log file
if [ ! -f "$LOG_FILE" ]; then
	echo "ERROR: $script_name: file does not exist: $LOG_FILE" >&2
	exit 2
fi

# default to INFO logging
[ -z "$LOG_LEVEL" ] && LOG_LEVEL=3

# library filenames
lib_filenames[1]=core_lib.bash
lib_filenames[2]=compatible_date.bash
lib_filenames[3]=http_tools.bash
lib_filenames[4]=http_cache_tools.bash
lib_filenames[5]=http_log_tools.bash
lib_filenames[6]=json_tools.bash

# check lib files
for lib_filename in ${lib_filenames[*]}; do
	lib_file="${LIB_DIR%%/}/$lib_filename"
	if [ ! -f "$lib_file" ]; then
		echo "ERROR: $script_name: file does not exist: $lib_file" >&2
		exit 2
	fi
done

#######################################################################
# Process command-line options and arguments
#######################################################################

usage_string="Usage: $script_name [-hqDWz] [-n NUM_OBJECTS] [-d OUT_DIR] LOCATION"

# defaults
help_mode=false; quiet_mode=false
numObjects=10

while getopts ":hqDWzn:d:" opt; do
	case $opt in
		h)
			help_mode=true
			;;
		q)
			quiet_mode=true
			;;
		D)
			LOG_LEVEL=4  # DEBUG
			;;
		W)
			LOG_LEVEL=2  # WARN
			;;
		z)
			compression_opt="$compression_opt -$opt"
			;;
		n)
			numObjects="$OPTARG"
			;;
		d)
			out_dir="$OPTARG"
			;;
		\?)
			echo "ERROR: $script_name: Unrecognized option: -$OPTARG" >&2
			exit 2
			;;
		:)
			echo "ERROR: $script_name: Option -$OPTARG requires an argument" >&2
			exit 2
			;;
	esac
done

if $help_mode; then
	display_help
	exit 0
fi

# check numObjects
if [ "$numObjects" -lt 1 ]; then
	echo "ERROR: $script_name: option -n arg must be positive integer: $numObjects" >&2
	exit 2
fi

# determine the location of the HTTP resource
shift $(( OPTIND - 1 ))
if [ $# -ne 1 ]; then
	echo "ERROR: $script_name: wrong number of arguments: $# (1 required)" >&2
	exit 2
fi
location="$1"

# check output directory
if [ -n "$out_dir" ] && [ ! -d "$out_dir" ]; then
	echo "ERROR: $script_name: output directory does not exist: $out_dir" >&2
	exit 2
fi

#######################################################################
# Initialization
#######################################################################

# source lib files
for lib_filename in ${lib_filenames[*]}; do
	[[ ! $lib_filename =~ \.bash$ ]] && continue
	lib_file="${LIB_DIR%%/}/$lib_filename"
	source "$lib_file"
	status_code=$?
	if [ $status_code -ne 0 ]; then
		echo "ERROR: $script_name failed ($status_code) to source lib file $lib_file" >&2
		exit 2
	fi
done

# create a temporary subdirectory
tmp_dir="${TMPDIR%%/}/${script_name%%.*}_$$"
/bin/mkdir "$tmp_dir"
status_code=$?
if [ $status_code -ne 0 ]; then
	echo "ERROR: $script_name failed ($status_code) to create tmp dir $tmp_dir" >&2
	exit 2
fi

# special log messages
initial_log_message="$script_name BEGIN"
final_log_message="$script_name END"

#######################################################################
#
# Main processing
#
# 1. Issue an HTTP GET request (with or without compression)
# 2. Update the corresponding response log file with the results
# 3. Print the tail of the response log file in JSON format
#
#######################################################################

print_log_message -I "$initial_log_message"

# compute currentTime (NOW)
currentTime=$( dateTime_now_canonical )
status_code=$?
if [ $status_code -ne 0 ]; then
	print_log_message -E "$script_name: dateTime_now_canonical failed ($status_code) to compute currentTime"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
fi
print_log_message -I "$script_name: currentTime: $currentTime"

#######################################################################
#
# Issue an HTTP GET request (with or without compression)
#
#######################################################################

# get the resource
http_get $compression_opt -d $CACHE_DIR -T "$tmp_dir" "$location" > /dev/null
http_status_code=$?

#######################################################################
#
# Update the corresponding response log file with the results
#
#######################################################################

# update the response log
response_log_file_path=$( update_response_log $compression_opt -d $CACHE_DIR -T "$tmp_dir" $location $currentTime )
status_code=$?
if [ $status_code -ne 0 ]; then
	print_log_message -E "$script_name update_response_log failed ($status_code) on location: $location"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
fi

# delayed error handling
if [ $http_status_code -ne 0 ]; then
	print_log_message -E "$script_name http_get failed ($http_status_code) on location: $location"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
fi

# short-circuit if necessary
$quiet_mode && clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 0

#######################################################################
#
# Print the tail of the response log file in JSON format
#
#######################################################################

# compute the desired tail of the response log file
print_log_message -I "$script_name using log file: $response_log_file_path"
tmp_log_file="$tmp_dir/response_log_tail.txt"
/usr/bin/tail -n $numObjects "$response_log_file_path" > "$tmp_log_file"

# print JSON to stdout
if [ -z "$out_dir" ]; then
	print_json_array "$tmp_log_file" append_response_object
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" $?
fi

# compute the output file path
out_file=$( opaque_file_path $compression_opt -e json -d "$out_dir" $location response_stats )
status_code=$?
if [ $status_code -ne 0 ]; then
	print_log_message -E "$script_name opaque_file_path failed ($status_code) to compute out_file"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
fi
print_log_message -I "$script_name using output file: $out_file"

# print JSON to the file
print_json_array "$tmp_log_file" append_response_object > "$out_file"
clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" $?

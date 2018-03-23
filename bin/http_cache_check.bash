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
	This script checks to see if a previously cached HTTP resource 
	is up-to-date. By default, the script performs a lightweight 
	network operation intended to be run as a cron job.
	
	$usage_string
	
	The script takes a single command-line argument, which is the 
	absolute URL of an HTTP resource. Assuming the resource is
	already cached, the script requests the resource via an HTTP 
	conditional (HEAD) request [RFC 7232]. The resource is up-to-date 
	if (and only if) the web server responds with 304 Not Modified.
	
	If the server supports HTTP conditional requests (as indicated 
	by an ETag in the response header), a successful response will 
	be either 304 or 200. If the server responds with 304, the 
	script exits normally with exit code 0. If the server responds 
	with 200 (instead of 304), the script logs a warning and exits 
	with code 1, indicating that the cache is dirty and in need of 
	update. See below for details about exit codes.
	
	Regardless of the exit status, this script produces no output 
	and, moreover, no cache write will occur under any circumstances.
	
	Options:
	   -h      Display this help message
	   -D      Enable DEBUG logging
	   -W      Enable WARN logging
	   -t      Enable "Try Hard Mode"
	   -z      Enable "Compressed Mode"

	Option -h is mutually exclusive of all other options.
	
	Options -D or -W enable DEBUG or WARN logging, respectively.
	This temporarily overrides the LOG_LEVEL environment variable.
	
	Option -t enables Try Hard Mode. If the server responds with 200,
	but HTTP conditional requests are not supported (indicated by the
	absence of an ETag in the response header), the script issues an
	ordinary HTTP GET request for the resource. It then compares the
	cached file with the file on the server byte-by-byte (using diff).
	The script exits normally with exit code 0 if (and only if) the 
	two files are identical.
	
	Compressed Mode (option -z) enables HTTP Compression by adding an 
	Accept-Encoding header to the request; that is, if option -z is 
	enabled, the client merely indicates its support for HTTP Compression 
	in the request. The server will indicate its support for HTTP
	Compression (or not) in the response header.
	
	Important! This implementation treats compressed and uncompressed 
	requests for the same resource as two distinct cachable resources.
	
	EXIT CODES
	
	The following exit codes are emitted by this script:
	
	  0: Cache is up-to-date
	  1: Cache is NOT up-to-date
	  2: Initialization failure
	  3: Unexpected failure
	  4: HTTP conditional requests not supported (no ETag)
	  5: Unexpected HTTP response (neither 304 nor 200)
	
	To work around exit code 4, enable Try Hard Mode (option -t). In 
	any case, if the resource was not previously cached at the time 
	the script was called, the exit code is guaranteed to be nonzero.
	
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
	
	For some HTTP location:
	
	  \$ cget.bash \$url              # prime the cache
	  \$ ${0##*/} \$url
	  \$ echo \$?
	  0                             # the cache is up-to-date
	
	When the resource on the server changes:
	
	  \$ ${0##*/} \$url
	  \$ echo \$?
	  1                             # the cache is NOT up-to-date
	  \$ cget.bash \$url              # update the cache
	  \$ ${0##*/} \$url
	  \$ echo \$?
	  0                             # the cache is up-to-date
	
	For some other HTTP location:
	
	  \$ cget.bash \$url2             # prime the cache
	  \$ ${0##*/} \$url2
	  \$ echo \$?
	  4                             # HTTP conditional requests not supported
	  \$ ${0##*/} -t \$url2
	  \$ echo \$?
	  0                             # the cache is up-to-date
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
if [ -z "$LOG_LEVEL" ]; then
	LOG_LEVEL=3
fi

# library filenames
lib_filenames[1]=core_lib.bash
lib_filenames[2]=http_tools.bash
lib_filenames[3]=http_cache_tools.bash

# check lib files
for lib_filename in ${lib_filenames[*]}; do
	lib_file="$LIB_DIR/$lib_filename"
	if [ ! -f "$lib_file" ]; then
		echo "ERROR: $script_name: file does not exist: $lib_file" >&2
		exit 2
	fi
done

#######################################################################
# Process command-line options and arguments
#######################################################################

usage_string="Usage: $script_name [-hDWtz] HTTP_LOCATION"

# defaults
help_mode=false; try_hard_mode=false

while getopts ":hDWtz" opt; do
	case $opt in
		h)
			help_mode=true
			;;
		D)
			LOG_LEVEL=4  # DEBUG
			;;
		W)
			LOG_LEVEL=2  # WARN
			;;
		t)
			try_hard_mode=true
			;;
		z)
			compression_opt="$compression_opt -$opt"
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

# check the number of remaining arguments
shift $(( OPTIND - 1 ))
if [ $# -ne 1 ]; then
	echo "ERROR: $script_name: wrong number of arguments: $# (1 required)" >&2
	exit 2
fi
location="$1"

#######################################################################
# Initialization
#######################################################################

# source lib files
for lib_filename in ${lib_filenames[*]}; do
	lib_file="$LIB_DIR/$lib_filename"
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
# 1. issue a conditional HEAD request
# 2. compute the HTTP response code
# 3. process the response code
#
#######################################################################

print_log_message -I "$initial_log_message"

# issue a conditional HEAD request
http_conditional_head $compression_opt -d "$CACHE_DIR" -T "$tmp_dir" "$location" > /dev/null
status_code=$?
if [ $status_code -ne 0 ]; then
	print_log_message -E "$script_name: http_conditional_head failed ($status_code)"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
fi

# sanity check
tmp_header_file="$tmp_dir/$( tmp_response_headers_filename )"
if [ ! -f "$tmp_header_file" ]; then
	print_log_message -E "$script_name unable to find header file $tmp_header_file"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
fi

# compute the HTTP response code
response_code=$( get_response_code "$tmp_header_file" )
status_code=$?
if [ $status_code -ne 0 ]; then
	print_log_message -E "$script_name: get_response_code failed ($status_code)"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
fi

# process terminal conditions
if [ "$response_code" = 304 ]; then
	print_log_message -I "$script_name: cache is up-to-date for resource: $location"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 0
elif [ "$response_code" = 200 ]; then
	header_value=$( get_header_value "$tmp_header_file" ETag )
	if [ -n "$header_value" ]; then
		print_log_message -W "$script_name: cache is NOT up-to-date for resource: $location"
		clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 1
	elif ! $try_hard_mode; then
		print_log_message -E "$script_name: HTTP conditional request not supported for resource: $location"
		clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 4
	fi
else
	print_log_message -E "$script_name: unexpected HTTP response ($response_code) for resource: $location"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 5
fi

# there's only one way to get through the above if-block:
# HTTP conditional requests are not supported but try_hard_mode is enabled
# in which case, prepare to try harder by comparing files byte-by-byte
print_log_message -I "$script_name: HTTP conditional request not supported for resource: $location"

# determine the cached file path
cache_file_path=$( cache_response_body_file $compression_opt -d "$CACHE_DIR" "$location" )
status_code=$?
if [ $status_code -ne 0 ]; then
	print_log_message -E "$script_name: cache_response_body_file failed ($status_code) on location $location"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
fi
print_log_message -I "$script_name using cached file $cache_file_path"

# GET the resource, do not write to cache
print_log_message -D "$script_name fetching HTTP resource $location"
http_get $compression_opt -x -d "$CACHE_DIR" -T "$tmp_dir" "$location" > /dev/null
status_code=$?
if [ $status_code -ne 0 ]; then
	print_log_message -E "$script_name: http_get failed ($status_code) on location $location"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
fi

# sanity check
http_file_path="$tmp_dir/$( tmp_response_body_filename )"
if [ ! -f "$http_file_path" ]; then
	print_log_message -E "$script_name unable to find response file $http_file_path"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
fi

# compute the diff and exit
/usr/bin/diff -q "$cache_file_path" "$http_file_path" > /dev/null
clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" $?

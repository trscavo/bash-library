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
#
# Well-known temporary file names
#
#######################################################################
tmp_response_headers_filename () {
	echo http_request_curl_headers
}
tmp_response_body_filename () {
	echo http_request_curl_content
}
tmp_curl_results_filename () {
	echo http_request_curl_results
}

#######################################################################
#
# This function computes the absolute path to the cached request
# headers for the given CACHE_DIR and HTTP location.
#
# Usage: cache_request_headers_file [-z] -d CACHE_DIR HTTP_LOCATION
#
# Dependencies:
#   core_lib.bash
#   http_tools.bash
#
#######################################################################
cache_request_headers_file () {
	opaque_file_path "$@" request_headers
}

#######################################################################
#
# This function computes the absolute path to the cached response
# headers for the given CACHE_DIR and HTTP location.
#
# Usage: cache_response_headers_file [-z] -d CACHE_DIR HTTP_LOCATION
#
# Dependencies:
#   core_lib.bash
#   http_tools.bash
#
#######################################################################
cache_response_headers_file () {
	opaque_file_path "$@" response_headers
}

#######################################################################
#
# This function computes the absolute path to the cached response
# body for the given CACHE_DIR and HTTP location.
#
# Usage: cache_response_body_file [-z] -d CACHE_DIR HTTP_LOCATION
#
# Dependencies:
#   core_lib.bash
#   http_tools.bash
#
#######################################################################
cache_response_body_file () {
	opaque_file_path "$@" response_body
}

#######################################################################
#
# This abstract function issues an HTTP request for an arbitrary
# web resource.
#
# Usage: http_request [-z] -d CACHE_DIR -T TMP_DIR HTTP_LOCATION
#
# This function requires two option arguments (CACHE_DIR and TMP_DIR)
# and a single command-line argument (HTTP_LOCATION). The rest of the
# command line is optional.
#
# The type of request issued by this abstract function is intentionally
# unspecified. Use one of the following concrete functions to issue
# an actual HTTP request:
#
#   http_get
#   http_conditional_get
#   http_head
#   http_conditional_head
#
# All of the above functions support the following common set of options:
#
#   -z   enable HTTP Compression
#   -d   the cache directory (REQUIRED)
#   -T   a temporary directory (REQUIRED)
#
# Option -z adds an Accept-Encoding header to the request; that is, if
# option -z is enabled, the client merely indicates its support for HTTP 
# Compression in the request. The server may or may not compress the 
# response, and in fact, this implementation does not check to see if
# the response is actually compressed by the server. The HTTP response
# header will indicate if this is so.
#
# Important! This implementation treats compressed and uncompressed 
# requests for the same resource as two distinct resources. For example, 
# consider the following pair of function calls:
#
#   http_request ... $url
#   http_request -z ... $url
#
# The above requests result in two distinct cached resources, the content
# of which are identical. Assuming the server actually compressed the
# response of the latter, the headers will be different, however. In 
# particular, the Content-Length values will be different in each case. 
# Most importantly, the compressed response header will include a 
# Content-Encoding header (whose value is invariably "gzip").
#
# TEMPORARY OUTPUT
#
# The output of the curl command-line tool is stored in the following 
# temporary files:
#
#   $TMP_DIR/http_request_curl_headers
#   $TMP_DIR/http_request_curl_content
#   $TMP_DIR/http_request_curl_results
#
# The latter file contains one or more lines with two tab-separated
# fields. The number of lines in the file depends on how many times
# the function is called (one line per call). The first field on
# each line is the curl exit code. The second field is the output
# of the curl --write-out command-line option. The output string
# records a number of name-value pairs with info regarding the
# HTTP transaction:
# 
#   response_code
#   size_download
#   speed_download
#   time_namelookup
#   time_connect
#   time_appconnect
#   time_pretransfer
#   time_starttransfer
#   time_total
#
# For details about curl exit codes or the curl --write-out command
# option, visit:
#
#   https://curl.haxx.se/docs/manpage.html#EXIT
#   https://curl.haxx.se/docs/manpage.html#-w
#
# respectively. Note that the documentation for each exit code is
# individually addressable. For example, the documentation for exit
# code 28 is:
#
#   https://curl.haxx.se/docs/manpage.html#28
#
# DEPENDENCIES
#
# This function requires the following library files:
#
# core_lib.sh
# http_tools.bash
#
# Each library file must be sourced BEFORE calling this function.
#
# RETURN CODES
#
#    0: success
#    1: Quiet Failure Mode:
#       option -F but no fresh resource available
#       option -C but no up-to-date cache resource available
#    2: initialization failure
#    3: unspecified failure
#    4: cache file initialization failed
#    5: curl failed
#    6: call to HTTP helper function failed
#    7: content length check failed
#    8: cache write failed
#    9: unexpected HTTP response
#
#######################################################################
http_request () {

	# external dependencies
	if [ "$(type -t print_log_message)" != function ]; then
		echo "ERROR: $FUNCNAME: function print_log_message not found" >&2
		return 2
	fi
	if [ "$(type -t get_response_code)" != function ]; then
		echo "ERROR: $FUNCNAME: function get_response_code not found" >&2
		return 2
	fi

	local script_version="1.0"
	local user_agent_string="HTTP Client $script_version"
	
	local verbose_mode=false
	local head_request_mode=false
	local conditional_request_mode=false
	local force_refresh_mode=false
	local check_cache_mode=false
	local do_not_cache_mode=false
	
	local compressed_mode=false
	local local_opts
	local cache_dir
	local tmp_dir
	local location
	local cached_request_file
	local cached_header_file
	local cached_content_file
	local adjective
	local resource_is_cached
	local tmp_header_file
	local tmp_content_file
	local tmp_stderr_file
	local tmp_results_file
	local curl_opts
	local header_value
	local curl_output
	local response_code
	local actual_content_length
	local declared_content_length

	local exit_code
	local return_code

	###################################################################
	#
	# This function does not enforce constraints on the command-line
	# options. Use the wrapper functions listed above.
	#
	# Undocumented options:
	#
	#   -x  enable do-not-cache mode
	#   -v  verbose output mode
	#   -I  issue HEAD instead of GET
	#   -c  add HTTP Conditional GET header
	#   -F  enable force refresh mode
	#   -C  enable check cache mode
	#
	# Options -F and -C and -c are mutually exclusive (last one wins).
	# Option -I may be used by itself or with options -z or -c only.
	# Options -I and -F and -C are mutually exclusive.
	# Options -I and -C and -x are mutually exclusive.
	# Option -v requires the presence of option -I.
	#
	###################################################################

	local opt
	local OPTARG
	local OPTIND
	
	while getopts ":vIFCcxzd:T:" opt; do
		case $opt in
			v)
				verbose_mode=true
				;;
			I)
				head_request_mode=true
				;;
			F)
				conditional_request_mode=true
				force_refresh_mode=true
				check_cache_mode=false
				;;
			C)
				conditional_request_mode=true
				force_refresh_mode=false
				check_cache_mode=true
				;;
			c)
				conditional_request_mode=true
				force_refresh_mode=false
				check_cache_mode=false
				;;
			x)
				do_not_cache_mode=true
				;;
			z)
				compressed_mode=true
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

	# determine the URL location
	shift $(( OPTIND - 1 ))
	if [ $# -ne 1 ]; then
		echo "ERROR: $FUNCNAME: wrong number of arguments: $# (1 required)" >&2
		return 2
	fi
	location="$1"
	if [ -z "$location" ] ; then
		echo "ERROR: $FUNCNAME: empty URL argument" >&2
		return 2
	fi
	print_log_message -D "$FUNCNAME using location $location"
	
	###################################################################
	#
	# Determine the cache files (which may or may not exist at this point)
	#
	# This cache implementation uses separate files for the header and
	# body content. It also uses a separate pair of files if option -z
	# (i.e., HTTP Compression) is specified on the command line.
	#
	###################################################################

	cached_request_file="$( cache_request_headers_file $local_opts $location )"
	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		print_log_message -E "$FUNCNAME: cache_request_headers_file failed ($exit_code) to compute cached_request_file"
		return 4
	fi
	cached_header_file="$( cache_response_headers_file $local_opts $location )"
	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		print_log_message -E "$FUNCNAME: cache_response_headers_file failed ($exit_code) to compute cached_header_file"
		return 4
	fi
	cached_content_file="$( cache_response_body_file $local_opts $location )"
	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		print_log_message -E "$FUNCNAME: cache_response_body_file failed ($exit_code) to compute cached_content_file"
		return 4
	fi
	$compressed_mode && adjective="compressed "

	print_log_message -D "$FUNCNAME using cached request file: $cached_request_file"
	print_log_message -D "$FUNCNAME using cached header file: $cached_header_file"
	print_log_message -D "$FUNCNAME using cached content file: $cached_content_file"

	# check if the resource is cached
	if [ -f "$cached_header_file" ] && [ -f "$cached_content_file" ]; then
			
		resource_is_cached=true
	else
		# ensure cache integrity
		/bin/rm -f "$cached_header_file" "$cached_content_file" "$cached_request_file" >&2
		
		# quiet failure mode
		if $check_cache_mode; then
			print_log_message -W "$FUNCNAME: ${adjective}resource not cached: $location"
			return 1
		fi
		
		resource_is_cached=false
	fi

	###################################################################
	#
	# Initialization
	#
	###################################################################

	# The tmp_header_file and tmp_content_file are replaced each time 
	# the function is called. OTOH, the tmp_results_file is accumulated 
	# each time the function is called (one line per call).

	tmp_header_file="$tmp_dir/$( tmp_response_headers_filename )"
	tmp_content_file="$tmp_dir/$( tmp_response_body_filename )"
	tmp_results_file="$tmp_dir/$( tmp_curl_results_filename )"

	print_log_message -D "$FUNCNAME using temp header file: $tmp_header_file"
	print_log_message -D "$FUNCNAME using temp content file: $tmp_content_file"
	print_log_message -D "$FUNCNAME using temp results file: $tmp_results_file"

	# for internal use only
	tmp_stderr_file="$tmp_dir/${FUNCNAME}_curl_stderr"
	print_log_message -D "$FUNCNAME using temp stderr file: $tmp_stderr_file"

	###################################################################
	#
	# Issue a GET request for the web resource
	# If option -I was used, issue a HEAD request instead
	#
	###################################################################

	# init curl command-line options
#	if $verbose_mode; then
#		curl_opts="--verbose --progress-bar"
#	else
#		curl_opts="--silent --show-error"
#	fi
	curl_opts="--silent --show-error --verbose"
	curl_opts="${curl_opts} --user-agent '${user_agent_string}'"
	
	# set curl --compressed option if necessary
	$compressed_mode && curl_opts="${curl_opts} --compressed"

	# always capture the header in a file
	curl_opts="${curl_opts} --dump-header '${tmp_header_file}'"
	
	# capture the output iff the client issues a GET request
	if $head_request_mode; then
		print_log_message -I "$FUNCNAME issuing HEAD request for ${adjective}resource: $location"
		curl_opts="${curl_opts} --head"
		curl_opts="${curl_opts} --output '/dev/null'"
	else
		print_log_message -I "$FUNCNAME issuing GET request for ${adjective}resource: $location"
		curl_opts="${curl_opts} --output '${tmp_content_file}'"
	fi

	# always capture stderr in a file
	curl_opts="${curl_opts} --stderr '${tmp_stderr_file}'"

	# always write out a string of data
	curl_opts="${curl_opts} --write-out 'response_code=%{response_code};size_download=%{size_download};speed_download=%{speed_download};time_namelookup=%{time_namelookup};time_connect=%{time_connect};time_appconnect=%{time_appconnect};time_pretransfer=%{time_pretransfer};time_starttransfer=%{time_starttransfer};time_total=%{time_total}'"
	
	# Optionally issue a conditional request.
	# Since "A recipient MUST ignore If-Modified-Since if the 
	# request contains an If-None-Match header field," the
	# latter takes precedence in the following code block.
	if $conditional_request_mode && [ -f "$cached_header_file" ]; then
		header_value=$( get_header_value "$cached_header_file" 'ETag' )
		return_code=$?
		if [ $return_code -ne 0 ]; then
			print_log_message -E "$FUNCNAME: get_header_value (return code: $return_code)"
			return 6
		fi
		if [ -n "$header_value" ]; then
			curl_opts="${curl_opts} --header 'If-None-Match: $header_value'"
		else
			header_value=$( get_header_value "$cached_header_file" 'Last-Modified' )
			return_code=$?
			if [ $return_code -ne 0 ]; then
				print_log_message -E "$FUNCNAME: get_header_value (return code: $return_code)"
				return 6
			fi
			if [ -n "$header_value" ]; then
				curl_opts="${curl_opts} --header 'If-Modified-Since: $header_value'"
			fi
		fi
	fi

	# invoke curl
	print_log_message -D "$FUNCNAME invoking curl with options: $curl_opts"
	curl_output=$( echo "$curl_opts" | /usr/bin/xargs /usr/bin/curl $location )
	exit_code=$?
	
	# always capture the curl results in a temporary file
	echo "$exit_code $curl_output" \
		| /usr/bin/xargs printf "%s\t%s\n" >> "$tmp_results_file"
	
	if [ $exit_code -ne 0 ]; then
		print_log_message -E "$FUNCNAME: curl failed (exit code: $exit_code)"
		return 5
	fi

	###################################################################
	#
	# Response processing
	#
	###################################################################

	# sanity check
	if [ ! -f "$tmp_header_file" ]; then
		print_log_message -E "$FUNCNAME unable to find header file $tmp_header_file"
		return 3
	fi

	# compute the HTTP response code
	response_code=$( get_response_code "$tmp_header_file" )
	return_code=$?
	if [ $return_code -ne 0 ]; then
		print_log_message -E "$FUNCNAME: get_response_code failed (return code: $return_code)"
		return 6
	fi
	print_log_message -I "$FUNCNAME received response code: $response_code"

	# short-circuit if a HEAD request was issued
	if $head_request_mode; then
		if $verbose_mode; then
			# output request and response headers (curl --verbose output)
			/bin/cat "$tmp_stderr_file"
		else
			# output the response headers only
			/bin/cat "$tmp_header_file"
		fi
		exit_code=$?
		if [ $exit_code -ne 0 ]; then
			print_log_message -E "$FUNCNAME unable to cat output ($exit_code)"
			return 3
		fi
		return 0
	fi
	
	###################################################################
	#
	# Update the cache
	#
	# Open questions:
	#   What if the response contains a "no-store" cache directive?
	#
	###################################################################

	if [ "$response_code" = "200" ]; then

		# quiet failure mode
		if $check_cache_mode; then
			print_log_message -W "$FUNCNAME: ${adjective}resource is not up-to-date: $location"
			return 1
		fi
		
		# compute the length of the downloaded content
		actual_content_length=$( /bin/cat "$tmp_content_file" \
			| /usr/bin/wc -c \
			| $_SED -e 's/^[ ]*//' -e 's/[ ]*$//'
		)
		return_code=$?
		if [ $return_code -ne 0 ]; then
			print_log_message -E "$FUNCNAME: length calculation failed (return code: $return_code)"
			return 3
		fi
		print_log_message -D "$FUNCNAME downloaded ${actual_content_length} bytes"

		# this sanity check is applied only if compression was NOT used
		if ! $compressed_mode; then
			declared_content_length=$( get_header_value "$tmp_header_file" 'Content-Length' )
			return_code=$?
			if [ $return_code -ne 0 ]; then
				print_log_message -E "$FUNCNAME: get_header_value failed (return code: $return_code)"
				return 6
			fi
			if [ -n "$declared_content_length" ]; then
				if [ "$declared_content_length" != "$actual_content_length" ]; then
					print_log_message -E "$FUNCNAME failed content length check"
					return 7
				fi
			else
				print_log_message -W "$FUNCNAME: Content-Length response header missing"
			fi
		fi
		
		# short-circuit if do_not_cache_mode is enabled
		if $do_not_cache_mode; then
			/bin/cat "$tmp_content_file"
			exit_code=$?
			if [ $exit_code -ne 0 ]; then
				print_log_message -E "$FUNCNAME unable to cat output ($exit_code)"
				return 3
			fi
			return 0
		fi

		if $resource_is_cached; then
			print_log_message -D "$FUNCNAME refreshing cache files"
		else
			print_log_message -D "$FUNCNAME initializing cache files"
		fi

		# update the cache; maintain cache integrity at all times
		print_log_message -I "$FUNCNAME writing cached header file: $cached_header_file"
		/bin/cp -f "$tmp_header_file" "$cached_header_file" >&2
		exit_code=$?
		if [ $exit_code -ne 0 ]; then
			/bin/rm -f "$cached_header_file" "$cached_content_file" "$cached_request_file" >&2
			print_log_message -E "$FUNCNAME failed copy ($exit_code) to file $cached_header_file"
			return 8
		fi
		print_log_message -I "$FUNCNAME writing cached content file: $cached_content_file"
		/bin/cp -f "$tmp_content_file" "$cached_content_file" >&2
		exit_code=$?
		if [ $exit_code -ne 0 ]; then
			/bin/rm -f "$cached_header_file" "$cached_content_file" "$cached_request_file" >&2
			print_log_message -E "$FUNCNAME failed copy ($exit_code) to file $cached_content_file"
			return 8
		fi
		
		# write the request headers to cache
		print_log_message -I "$FUNCNAME writing cached request file: $cached_request_file"
		/bin/cat "$tmp_stderr_file" \
			| $_GREP '> [^[:space:]]' \
			| $_SED -e 's/^> \(.*\)$/\1/' > "$cached_request_file"
		exit_code=$?
		if [ $exit_code -ne 0 ]; then
			print_log_message -W "$FUNCNAME failed copy ($exit_code) to file $cached_request_file"
		fi

	elif [ "$response_code" = "304" ]; then
	
		# quiet failure mode
		if $force_refresh_mode; then
			print_log_message -W "$FUNCNAME: fresh resource not available: $location"
			return 1
		fi
		
		print_log_message -D "$FUNCNAME downloaded 0 bytes (cache is up-to-date)"
	else
		print_log_message -E "$FUNCNAME failed with HTTP response code $response_code"
		return 9
	fi

	###################################################################
	#
	# Return the cached resource
	# (since the cache is now up-to-date)
	#
	###################################################################

	print_log_message -I "$FUNCNAME reading cached content file: $cached_content_file"
	/bin/cat "$cached_content_file"
	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		print_log_message -E "$FUNCNAME unable to cat output ($exit_code)"
		return 3
	fi
	return 0
}

#######################################################################
#
# This function issues an ordinary GET request for an HTTP resource.
#
# Usage: http_get [-xz] -d CACHE_DIR -T TMP_DIR HTTP_LOCATION
#
# This function requires two option arguments (CACHE_DIR and TMP_DIR)
# and a single command-line argument (HTTP_LOCATION). The rest of the
# command line is optional.
#
# If the server responds with 200, the function returns the response
# body and caches the response (unless option -x is specified on the
# command line).
#
# This function relies on http_request(). Refer to the latter for
# additional documentation.
#
# Options:
#   -x   enable do-not-cache mode
#   -z   enable HTTP Compression
#   -d   the cache directory (REQUIRED)
#   -T   a temporary directory (REQUIRED)
#
# Option -x enables do-not-cache mode. In that case, nothing is written
# to cache. Basically 'http_get -x' issues an ordinary HTTP GET request.
#
# Option -z enables HTTP Compression via the curl --compressed option.
#
# Dependencies:
#   core_lib.bash
#   http_tools.bash
#
#######################################################################
http_get () {
	# options -x and -z is optional
	# options -d and -T are required
	# no other options are allowed
	
	# external dependencies
	if [ "$(type -t print_log_message)" != function ]; then
		echo "ERROR: $FUNCNAME: function print_log_message not found" >&2
		return 2
	fi

	local opt
	local OPTARG
	local OPTIND
	
	while getopts ":xzd:T:" opt; do
		case $opt in
			x)
				print_log_message -I "$FUNCNAME: do-not-cache mode enabled"
				;;
			z)
				print_log_message -I "$FUNCNAME: compressed mode enabled"
				;;
			d)
				print_log_message -D "$FUNCNAME: CACHE_DIR: $OPTARG"
				;;
			T)
				print_log_message -D "$FUNCNAME: TMP_DIR: $OPTARG"
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
	
	http_request "$@"
}

#######################################################################
#
# This function issues an HTTP Conditional GET request for an HTTP
# resource.
#
# Usage: http_conditional_get [-xz] [-FC] -d CACHE_DIR -T TMP_DIR HTTP_LOCATION
#
# This function requires two option arguments (CACHE_DIR and TMP_DIR)
# and a single command-line argument (HTTP_LOCATION). The rest of the
# command line is optional.
#
# If the resource is cached, the function requests the resource
# using HTTP Conditional GET [RFC 7232], otherwise an ordinary GET
# request is issued. In either case, if the server responds with
# 200, the function returns the response body and caches the response
# (unless option -x is specified on the command line). On the other
# hand, if the server responds with 304, the cached response body is
# returned instead.
#
# This function relies on http_request(). Refer to the latter for
# more general documentation.
#
# Options:
#   -x   enable do-not-cache mode
#   -z   enable HTTP Compression
#   -F   enable force refresh mode
#   -C   enable check cache mode
#   -d   the cache directory (REQUIRED)
#   -T   a temporary directory (REQUIRED)
#
# Option -x enables do-not-cache mode. In that case, nothing is written
# to cache.
#
# Option -z enables HTTP Compression via the curl --compressed option.
# It may be used with any other option.
#
# Options -F and -C are mutually exclusive. If more than one of these
# options appears on the command line, the last option listed wins.
# 
# Option -F forces the output of fresh content. That is, if option -F
# is enabled and the server responds with 200, the function returns
# normally. In that case, a cache write will occur (unless option -x
# is specified). On the other hand, if option -F is enabled and the
# server responds with 304, the function quietly returns with a nonzero
# return code. See the section Quiet Failure Mode below for details.
#
# If option -C is enabled but the resource is not cached, the function
# quietly returns with a nonzero return code. Otherwise an HTTP
# Conditional GET request is issued to determine if the cache content
# is stale. If the cache is not up-to-date, the function quietly
# returns with a nonzero return code (i.e., Quiet Failure Mode).
#
# If options -C and -x are used together, the latter is ignored
# (since the former does not write to cache).
#
# QUIET FAILURE MODE
#
# Options -F and -C exhibit Quiet Failure Mode. If one of these 
# options is enabled, and a special error condition is detected, the
# function logs a warning message and quietly returns error code 1.
#
# The error conditions that trigger Quiet Failure Mode are based on the
# following requirements:
#
#   Option -F: the HTTP response MUST be 200
#   Option -C: the HTTP response MUST be 304
#
# If one of the above requirements is NOT met, the function quietly
# returns error code 1.
#
# Quiet Failure Mode guarantees the following:
#
#   Option -F: the cache has been updated (i.e., a cache write occurred)
#   Option -C: the resource is cached and the cache is up-to-date
#
# If options -F and -x are used together, no cache write will occur.
# Option -C does not write to cache in any case.
#
# Dependencies:
#   core_lib.bash
#   http_tools.bash
#
#######################################################################
http_conditional_get () {
	# options -x and -z and -C and -F are optional
	# options -F and -C are mutually exclusive
	# options -x and -C are mutually exclusive (but not enforced)
	# options -d and -T are required
	# no other options are allowed
	
	# external dependencies
	if [ "$(type -t print_log_message)" != function ]; then
		echo "ERROR: $FUNCNAME: function print_log_message not found" >&2
		return 2
	fi

	local optionEnabled=false
	
	local opt
	local OPTARG
	local OPTIND
	
	while getopts ":xzFCd:T:" opt; do
		case $opt in
			x)
				print_log_message -I "$FUNCNAME: do-not-cache mode enabled"
				;;
			z)
				print_log_message -I "$FUNCNAME: compressed mode enabled"
				;;
			F)
				if $optionEnabled; then
					print_log_message -E "$FUNCNAME: options -F and -C are mutually exclusive"
					return 2
				fi
				optionEnabled=true
				print_log_message -I "$FUNCNAME: force refresh mode enabled"
				;;
			C)
				if $optionEnabled; then
					print_log_message -E "$FUNCNAME: options -F and -C are mutually exclusive"
					return 2
				fi
				optionEnabled=true
				print_log_message -I "$FUNCNAME: check cache mode enabled"
				;;
			d)
				print_log_message -D "$FUNCNAME: CACHE_DIR: $OPTARG"
				;;
			T)
				print_log_message -D "$FUNCNAME: TMP_DIR: $OPTARG"
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
	
	# Default option -c enables HTTP Conditional GET
	# Options -F or -C override option -c since the
	# last option (-F, -C, or -c) on the command line wins
	http_request -c "$@"
}

#######################################################################
#
# This function issues an HTTP Conditional HEAD request for an
# HTTP resource.
#
# Usage: http_conditional_head [-z] -d CACHE_DIR -T TMP_DIR HTTP_LOCATION
#
# This function requires two option arguments (CACHE_DIR and TMP_DIR)
# and a single command-line argument (HTTP_LOCATION). The rest of the
# command line is optional.
#
# This function does not write to cache.
#
# This function relies on http_request(). Refer to the latter for
# additional documentation.
#
# Options:
#   -v   enable verbose mode
#   -z   enable HTTP Compression
#   -d   the cache directory (REQUIRED)
#   -T   a temporary directory (REQUIRED)
#
# Option -v invokes the curl --verbose option.
# Option -z enables HTTP Compression via the curl --compressed option.
#
# Dependencies:
#   core_lib.bash
#   http_tools.bash
#
#######################################################################
http_conditional_head () {
	# options -v and -z are optional
	# options -d and -T are required
	# no other options are allowed
	
	# external dependencies
	if [ "$(type -t print_log_message)" != function ]; then
		echo "ERROR: $FUNCNAME: function print_log_message not found" >&2
		return 2
	fi

	local opt
	local OPTARG
	local OPTIND
	
	while getopts ":vzd:T:" opt; do
		case $opt in
			v)
				print_log_message -I "$FUNCNAME: verbose mode enabled"
				;;
			z)
				print_log_message -I "$FUNCNAME: compressed mode enabled"
				;;
			d)
				print_log_message -D "$FUNCNAME: CACHE_DIR: $OPTARG"
				;;
			T)
				print_log_message -D "$FUNCNAME: TMP_DIR: $OPTARG"
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
	
	http_request -cI "$@"
}

#######################################################################
#
# This function issues a HEAD request for an HTTP resource.
#
# Usage: http_head [-z] -d CACHE_DIR -T TMP_DIR HTTP_LOCATION
#
# This function requires two option arguments (CACHE_DIR and TMP_DIR)
# and a single command-line argument (HTTP_LOCATION). The rest of the
# command line is optional.
#
# This function does not write to nor read from cache.
#
# This function relies on http_request(). Refer to the latter for
# additional documentation.
#
# Options:
#   -v   enable verbose mode
#   -z   enable HTTP Compression
#   -d   the cache directory (REQUIRED)
#   -T   a temporary directory (REQUIRED)
#
# Option -v invokes the curl --verbose option.
# Option -z enables HTTP Compression via the curl --compressed option.
#
# Dependencies:
#   core_lib.bash
#   http_tools.bash
#
#######################################################################
http_head () {
	# option -v and -z are optional
	# options -d and -T are required
	# no other options are allowed
	
	# external dependencies
	if [ "$(type -t print_log_message)" != function ]; then
		echo "ERROR: $FUNCNAME: function print_log_message not found" >&2
		return 2
	fi

	local opt
	local OPTARG
	local OPTIND
	
	while getopts ":vzd:T:" opt; do
		case $opt in
			v)
				print_log_message -I "$FUNCNAME: verbose mode enabled"
				;;
			z)
				print_log_message -I "$FUNCNAME: compressed mode enabled"
				;;
			d)
				print_log_message -D "$FUNCNAME: CACHE_DIR: $OPTARG"
				;;
			T)
				print_log_message -D "$FUNCNAME: TMP_DIR: $OPTARG"
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
	
	http_request -I "$@"
}

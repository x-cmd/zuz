#!/bin/bash

set -e

PARALLELISM=8

repeated_bytes() {
	n="$1"
	dd if=/dev/zero bs="$n" count=1 2>/dev/null | tr '\0' 'a'
}
export -f repeated_bytes

trial_bulkdeflate() {
	uncompressed_size="$1"
	echo "bulk_deflate,$(./bulk_deflate "$uncompressed_size")"
}
export -f trial_bulkdeflate

trial_zlib() {
	uncompressed_size="$1"
	compressed_size="$(repeated_bytes "$uncompressed_size" | ./zlib_deflate | wc -c)"
	echo "zlib,$uncompressed_size,$compressed_size"
}
export -f trial_zlib

trial_infozip() {
	uncompressed_size="$1"
	tmp_filename="$(mktemp -u --suffix=.zip)"
	repeated_bytes "$uncompressed_size" | zip -X -9 -q "$tmp_filename" -
	zipinfo -v "$tmp_filename" | grep -q '^  compression method: *deflated$' || { echo "error: not deflated" 1>&2; exit 1; }
	compressed_size="$(zipinfo -v "$tmp_filename" | grep '^  compressed size:' | grep -E -o '[0-9]+')"
	echo "infozip,$uncompressed_size,$compressed_size"
	rm -f "$tmp_filename"
}
export -f trial_infozip

trial_zopfli() {
	uncompressed_size="$1"
	tmp_filename="$(mktemp -u --suffix=.zopfli-input)"
	repeated_bytes "$uncompressed_size" > "$tmp_filename"
	compressed_size="$(zopfli --deflate -c "$tmp_filename" | wc -c)"
	echo "zopfli,$uncompressed_size,$compressed_size"
	rm -f "$tmp_filename"
}
export -f trial_zopfli

trial_bzip2() {
	uncompressed_size="$1"
	compressed_size="$(repeated_bytes "$uncompressed_size" | bzip2 -c -9 | wc -c)"
	echo "bzip2,$uncompressed_size,$compressed_size"
}
export -f trial_bzip2

run_parallel() {
	xargs -n 1 -P "$PARALLELISM" -I '{}' bash -c "$1"
}


seq 21730000 21760000 | run_parallel 'trial_bulkdeflate{}'
seq 21705000 21736000 | run_parallel 'trial_zlib {}'
seq 21705000 21736000 | run_parallel 'trial_infozip {}'
seq 21713000 21746000 | run_parallel 'trial_zopfli {}'
seq 21740000 21760000 | run_parallel 'trial_bzip2 {}'

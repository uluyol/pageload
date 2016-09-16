#!/usr/bin/env bash

# assume that PATH has already been set by a previous script
# as this is for internal use only

set -e

extracted=$(cat)

index_urls=$(jq -r .indexRedirectChain[] <<<"$extracted")
index_last_url=$(tail -n1 <<<"$index_urls")
online=$(jq -r .indexBody <<<"$extracted" | _internal_get_online_deps.py "$index_last_url")

_setops_ignore_types.py intersection \
	<(jq -r '.resources[] | .url + " " + .contentType' <<<"$extracted" | sort) \
	<(echo "$online" | sort)

#!/usr/bin/env bash

set -e

cd "${0%/*}"
exec node index.js "$@"

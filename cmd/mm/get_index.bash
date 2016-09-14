#!/usr/bin/env bash

export PYTHONPATH=$PYTHONPATH:${0%/}
python3 "${0%/*}/get_index.py" "$@"


#!/bin/bash


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cd "$SCRIPT_DIR"/json_rpc/raw
dub test -- -s

cd "$SCRIPT_DIR"/json_rpc/http
dub test -- -s

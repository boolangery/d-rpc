#!/bin/bash


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cd "$SCRIPT_DIR"/tests/json_rpc/raw
dub test -- -s

cd "$SCRIPT_DIR"/tests/json_rpc/http
dub test -- -s

cd "$SCRIPT_DIR"/tests/json_rpc/tcp
dub test -- -s

cd "$SCRIPT_DIR"/examples/http_client
dub build

cd "$SCRIPT_DIR"/examples/http_server
dub build

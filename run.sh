#!/bin/bash


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"


# run tests
cd "$SCRIPT_DIR"/tests/json_rpc
dub test -- -s

cd "$SCRIPT_DIR"/tests/stratum_rpc
dub test -- -s


# build example
cd "$SCRIPT_DIR"/examples/http_client
dub build

cd "$SCRIPT_DIR"/examples/http_server
dub build

cd "$SCRIPT_DIR"/examples/tcp_client
dub build

cd "$SCRIPT_DIR"/examples/tcp_server
dub build

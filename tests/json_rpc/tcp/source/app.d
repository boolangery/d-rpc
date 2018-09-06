/**
	This module contains the tests for http json rpc.
	License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
	Authors: Eliott Dumeix
*/
import common;
import std.conv;
import rpc.protocol.json;

import vibe.http.router;
import vibe.core.concurrency;
import vibe.core.log;


static this () {
    setLogLevel(LogLevel.verbose1);
}

@Name("JsonRpcAutoTCPClient: Should timeout")
unittest {
    auto client = new JsonRpcAutoTCPClient!IAPI("127.0.0.1", 20001);
    client.add(1, 2).shouldThrowExactly!RpcException;
}

@Name("JsonRpcAutoTCPClient: Should handle a basic call")
unittest {
    // start the rpc server
    auto server = new JsonRpcTCPServer!int(20002);
    server.registerInterface!IAPI(new API());

    // test success call
    auto client = new JsonRpcAutoTCPClient!IAPI("127.0.0.1", 20002);
    client.add(3, 4).should.be == 7;
}
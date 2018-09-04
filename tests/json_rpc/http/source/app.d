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

@Name("JsonRpcAutoClient: No http server started: timeout (int id)")
unittest {
    auto client = new JsonRpcAutoHTTPClient!IAPI("http://127.0.0.1:8080/rpc_2");
    client.add(1, 2).shouldThrowExactly!RpcException;
}

@Name("JsonRpcAutoClient: No http server started: timeout (string id)")
unittest {
    auto client = new JsonRpcAutoHTTPClient!IAPI("http://127.0.0.1:8080/rpc_2");
    client.add(1, 2).shouldThrowExactly!RpcException;
}

@Name("JsonRpcAutoClient :Should timeout when no http server is started")
unittest {
    // no http server started: timeout
    auto client = new JsonRpcAutoHTTPClient!IAPI("http://127.0.0.1:8080/rpc_2");
    client.add(1, 2).shouldThrowExactly!RpcException;
}


@Name("Client basic call")
unittest {
    // start the rpc server
    auto router = new URLRouter();
    auto server = new JsonRpcHttpServer!int(router, "/rpc_2");
    server.registerInterface!IAPI(new API());
    auto listener = listenHTTP("127.0.0.1:8080", router);

    // test success call
    auto client = new JsonRpcAutoHTTPClient!IAPI("http://127.0.0.1:8080/rpc_2");
    client.add(3, 4).should.be == 7;

    listener.stopListening();
}

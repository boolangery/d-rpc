/**
	This module contains the tests for http json rpc.
	License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
	Authors: Eliott Dumeix
*/
import common;
import std.conv;
import rpc.protocol.stratum;

import vibe.http.router;
import vibe.core.concurrency;
import vibe.core.log;


static this () {
    setLogLevel(LogLevel.verbose1);
}

@SingleThreaded
@Name("JsonRpcAutoHTTPClient: No http server started: timeout (int id)")
unittest {
    auto client = new HTTPStratumRPCAutoClient!IAPI("http://127.0.0.1:8080/rpc_2");
    client.add(1, 2).shouldThrowExactly!RPCException;
}

@SingleThreaded
@Name("JsonRpcAutoHTTPClient: No http server started: timeout (string id)")
unittest {
    auto client = new HTTPStratumRPCAutoClient!IAPI("http://127.0.0.1:8080/rpc_2");
    client.add(1, 2).shouldThrowExactly!RPCException;
}

@SingleThreaded
@Name("JsonRpcAutoHTTPClient :Should timeout when no http server is started")
unittest {
    // no http server started: timeout
    auto client = new HTTPStratumRPCAutoClient!IAPI("http://127.0.0.1:8080/rpc_2");
    client.add(1, 2).shouldThrowExactly!RPCException;
}


@SingleThreaded
@Name("JsonRpcHttpServer: Client basic call")
unittest {
    // start the rpc server
    auto router = new URLRouter();
    auto server = new HTTPStratumRPCServer(router, "/rpc_2");
    server.registerInterface!IAPI(new API());
    auto listener = listenHTTP("127.0.0.1:8080", router);

    // test success call
    auto client = new HTTPStratumRPCAutoClient!IAPI("http://127.0.0.1:8080/rpc_2");
    client.add(3, 4).should.be == 7;

    listener.stopListening();
}

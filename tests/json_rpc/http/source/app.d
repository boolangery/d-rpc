/**
	This module contains the tests for http json rpc.
	License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
	Authors: Eliott Dumeix
*/
import common;
import std.conv;

import vibe.http.router;
import vibe.core.concurrency;
import vibe.core.log;


static this () {
    setLogLevel(LogLevel.verbose4);
}

@Name("No http server started: timeout")
unittest {
    auto client = new RpcInterfaceClient!IAPI("http://127.0.0.1:8080/rpc_2");
    client.add(1, 2).shouldThrowExactly!RpcException;
}

@Name("Should timeout when no http server is started")
unittest {
    // no http server started: timeout
    auto client = new RpcInterfaceClient!IAPI("http://127.0.0.1:8080/rpc_2");
    client.add(1, 2).shouldThrowExactly!RpcException;
}

/*
@Name("Client basic call")
unittest {
    // start the rpc server
    auto router = new URLRouter();
    router.registerRpcInterface!Json2_0(new API(), "/rpc_2");
    listenHTTP("127.0.0.1:8080", router);

    // test success call
    auto client = new RpcInterfaceClient!IAPI("http://127.0.0.1:8080/rpc_2");
    client.add(3, 4).should.be == 7;
}
*/

/*
int main(string[] args) {
    // no http server started: timeout
    auto client = new RpcInterfaceClient!IAPI("http://127.0.0.1:8080/rpc_2");
    client.add(1, 2).shouldThrowExactly!RpcException;

    // start the rpc server
    auto router = new URLRouter();
    router.registerRpcInterface!Json2_0(new API(), "/rpc_2");
    listenHTTP("127.0.0.1:8080", router);

    // test success call
    client.add(3, 4).should.be == 7;

    // test one missing parameter from client-side
    auto badClient = new RpcInterfaceClient!IBadAPI("http://127.0.0.1:8080/rpc_2");
    badClient.add(5).shouldThrowExactly!RpcException;

    // test exception on server side
    client.div(1, 0).shouldThrowExactly!RpcException;

    client.div(25, 5).should.be == 5;


    writeln("all tests run successfully");

    return 0;
}
*/
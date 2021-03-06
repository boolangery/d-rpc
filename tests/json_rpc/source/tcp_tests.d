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


// static this ()
// {
//     setLogLevel(LogLevel.verbose4);
// }

@SingleThreaded
@Name("TCPJsonRPCAutoClient: Should timeout")
unittest
{
    auto client = new TcpJsonRpcAutoClient!IAPI("127.0.0.1", 20001);
    client.add(1, 2).shouldThrowExactly!RpcException;
}

@SingleThreaded
@Name("TCPJsonRPCAutoClient: Should handle a basic call")
@Tags("foo")
unittest
{
    // start the rpc server
    auto server = new TcpJsonRpcServer!int(20002);
    server.registerInterface!IAPI(new API());

    // test success call
    auto client = new TcpJsonRpcAutoClient!IAPI("127.0.0.1", 20002);
    client.add(3, 4).should == 7;

    // test @ObjectAsParam endpoint
    client.asObject("foo", 42).should == "foo42";
}

@SingleThreaded
@Name("TCPJsonRPCServer: invalid json received")
unittest
{
    import vibe.core.net : listenTCP;

    bool called = false;

    // settings
    auto settings = new RpcInterfaceSettings();
    settings.errorHandler = (Exception e) @safe {
        called = true;
    };

    // start the rpc server
    auto server = new TcpJsonRpcServer!int(20003u, settings);
    server.registerInterface!IAPI(new API());

    // fake an invalid json call
    auto client = connectTCP("127.0.0.1", 20003u);
    client.write(`{"jsonrpc":"2.0","id":2,"res` ~ "\r\n");
    client.flush();
    client.waitForData();
    called.should == true;
}

@SingleThreaded
@Name("TCPJsonRPCAutoClient: wrong client")
unittest
{
    // start the rpc server
    auto server = new TcpJsonRpcServer!int(20004);
    server.registerInterface!IAPI(new API());

    struct Bad
    {
        string login = "foo";
    }

    static interface IFail
    {
        int add(Bad b);
    }
    Bad b;

    // test success call
    auto client = new TcpJsonRpcAutoClient!IFail("127.0.0.1", 20004);
    client.add(b).shouldThrowExactly!RpcException;
}

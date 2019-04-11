/**
	This module contains the tests for raw json rpc.
	License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
	Authors: Eliott Dumeix
*/
import common;
import std.conv;

import rpc.protocol.json;

@SingleThreaded
@Name("RawJsonRPCAutoClient: basic call")
@Values(12, 42)
unittest {
    auto input = `{"jsonrpc":"2.0","id":2,"result":` ~ to!string(getValue!int) ~ "}";
    auto istream = createMemoryStream(input.toBytes());
    auto ostream = createMemoryOutputStream();

    auto api = new RawJsonRpcAutoClient!IAPI(ostream, istream);

    // test the client side:
    // inputstream not processed: timeout
    api.add(1, 2).shouldThrowExactly!RpcException;
    ostream.str.should.be == JsonRpcRequest!int.make(1, "add", [1, 2]).toString();

    // process input stream
    api.client.tick();

    // client must send a reponse
    api.add(1, 2).should.be == getValue!int;
}

@SingleThreaded
@Name("RawJsonRPCAutoClient: one param")
unittest {
    auto istream = createMemoryStream("".toBytes());
    auto ostream = createMemoryOutputStream();

    auto api = new RawJsonRpcAutoClient!IAPI(ostream, istream);

    api.set("foo").shouldThrowExactly!RpcException;
    ostream.str.should.be == JsonRpcRequest!int.make(1, "set", "foo").toString();
}

@SingleThreaded
@Name("RawJsonRPCAutoClient.@rpcMethod")
unittest {
    auto istream = createMemoryStream("".toBytes());
    auto ostream = createMemoryOutputStream();

    auto api = new RawJsonRpcAutoClient!IAPI(ostream, istream);

    api.nameChanged().shouldThrowExactly!RpcException;
    ostream.str.should.be == JsonRpcRequest!int.make(1, "name_changed").toString();
}

@SingleThreaded
@Name("RawJsonRPCAutoClient: params as object")
unittest {
    auto istream = createMemoryStream("".toBytes());
    auto ostream = createMemoryOutputStream();

    IAPI api = new RawJsonRpcAutoClient!IAPI(ostream, istream);

    struct Params
    {
        string my_value = "foo";
        int number = 42;
    }
    Params p;

    api.asObject("foo", 42).shouldThrowExactly!RpcException;
    ostream.str.should.be == JsonRpcRequest!int.make(1, "asObject", p).toString();
}

@SingleThreaded
@Name("RawJsonRPCAutoClient: no return")
unittest {
    auto input = `{"jsonrpc":"2.0","id":1,"result":{}}`;
    auto istream = createMemoryStream(input.toBytes());
    auto ostream = createMemoryOutputStream();

    auto api = new RawJsonRpcAutoClient!IAPI(ostream, istream);
    api.client.tick();

    // client must send a reponse
    api.doNothing();
}

@SingleThreaded
@Name("RawJsonRPCServer: Test server basic call")
unittest {
    auto input = `{"jsonrpc":"2.0","id":1,"method":"add","params":[1,2]}`;
    auto istream = createMemoryStream(input.toBytes());
    auto ostream = createMemoryOutputStream();

    auto s1 = new RawJsonRpcServer!int(ostream, istream);

    s1.registerRequestHandler("add", (req, serv) {
        req.toString().should.be == JsonRpcRequest!int.make(1, "add", [1, 2]).toString();
    });

    s1.tick();
}

@SingleThreaded
@Name("RawJsonRPCServer")
unittest {
    auto input = `{"jsonrpc":"2.0","id":1,"method":"add","params":[1,2]}`;
    auto istream = createMemoryStream(input.toBytes());
    auto ostream = createMemoryOutputStream();

    interface ICalculator
    {
        int sum(int a, int b);
    }

    auto c = new RawJsonRpcAutoClient!ICalculator(ostream, istream);

    c.sum(1, 2).shouldThrowExactly!RpcException;

    ostream.str.should.be == JsonRpcRequest!int.make(1, "sum", [1, 2]).toString();
}

@SingleThreaded
@Name("rpcArrayParams")
unittest {
    auto istream = createMemoryStream("".toBytes());
    auto ostream = createMemoryOutputStream();

    auto c = new RawJsonRpcAutoClient!IAPI(ostream, istream);

    c.forceArray("value").shouldThrowExactly!RpcException;

    ostream.str.should.be == JsonRpcRequest!int.make(1, "forceArray", ["value"]).toString();
}
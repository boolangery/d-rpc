/**
	This module contains the tests for raw json rpc.
	License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
	Authors: Eliott Dumeix
*/
import common;
import std.conv;

import rpc.protocol.json;


@Name("Test client basic call")
@Values(12, 42)
unittest {
    auto input = `{"jsonrpc":"2.0","id":2,"result":` ~ to!string(getValue!int) ~ "}";
    auto istream = createMemoryStream(input.toBytes());
    auto ostream = createMemoryOutputStream();

    auto c1 = new RpcInterfaceClient!IAPI(ostream, istream);

    // test the client side:
    // inputstream not processed: timeout
    c1.add(1, 2).shouldThrowExactly!RpcException;
    ostream.str.should.be == `{"jsonrpc":"2.0","id":1,"method":"add","params":[1,2]}`;

    // process input stream
    c1.tick();

    // client must send a reponse
    c1.add(1, 2).should.be == getValue!int;
}

@Name("Test client call with one param")
unittest {
    auto istream = createMemoryStream("".toBytes());
    auto ostream = createMemoryOutputStream();

    auto c1 = new RpcInterfaceClient!IAPI(ostream, istream);

    c1.set("foo").shouldThrowExactly!RpcException;
    ostream.str.should.be == `{"jsonrpc":"2.0","id":1,"method":"set","params":"foo"}`;
}

@Name("Test client call with params as object")
unittest {
    auto istream = createMemoryStream("".toBytes());
    auto ostream = createMemoryOutputStream();

    IAPI c1 = new RpcInterfaceClient!IAPI(ostream, istream);

    c1.asObject("foo", 42).shouldThrowExactly!RpcException;
    ostream.str.should.be == `{"jsonrpc":"2.0","id":1,"method":"asObject","params":{"my_value":"foo","number":42}}`;
}

@Name("Test client call with no return")
unittest {
    auto input = `{"jsonrpc":"2.0","id":1,"result":{}}`;
    auto istream = createMemoryStream(input.toBytes());
    auto ostream = createMemoryOutputStream();

    auto c2 = new RpcInterfaceClient!IAPI(ostream, istream);
    c2.tick();

    // client must send a reponse
    c2.doNothing();
}

@Name("Test server basic call")
unittest {
    auto input = `{"jsonrpc":"2.0","id":1,"method":"add","params":[1,2]}`;
    auto istream = createMemoryStream(input.toBytes());
    auto ostream = createMemoryOutputStream();

    auto s1 = new RawJsonRpcServer!int(ostream, istream);

    s1.registerRequestHandler("add", (req, serv) {
        req.toString().should.be == `{"jsonrpc":"2.0","id":1,"method":"add","params":[1,2]}`;
    });

    s1.tick();
}

@Name("JsonRpcInterfaceClient")
unittest {
    auto input = `{"jsonrpc":"2.0","id":1,"method":"add","params":[1,2]}`;
    auto istream = createMemoryStream(input.toBytes());
    auto ostream = createMemoryOutputStream();

    interface ICalculator
    {
        int sum(int a, int b);
    }

    auto c = new JsonRpcInterfaceClient!(ICalculator)(ostream, istream);

    c.sum(1, 2).shouldThrowExactly!RpcException;

    ostream.str.should.be == `{"jsonrpc":"2.0","id":1,"method":"sum","params":[1,2]}`;
}
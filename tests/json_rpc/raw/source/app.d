/**
	This module contains the tests for raw json rpc.
	License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
	Authors: Eliott Dumeix
*/
import common;
import std.conv;

import rpc.protocol.json;


@Name("JsonRpcAutoClient: basic call")
@Values(12, 42)
unittest {
    auto input = `{"jsonrpc":"2.0","id":2,"result":` ~ to!string(getValue!int) ~ "}";
    auto istream = createMemoryStream(input.toBytes());
    auto ostream = createMemoryOutputStream();

    auto api = new RawJsonRpcAutoClient!IAPI(ostream, istream);

    // test the client side:
    // inputstream not processed: timeout
    api.add(1, 2).shouldThrowExactly!RpcException;
    ostream.str.should.be == `{"jsonrpc":"2.0","id":1,"method":"add","params":[1,2]}`;

    // process input stream
    api.client.tick();

    // client must send a reponse
    api.add(1, 2).should.be == getValue!int;
}

@Name("JsonRpcAutoClient: one param")
unittest {
    auto istream = createMemoryStream("".toBytes());
    auto ostream = createMemoryOutputStream();

    auto api = new RawJsonRpcAutoClient!IAPI(ostream, istream);

    api.set("foo").shouldThrowExactly!RpcException;
    ostream.str.should.be == `{"jsonrpc":"2.0","id":1,"method":"set","params":"foo"}`;
}

@Name("JsonRpcAutoClient.@rpcMethod")
unittest {
    auto istream = createMemoryStream("".toBytes());
    auto ostream = createMemoryOutputStream();

    auto api = new RawJsonRpcAutoClient!IAPI(ostream, istream);

    api.nameChanged().shouldThrowExactly!RpcException;
    ostream.str.should.be == `{"jsonrpc":"2.0","id":1,"method":"name_changed"}`;
}

@Name("JsonRpcAutoClient: params as object")
unittest {
    auto istream = createMemoryStream("".toBytes());
    auto ostream = createMemoryOutputStream();

    IAPI api = new RawJsonRpcAutoClient!IAPI(ostream, istream);

    api.asObject("foo", 42).shouldThrowExactly!RpcException;
    ostream.str.should.be == `{"jsonrpc":"2.0","id":1,"method":"asObject","params":{"my_value":"foo","number":42}}`;
}

@Name("JsonRpcAutoClient: no return")
unittest {
    auto input = `{"jsonrpc":"2.0","id":1,"result":{}}`;
    auto istream = createMemoryStream(input.toBytes());
    auto ostream = createMemoryOutputStream();

    auto api = new RawJsonRpcAutoClient!IAPI(ostream, istream);
    api.client.tick();

    // client must send a reponse
    api.doNothing();
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

@Name("JsonRpcAutoClient")
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

    ostream.str.should.be == `{"jsonrpc":"2.0","id":1,"method":"sum","params":[1,2]}`;
}
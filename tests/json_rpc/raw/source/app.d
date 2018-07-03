/**
	This module contains the tests for raw json rpc.
	License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
	Authors: Eliott Dumeix
*/
import common;
import std.conv;


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

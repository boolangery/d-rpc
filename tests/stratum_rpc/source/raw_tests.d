/**
	This module contains the tests for raw stratum rpc.
	License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
	Authors: Eliott Dumeix
*/
import common;
import std.conv;

import rpc.protocol.stratum;

@SingleThreaded
@Name("RawStratumRPCAutoClient: basic call")
@Values(12, 42)
unittest {
    auto input = `{"jsonrpc":"2.0","id":2,"result":` ~ to!string(getValue!int) ~ "}";
    auto istream = createMemoryStream(input.toBytes());
    auto ostream = createMemoryOutputStream();

    auto api = new RawStratumRPCAutoClient!IAPI(ostream, istream);

    // test the client side:
    // inputstream not processed: timeout
    api.add(1, 2).shouldThrowExactly!RPCException;
    ostream.str.should.be == StratumRPCRequest.make(1, "add", [1, 2]).toString();

    // process input stream
    api.client.tick();

    // client must send a reponse
    api.add(1, 2).should.be == getValue!int;
}

@SingleThreaded
@Name("RawStratumRPCAutoClient: one param")
unittest {
    auto istream = createMemoryStream("".toBytes());
    auto ostream = createMemoryOutputStream();

    auto api = new RawStratumRPCAutoClient!IAPI(ostream, istream);

    api.set("foo").shouldThrowExactly!RPCException;
    ostream.str.should.be == StratumRPCRequest.make(1, "set", "foo").toString();
}

@SingleThreaded
@Name("RawStratumRPCAutoClient.@rpcMethod")
unittest {
    auto istream = createMemoryStream("".toBytes());
    auto ostream = createMemoryOutputStream();

    auto api = new RawStratumRPCAutoClient!IAPI(ostream, istream);

    api.nameChanged().shouldThrowExactly!RPCException;
    ostream.str.should.be == StratumRPCRequest.make(1, "name_changed").toString();
}

@SingleThreaded
@Name("RawStratumRPCAutoClient: params as object")
unittest {
    auto istream = createMemoryStream("".toBytes());
    auto ostream = createMemoryOutputStream();

    IAPI api = new RawStratumRPCAutoClient!IAPI(ostream, istream);

    struct Params
    {
        string my_value = "foo";
        int number = 42;
    }
    Params p;

    api.asObject("foo", 42).shouldThrowExactly!RPCException;
    ostream.str.should.be == StratumRPCRequest.make(1, "asObject", p).toString();
}

@SingleThreaded
@Name("RawStratumRPCAutoClient: no return")
unittest {
    auto input = `{"jsonrpc":"2.0","id":1,"result":{}}`;
    auto istream = createMemoryStream(input.toBytes());
    auto ostream = createMemoryOutputStream();

    auto api = new RawStratumRPCAutoClient!IAPI(ostream, istream);
    api.client.tick();

    // client must send a reponse
    api.doNothing();
}

@SingleThreaded
@Name("RawStratumRPCAutoClient: Test server basic call")
unittest {
    auto input = `{"jsonrpc":"2.0","id":1,"method":"add","params":[1,2]}`;
    auto istream = createMemoryStream(input.toBytes());
    auto ostream = createMemoryOutputStream();

    auto s1 = new RawStratumRPCServer(ostream, istream);

    s1.registerRequestHandler("add", (req, serv) {
        req.toString().should.be == StratumRPCRequest.make(1, "add", [1, 2]).toString();
    });

    s1.tick();
}

@SingleThreaded
@Name("RawStratumRPCAutoClient")
unittest {
    auto input = `{"jsonrpc":"2.0","id":1,"method":"add","params":[1,2]}`;
    auto istream = createMemoryStream(input.toBytes());
    auto ostream = createMemoryOutputStream();

    interface ICalculator
    {
        int sum(int a, int b);
    }

    auto c = new RawStratumRPCAutoClient!ICalculator(ostream, istream);

    c.sum(1, 2).shouldThrowExactly!RPCException;

    ostream.str.should.be == StratumRPCRequest.make(1, "sum", [1, 2]).toString();
}
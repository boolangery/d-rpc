import rpc.server;
import rpc.client;
import unit_threaded;
import std.stdio;
import std.conv;

import vibe.http.router;
import vibe.core.concurrency;
import vibe.core.log;
import vibe.stream.memory;
import vibe.stream.operations;

/** The API to test.
*/
@rpcIdType!int
interface IAPI
{
    int add(int a, int b);

    int div(int a, int b);

    void doNothing();
}

/** Represent a bad client implementation of IAPI.
*/
@rpcIdType!int
interface IBadAPI
{
    int add(int b);
}

/** Api implementation.
*/
class API: IAPI
{
    int add(int a, int b)
    {
        return a + b;
    }

    int div(int a, int b)
    {
        if (b == 0)
            throw new Exception("invalid diviser (0)");
        else
            return a/b;
    }

    void doNothing() {}
}

/// MemoryOutputStream helper to get data as a string.
string str(MemoryOutputStream stream)
{
    import std.conv: to;
    return to!string(cast(char[])stream.data);
}

ubyte[] toBytes(string str) @safe
{
    return cast(ubyte[])(str.dup);
}


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

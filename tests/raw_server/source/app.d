import rpc.server;
import rpc.client;
import unit_threaded;
import std.stdio;

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


int main(string[] args) {
    setLogLevel(LogLevel.verbose4);

    MemoryStream istream;
    MemoryOutputStream ostream;

    void setupStreams(string preloadedData) @safe
    {
        auto bytes = cast(ubyte[])(preloadedData.dup);
        istream = createMemoryStream(bytes);
        ostream = createMemoryOutputStream();
    }

    // ////////////////////////////////////////////////////////////////////////
    // client side
    // ////////////////////////////////////////////////////////////////////////
    // test basic client call
    setupStreams(`{"jsonrpc":"2.0","id":2,"result":3}`);
    auto c1 = new RpcInterfaceClient!IAPI(ostream, istream);

    // test the client side:
    // inputstream not processed: timeout
    c1.add(1, 2).shouldThrowExactly!RpcException;
    ostream.str.should.be == `{"jsonrpc":"2.0","id":1,"method":"add","params":[1,2]}`;

    // process input stream
    c1.tick();

    // client must send a reponse
    c1.add(1, 2).should.be == 3;

    // ////////////////////////////////////////////////////////////////////////
    // test client call with no param, no response
    setupStreams(`{"jsonrpc":"2.0","id":1,"result":{}}`);
    auto c2 = new RpcInterfaceClient!IAPI(ostream, istream);
    c2.tick();

    // client must send a reponse
    c2.doNothing();

    // ////////////////////////////////////////////////////////////////////////
    // server side
    // ////////////////////////////////////////////////////////////////////////
    // test invalid json in reponse
    setupStreams(`{"jsonrpc":"2.0","id":1,"method":"add","params":[1,2]}`);
    auto s1 = new RawJsonRpcServer!int(ostream, istream);

    s1.registerRequestHandler("add", (req, serv) {
        req.toString().should.be == `{"jsonrpc":"2.0","id":1,"method":"add","params":[1,2]}`;
    });

    s1.tick();

    writeln("all tests run successfully");

    return 0;
}

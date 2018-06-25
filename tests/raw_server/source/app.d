import rpc.server;
import rpc.client;
import unit_threaded;
import std.stdio;

import vibe.http.router;
import vibe.core.concurrency;
import vibe.core.log;
import vibe.stream.memory: MemoryOutputStream, MemoryStream;
import vibe.stream.operations;

/** The API to test.
*/
@rpcIdType!int
interface IAPI
{
    int add(int a, int b);

    int div(int a, int b);
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
}

/// MemoryOutputStream helper to get data as a string.
string str(MemoryOutputStream stream)
{
    import std.conv: to;
    return to!string(cast(char[])stream.data);
}


int main(string[] args) {
    setLogLevel(LogLevel.verbose4);

    // setup test
    auto add_1_2_resp = cast(ubyte[])(`{"jsonrpc":"2.0","id":2,"result":3}`.dup);
    auto istream = new MemoryStream(add_1_2_resp);
    auto ostream = new MemoryOutputStream();
    // create the client
    auto client = new RpcInterfaceClient!IAPI(ostream, istream);

    // test the client side:
    // inputstream not processed: timeout
    client.add(1, 2).shouldThrowExactly!RpcException;
    ostream.str.should.be == `{"jsonrpc":"2.0","id":1,"method":"add","params":[1,2]}`;

    // process input stream
    client.tick();


    // client must send a reponse
    client.add(1, 2).should.be == 3;


/*
    // start the rpc server
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

*/
    writeln("all tests run successfully");

    return 0;
}

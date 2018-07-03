import rpc.server;
import rpc.client;
import unit_threaded;
import std.stdio;

import vibe.http.router;
import vibe.core.concurrency;
import vibe.core.log;
import vibe.core.core;


@rpcIdType!int
interface IAPI
{
    int add(int a, int b);

    int div(int a, int b);
}

@rpcIdType!int
interface IBadAPI
{
    int add(int b);
}

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


int main(string[] args) {
    setLogLevel(LogLevel.verbose4);


    // start the rpc server
    auto server = new TcpJsonRpcServer!int(13000);
    server.registerRpcInterface(new API());

    // connect the client
    auto client = new RpcInterfaceClient!IAPI("127.0.0.1", 13000);
    client.connect();
    client.connected.should.be == true;

    // test success call
    client.add(3, 4).should.be == 7;

    // test one missing parameter from client-side
    auto badClient = new RpcInterfaceClient!IBadAPI("127.0.0.1", 13000);
    badClient.add(5).shouldThrowExactly!RpcException;

    // test exception on server side
    client.div(1, 0).shouldThrowExactly!RpcException;
    client.div(25, 5).should.be == 5;

    writeln("all tests run successfully");

    return 0;
}

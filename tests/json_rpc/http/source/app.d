import rpc.server;
import rpc.client;
import unit_threaded;
import std.stdio;

import vibe.http.router;
import vibe.core.concurrency;
import vibe.core.log;


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

    // no http server started: timeout
    auto client = new RpcInterfaceClient!IAPI("http://127.0.0.1:8080/rpc_2");
    client.add(1, 2).shouldThrowExactly!RpcException;

    // start the rpc server
    auto router = new URLRouter();
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


    writeln("all tests run successfully");

    return 0;
}

import std.stdio;
import rpc.protocol.json;
import vibe.appmain;
import vibe.http.router;


interface ICalculator
{
    int sum(int a, int b);
    int mult(int a, int b);
}

class Calculator : ICalculator
{
    int sum(int a, int b) { return a + b; }
    int mult(int a, int b) { return a * b; }
}

shared static this()
{
	auto router = new URLRouter();
    auto server = new HTTPJsonRPCServer!int(router, "/rpc_2");
    server.registerInterface!ICalculator(new Calculator());
    listenHTTP("127.0.0.1:8080", router);
}

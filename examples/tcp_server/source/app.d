import rpc.protocol.json;
import vibe.appmain;


interface ICalculator
{
    int sum(int a, int b);
    int mult(int a, int b);
}

class Calculator : ICalculator
{
    this(string clientId)
    {
    }

    int sum(int a, int b) { return a + b; }
    int mult(int a, int b) { return a * b; }
}

shared static this()
{
    auto server = new TCPJsonRPCServer!int(2000u);

    server.registerInterface!ICalculator((conn) {
        return new Calculator(conn.peerAddress());
    });
}

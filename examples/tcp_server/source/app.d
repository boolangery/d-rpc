import rpc.core : rpcMethod;
import rpc.protocol.json;
import vibe.appmain;
import vibe.data.json;


struct ComplexNumber
{
    @name("real") double realPart;
    @name("imaginary") double imPart;

    this(double r, double i) {
        realPart = r;
        imPart = i;
    }

    ComplexNumber opBinary(string op)(ComplexNumber other) if(op == "+") {
        return ComplexNumber(realPart + other.realPart, imPart + other.imPart);
    }
}

interface ICalculator
{
    int sum(int a, int b);
    int mult(int a, int b);
    ComplexNumber sumComplex(ComplexNumber a, ComplexNumber b);
}

class Calculator : ICalculator
{
    this(string clientId)
    {
    }

    int sum(int a, int b) { return a + b; }
    int mult(int a, int b) { return a * b; }

    ComplexNumber sumComplex(ComplexNumber a, ComplexNumber b) {
        return a + b;
    }
}

shared static this()
{
    auto server = new TcpJsonRpcServer!int(2000u);

    server.registerInterface!ICalculator((conn) {
        return new Calculator(conn.peerAddress());
    });
}

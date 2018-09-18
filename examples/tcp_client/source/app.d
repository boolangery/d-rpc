import std.stdio;
import rpc.core : rpcMethod;
import rpc.protocol.json;
import vibe.data.json;
import std.string : format;

class ComplexNumber
{
    @name("real") double realPart;
    @name("imaginary") double imPart;

    this() @safe {} // needed by json serialization

    this(double r, double i) {
        realPart = r;
        imPart = i;
    }

    override string toString() { return format("(%f, %fi)", realPart, imPart);}
}

interface ICalculator
{
    int sum(int a, int b);
    int mult(int a, int b);

    ComplexNumber sumComplex(ComplexNumber a, ComplexNumber b);
}

void main()
{
	auto calc = new TCPJsonRPCAutoClient!ICalculator("127.0.0.1", 2000u);

	writeln(calc.sum(1, 2));
	writeln(calc.mult(5, 5));

	writeln(calc.sumComplex(new ComplexNumber(2, 3), new ComplexNumber(4, 1)));
}

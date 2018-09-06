import std.stdio;
import rpc.protocol.json;
import vibe.http.router;


interface ICalculator
{
    int sum(int a, int b);
    int mult(int a, int b);
}

void main()
{
	auto calc = new HTTPJsonRPCAutoClient!ICalculator("http://127.0.0.1:8080/rpc_2");

	writeln(calc.sum(1, 2));
	writeln(calc.mult(5, 5));
}

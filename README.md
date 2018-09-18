rpc
===

| [![Build Status](https://api.travis-ci.org/boolangery/d-rpc.svg?branch=master)](https://api.travis-ci.org/boolangery/d-rpc) |

An rpc library aimed to be protocol agnostic. It's based on automatic interface implementation.

It currently support:

* [Json RPC 2.0](https://www.jsonrpc.org/specification)
* [Stratum](https://en.bitcoin.it/wiki/Stratum_mining_protocol)



It use vibed as HTTP and TCP driver.

It also use [vibe.data.json](http://vibed.org/api/vibe.data.json/) for json serialization.

Quick start with dub
----------------------

```json
"dependencies": {
	"rpc": "*"
}
```


Usage
-----

Server:

```d
import rpc.core : rpcMethod;
import rpc.protocol.json;
import vibe.appmain;
import vibe.data.json;


class ComplexNumber
{
    @name("real") double realPart;
    @name("imaginary") double imPart;

    this() @safe {} // needed by json serialization

    this(double r, double i) {
        realPart = r;
        imPart = i;
    }

    ComplexNumber opBinary(string op)(ComplexNumber other) if(op == "+") {
        return new ComplexNumber(realPart + other.realPart, imPart + other.imPart);
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
    auto server = new TCPJsonRPCServer!int(2000u);

    server.registerInterface!ICalculator((conn) {
        return new Calculator(conn.peerAddress());
    });
}
```

Client:

```d
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
```

See more in the examples folder.

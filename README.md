rpc
===

| [![Build Status](https://api.travis-ci.org/boolangery/d-rpc.svg?branch=master)](https://api.travis-ci.org/boolangery/d-rpc) |

An rpc library aimed to be protocol independent. It's based on automatic interface implementation.

It currently support:

* Json RPC 2.0

It use vibed as HTPP and TCP driver.

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
import rpc.protocol.json;
import vibe.appmain;


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
	auto server = new TCPJsonRPCServer!int(2000u);
	server.registerInterface!ICalculator(new Calculator());
}
```

Client:

```d
import std.stdio;
import rpc.protocol.json;


interface ICalculator
{
	int sum(int a, int b);
	int mult(int a, int b);
}

void main()
{
	auto calc = new TCPJsonRPCAutoClient!ICalculator("127.0.0.1", 2000u);

	writeln(calc.sum(1, 2));
	// > {"jsonrpc": "2.0", "method": "sum", "params": [1, 2], "id": 1}
	// < {"jsonrpc": "2.0", "result": 3, "id": 1}

	writeln(calc.mult(5, 5));
	// > {"jsonrpc": "2.0", "method": "mult", "params": [5, 5], "id": 2}
	// < {"jsonrpc": "2.0", "result": 25, "id": 2}
}
```

See more in the examples folder.

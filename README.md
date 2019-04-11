rpc
===

[![DUB Package](https://img.shields.io/dub/v/rpc.svg)](https://code.dlang.org/packages/rpc)
[![Build Status](https://api.travis-ci.org/boolangery/d-rpc.svg?branch=master)](https://api.travis-ci.org/boolangery/d-rpc)

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


Basic usage
-----------

An example showing how to fetch the last [Ethereum](https://www.ethereum.org/) block number using 
the [rpc api](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_blocknumber).

```d
import std.stdio;
import rpc.protocol.json;


interface IEthereumApi
{
    string eth_blockNumber();
}

void main()
{
	enum EthNode = "https://eth-mainnet.alchemyapi.io/jsonrpc/-vPGIFwUyjlMRF9beTLXiGQUK6Nf3k8z";
	auto eth = new HttpJsonRpcAutoClient!IEthereumApi(EthNode);

	writeln(eth.eth_blockNumber());
}
```

The server for the above example could be implemented like this:


```d
import rpc.protocol.json;


interface IEthereumApi
{
	string eth_blockNumber();
}

class EthereumServer : IEthereumApi
{
	override string eth_blockNumber()
	{
		return "42";
	}
}

void main()
{
	import vibe.http.router;
	
	enum EthNode = "https://eth-mainnet.alchemyapi.io/jsonrpc/-vPGIFwUyjlMRF9beTLXiGQUK6Nf3k8z";
	auto eth = new HttpJsonRpcAutoClient!IEthereumApi(EthNode);

	writeln(eth.eth_blockNumber());
	
	auto router = new URLRouter();
	auto server = new HttpJsonRpcServer!int(router, "/my_endpoint");
	server.registerInterface!IEthereumApi(new EthereumServer());
	listenHTTP("127.0.0.1:8080", router);
}

```

You can browse the `examples` folder for more information.

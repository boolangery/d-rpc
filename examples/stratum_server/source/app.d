// https://slushpool.com/help/manual/stratum-protocol

import std.stdio;
import rpc.json;
import vibe.core.core;
import rpc.client;
import vibe.core.concurrency;
import vibe.core.log;
import core.time;


interface IRpcService
{
	int add(int a, int b);
}

class RpcService: IRpcService
{
	int add(int a, int b)
	{
		return a + b;
	}
}

void main()
{
	setLogLevel(LogLevel.verbose4);

	auto rpcServer = new TcpJsonRpcServer!int(11375);

	rpcServer.registerInterface(new RpcService());

	auto client = new TcpJsonRpcClient!int("127.0.0.1", 11375);
	auto api = new RpcInterfaceClient!IRpcService(client);

	runTask({
		writeln(api.add(1, 3));
	});


	runApplication();
}

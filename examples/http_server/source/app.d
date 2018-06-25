import std.stdio;
import vibe.http.router;
import rpc.json;
import rpc.server;
import vibe.core.core;
import rpc.client;
import vibe.core.concurrency;
import vibe.core.log;

class OpResult
{
	int left;
	int right;
	int result;

	this() @safe {}

	this(int left, int right, int result)
	@safe {
		this.left = left;
		this.right = right;
		this.result = result;
	}

}

interface IRpcService
{
	OpResult add(int a, int b);
}

class RpcService: IRpcService
{
	OpResult add(int a, int b)
	{
		return new OpResult(a, b, a+b);
	}
}

void main()
{
	setLogLevel(LogLevel.verbose3);

	auto router = new URLRouter;

	router.registerRpcInterface(new RpcService(), "/rpc");



	runTask({
		auto api = new RpcInterfaceClient!IRpcService("http://127.0.0.1:8080/rpc");
		api.add(1, 2);
	});

	//writeln(sum.getResult());

	listenHTTP("127.0.0.1:8080", router);
	runApplication();
}

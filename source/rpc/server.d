/**
	Rpc server interface generator based on the work from vibed rest interfaces.

	Copyright: © 2018 Eliott Dumeix
	License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
*/
module rpc.server;

import vibe.http.router;
public import rpc.core;
public import rpc.protocol.json: RawJsonRpcServer;
public import rpc.protocol.json: TcpJsonRpcServer;


/** Registers a server on a vibed URLRouter matching a certain RPC interface.
	Servers are implementation of the D interface that defines the RPC API.
	The methods of this class are invoked by the code that is generated for
	each endpoint of the API, with parameters and return values being translated
	according to `RpcProtocol`.

    The rpc interface is registered on the provided `path`.

	A basic 'hello world' RPC API can be defined as follows:
	----
	@rpcIdType!int
	interface APIRoot {
	    string get();
	}
	class API : APIRoot {
	    override string get() { return "Hello, World"; }
	}
	void main()
	{
        // register a json-rpc 2.0 service:
	    router.registerRpcInterface!(RpcProtocol.jsonRpc2_0)(new API(), "/rpc");

	    // POST '{"id":1,"method":"get"}' on http://127.0.0.1:8080/rpc/
	    // and '{"id":1,"result":"Hello, World"}' will be replied
	    listenHTTP("127.0.0.1:8080", router);
	    runApplication();
	}
	----

	As can be seen here, the RPC logic can be written inside the class
	without any concern for the actual transport representation.


	Params:
	    router   = The HTTP router on which the interface will be registered
        path     = The path used to register the service on the router
	    instance = Server instance to use
	    settings = Additional settings

*/
URLRouter registerRpcInterface(RpcProtocol protocol = RpcProtocol.jsonRpc2_0, TImpl)
(URLRouter router, TImpl instance, string path, RpcInterfaceSettings settings = null)
{
    auto intf = RpcInterface!TImpl(settings, false); // compile-time
    alias TId = intf.rpcIdType;

    static if (protocol == RpcProtocol.jsonRpc2_0)
    {
        import rpc.protocol.json;

        auto rpcServer = new JsonRpcHttpServer!TId(router, path);
        doJsonHandlerRegistration!(TId, TImpl)(rpcServer, instance, settings);
    }

    return router;
}

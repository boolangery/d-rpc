/**
    Stratum protocol is based on JSON-RPC 2.0.
    (although it doesn't include "jsonrpc" information in every message).
    Each message has to end with a line end character (n).

    This module has 3 entry point:
        $(UL
			$(LI `RawStratumRpcAutoClient`)
			$(LI `HttpStratumRpcAutoClient`)
			$(LI `TcpStratumRpcAutoClient`)
		)
*/
module rpc.protocol.stratum;

public import rpc.core;
import rpc.protocol.json;
import vibe.data.json;
import std.typecons: Nullable, nullable;


class StratumRpcRequest : JsonRpcRequest!int
{
public:
    static StratumRpcRequest make(T)(int id, string method, T params)
    {
        import vibe.data.json : serializeToJson;

        auto request = new StratumRpcRequest();
        request.id = id;
        request.method = method;
        request.params = serializeToJson!T(params);

        return request;
    }

    static StratumRpcRequest make(int id, string method)
    {
        auto request = new StratumRpcRequest();
        request.id = id;
        request.method = method;

        return request;
    }

    /** Strip the "jsonrpc" field.
    */
    override Json toJson() const @safe
    {
        Json json = Json.emptyObject;
        json["method"] = method;
        json["id"] = id;
        if (!params.isNull)
            json["params"] = params.get;
        return json;
    }

    /** Strip the "jsonrpc" field.
    */
    static StratumRpcRequest fromJson(Json src) @safe
    {
        StratumRpcRequest request = new StratumRpcRequest();
        request.method = src["method"].to!string;
        if (src["id"].type != Json.Type.undefined)
            request.id = src["id"].to!int;
        if (src["params"].type != Json.Type.undefined)
            request.params = src["params"].nullable;
        return request;
    }
}

class StratumRpcResponse : JsonRpcResponse!int
{
public:
    /** Strip the "jsonrpc" field.
    */
    override Json toJson() const @safe
    {
        Json json = Json.emptyObject;
        // the id must be 'null' in case of parse error
        if (!id.isNull)
            json["id"] = id.get;
        else
            json["id"] = null;
        if (!result.isNull)
            json["result"] = result.get;
        if (!error.isNull)
            json["error"] = serializeToJson!(const(JsonRpcError))(error.get);
        return json;
    }

    /** Strip the "jsonrpc" field.
    */
    static StratumRpcResponse fromJson(Json src) @safe
    {
        StratumRpcResponse request = new StratumRpcResponse();
        if (src["id"].type != Json.Type.undefined)
        {
            if (src["id"].type == Json.Type.null_)
                request.id.nullify;
            else
                request.id = src["id"].to!int;
        }
        if (src["result"].type != Json.Type.undefined)
            request.result = src["result"].nullable;
        if (src["error"].type != Json.Type.undefined)
            request.error = deserializeJson!JsonRpcError(src["error"]).nullable;
        return request;
    }
}

class RawStratumRPCServer : RawJsonRpcServer!(int, StratumRpcRequest, StratumRpcResponse)
{
    import vibe.core.stream: InputStream, OutputStream;

public:
    this(OutputStream ostream, InputStream istream) @safe
    {
        super(ostream, istream);
    }
}

class HTTPStratumRPCServer : HttpJsonRpcServer!(int, StratumRpcRequest, StratumRpcResponse)
{
    import vibe.http.router: URLRouter;

public:
    this(URLRouter router, string path)
    {
        super(router, path);
    }
}

class TCPStratumRPCServer : TcpJsonRpcServer!(int, StratumRpcRequest, StratumRpcResponse)
{
public:
    this(ushort port, RpcInterfaceSettings settings = new RpcInterfaceSettings())
    {
        super(port, settings);
    }
}

class StratumRpcAutoClient(I) : I
{
    import autointf;
    import std.traits;

protected:
    alias TId = int; // always an int
    alias TReq = StratumRpcRequest;
    alias TResp = StratumRpcResponse;
    alias AutoClient(I) = JsonRpcAutoClient!(I, TId, TReq, TResp);
    alias RPCClient = IRpcClient!(TId, TReq, TResp);
    AutoClient!I _autoClient;

public:
    this(RPCClient client, RpcInterfaceSettings settings) @safe
    {
        _autoClient = new AutoClient!I(client, settings);
    }

    pragma(inline, true)
    ReturnType!Func executeMethod(alias Func, ARGS...)(ARGS args) @safe
    {
        return _autoClient.executeMethod!(Func, ARGS)(args);
    }

    pragma(inline, true)
    @property auto client() @safe { return _autoClient.client; }

    mixin(autoImplementMethods!(I,executeMethod)());
}

///
class RawStratumRpcAutoClient(I) : StratumRpcAutoClient!I
{
    import vibe.core.stream: InputStream, OutputStream;

public:
    this(OutputStream ostream, InputStream istream) @safe
    {
        super(new RawJsonRpcClient!(int, StratumRpcRequest, StratumRpcResponse)(ostream, istream),
            new RpcInterfaceSettings());
    }
}

///
class HttpStratumRpcAutoClient(I) : StratumRpcAutoClient!I
{
public:
    this(string host) @safe
    {
        super(new HttpJsonRpcClient!(int, StratumRpcRequest, StratumRpcResponse)(host),
            new RpcInterfaceSettings());
    }
}

///
class TcpStratumRpcAutoClient(I) : StratumRpcAutoClient!I
{
public:
    this(string host, ushort port, RpcInterfaceSettings settings = new RpcInterfaceSettings()) @safe
    {
        super(new TcpJsonRpcClient!(int, StratumRpcRequest, StratumRpcResponse)(host, port, settings),
            settings);
    }
}

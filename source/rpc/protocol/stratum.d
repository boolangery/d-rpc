/**
    Stratum protocol is based on JSON-RPC 2.0.
    (although it doesn't include "jsonrpc" information in every message).
    Each message has to end with a line end character (n).
*/
module rpc.protocol.stratum;

import rpc.core;
import rpc.protocol.json;
import vibe.data.json;
import std.typecons: Nullable, nullable;


class StratumRPCRequest : JsonRPCRequest!int
{
public:
    static StratumRPCRequest make(T)(int id, string method, T params)
    {
        import vibe.data.json : serializeToJson;

        auto request = new StratumRPCRequest();
        request.id = id;
        request.method = method;
        request.params = serializeToJson!T(params);

        return request;
    }

    static StratumRPCRequest make(int id, string method)
    {
        auto request = new StratumRPCRequest();
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
    static StratumRPCRequest fromJson(Json src) @safe
    {
        StratumRPCRequest request = new StratumRPCRequest();
        request.method = src["method"].to!string;
        if (src["id"].type != Json.Type.undefined)
            request.id = src["id"].to!int;
        if (src["params"].type != Json.Type.undefined)
            request.params = src["params"].nullable;
        return request;
    }
}

class StratumRPCResponse : JsonRPCResponse!int
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
            json["error"] = serializeToJson!(const(JsonRPCError))(error.get);
        return json;
    }

    /** Strip the "jsonrpc" field.
    */
    static StratumRPCResponse fromJson(Json src) @safe
    {
        StratumRPCResponse request = new StratumRPCResponse();
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
            request.error = deserializeJson!JsonRPCError(src["error"]).nullable;
        return request;
    }
}

class RawStratumRPCServer : RawJsonRPCServer!(int, StratumRPCRequest, StratumRPCResponse)
{
    import vibe.core.stream: InputStream, OutputStream;

public:
    this(OutputStream ostream, InputStream istream) @safe
    {
        super(ostream, istream);
    }
}

class HTTPStratumRPCServer : HTTPJsonRPCServer!(int, StratumRPCRequest, StratumRPCResponse)
{
    import vibe.http.router: URLRouter;

public:
    this(URLRouter router, string path)
    {
        super(router, path);
    }
}

class TCPStratumRPCServer : TCPJsonRPCServer!(int, StratumRPCRequest, StratumRPCResponse)
{
public:
    this(ushort port, RPCInterfaceSettings settings = new RPCInterfaceSettings())
    {
        super(port, settings);
    }
}

class StratumRPCAutoClient(I) : I
{
    import autointf;
    import std.traits;

protected:
    alias TId = int; // always an int
    alias TReq = StratumRPCRequest;
    alias TResp = StratumRPCResponse;
    alias AutoClient(I) = JsonRPCAutoClient!(I, TId, TReq, TResp);
    alias RPCClient = IRPCClient!(TId, TReq, TResp);
    AutoClient!I _autoClient;

    pragma(inline, true)
    ReturnType!Func executeMethod(alias Func, ARGS...)(ARGS args) @safe
    {
        return _autoClient.executeMethod!(Func, ARGS)(args);
    }

public:
    this(RPCClient client, RPCInterfaceSettings settings) @safe
    {
        _autoClient = new AutoClient!I(client, settings);
    }

    pragma(inline, true)
    @property auto client() @safe { return _autoClient.client; }

    mixin(autoImplementMethods!(I,executeMethod)());
}

class RawStratumRPCAutoClient(I) : StratumRPCAutoClient!I
{
    import vibe.core.stream: InputStream, OutputStream;

public:
    this(OutputStream ostream, InputStream istream) @safe
    {
        super(new RawJsonRPCClient!(int, StratumRPCRequest, StratumRPCResponse)(ostream, istream),
            new RPCInterfaceSettings());
    }
}

class HTTPStratumRPCAutoClient(I) : StratumRPCAutoClient!I
{
public:
    this(string host) @safe
    {
        super(new HTTPJsonRPCClient!(int, StratumRPCRequest, StratumRPCResponse)(host),
            new RPCInterfaceSettings());
    }
}

class TCPStratumRPCAutoClient(I) : StratumRPCAutoClient!I
{
public:
    this(string host, ushort port, RPCInterfaceSettings settings = new RPCInterfaceSettings()) @safe
    {
        super(new TCPJsonRPCClient!(int, StratumRPCRequest, StratumRPCResponse)(host, port, settings),
            settings);
    }
}

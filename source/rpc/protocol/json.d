/**
    Json-Rpc 2.0 protocol implementation.

    This module has 3 entry point:
        $(UL
			$(LI `RawJsonRpcAutoClient`)
			$(LI `HttpJsonRpcAutoClient`)
			$(LI `TcpJsonRpcAutoClient`)
		)

    Copyright: © 2018 Eliott Dumeix
    License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
*/
module rpc.protocol.json;

public import rpc.core;
import std.typecons: Nullable, nullable;
import vibe.data.json;
import vibe.core.log;
import autointf : InterfaceInfo;
import std.traits : hasUDA;


/** Json-Rpc 2.0 error.
*/
class JsonRpcError
{
public:
    /// Error code
    int code;

    /// Error message
    string message;

    /// Optional json data
    @optional Json data;

    /// Default constructor.
    this() @safe nothrow {}

    /// Standard error constructor.
    this(StdCodes code)
    @safe nothrow {
        this.code = code;
        this.message = CODES_MESSAGE[this.code];
    }

    ///
    static enum StdCodes
    {
        parseError      = -32700, /// Parse error
        invalidRequest  = -32600, /// Invalid request
        methodNotFound  = -32601, /// Method not found
        invalidParams   = -32602, /// Invalid params
        internalError   = -32603  /// Internal error
    }

    ///
    private static immutable string[int] CODES_MESSAGE;

    shared static this()
    @safe {
        CODES_MESSAGE[StdCodes.parseError]     = "Parse error";
        CODES_MESSAGE[StdCodes.invalidRequest] = "Invalid Request";
        CODES_MESSAGE[StdCodes.methodNotFound] = "Method not found";
        CODES_MESSAGE[StdCodes.invalidParams]  = "Invalid params";
        CODES_MESSAGE[StdCodes.internalError]  = "Internal error";
    }
}

/** A Json-Rpc request that use TId as id type.
*/
class JsonRpcRequest(TId): IRpcRequest!TId
{
public:
    ///
    override @property TId requestId() { return id; }

    /// json rpc string
    string jsonrpc;

    /// Json rpc method
    string method;

    // id
    @optional TId id;

    // Parameters
    @optional Nullable!Json params;

    ///
    this() @safe
    {
        params = Nullable!Json.init;
    }

    /// Create a new json request.
    static JsonRpcRequest!TId make(T)(TId id, string method, T params)
    {
        import vibe.data.json : serializeToJson;

        auto request = new JsonRpcRequest!TId();
        request.id = id;
        request.method = method;
        request.params = serializeToJson!T(params);

        return request;
    }

    /// ditto
    static JsonRpcRequest!TId make(TId id, string method)
    {
        auto request = new JsonRpcRequest!TId();
        request.id = id;
        request.method = method;

        return request;
    }

    ///
    bool hasParams() @safe
    {
        return !params.isNull;
    }

    /// Convert to Json.
    Json toJson() const @safe
    {
        Json json = Json.emptyObject;
        json["jsonrpc"] = "2.0";
        json["method"] = method;
        json["id"] = id;
        if (!params.isNull)
            json["params"] = params.get;
        return json;
    }

    /// Parse from Json.
    static JsonRpcRequest fromJson(Json src) @safe
    {
        JsonRpcRequest request = new JsonRpcRequest();
        request.jsonrpc = src["jsonrpc"].to!string;
        request.method = src["method"].to!string;
        if (src["id"].type != Json.Type.undefined)
            request.id = src["id"].to!TId;
        if (src["params"].type != Json.Type.undefined)
            request.params = src["params"].nullable;
        return request;
    }

    /// Convert to a Json string.
    override string toString() const @safe
    {
        return toJson().toString();
    }

    /// Parse from a Json string.
    static JsonRpcRequest fromString(string src) @safe
    {
        return fromJson(parseJson(src));
    }
}

///
@("Test JsonRpcRequest")
unittest
{
    import vibe.data.json;

    auto r1 = new JsonRpcRequest!int();
    auto json = Json.emptyObject;
    json["foo"] = 42;

    r1.method = "foo";
    r1.toString().should == `{"method":"foo","id":0,"jsonrpc":"2.0"}`;

    auto r2 = new JsonRpcRequest!int();
    r2.method = "foo";
    r2.params = json;
    r2.toString().should == `{"params":{"foo":42},"method":"foo","id":0,"jsonrpc":"2.0"}`;

    auto r3 = deserializeJson!(JsonRpcRequest!int)(r1.toString());
    r3.id.should == r1.id;
    r3.params.should == r1.params;
    r3.method.should == r1.method;

    // string id:
    auto r10 = new JsonRpcRequest!string();
    r10.method = "foo";
    r10.id = "bar";
    r10.toString().should == `{"method":"foo","id":"bar","jsonrpc":"2.0"}`;
}

/** A Json-Rpc response with an id of type TId.
*/
class JsonRpcResponse(TId): IRpcResponse
{
public:
    ///
    string jsonrpc;

    /// id
    Nullable!TId id;

    /// Optional result.
    @optional Nullable!Json result;

    /// Optional error.
    @optional Nullable!JsonRpcError error;

    ///
    this() @safe nothrow
    {
        result = Nullable!Json.init;
        error = Nullable!JsonRpcError.init;
    }

    /// Tells if the response is an error.
    bool isError() @safe nothrow
    {
        return !error.isNull;
    }

    /// Tells if the response is in success.
    bool isSuccess() @safe nothrow
    {
        return !result.isNull;
    }

    /// Convert to Json.
    Json toJson() const @safe
    {
        Json json = Json.emptyObject;
        json["jsonrpc"] = "2.0";
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

    /// Parse from Json.
    static JsonRpcResponse fromJson(Json src) @safe
    {
        JsonRpcResponse request = new JsonRpcResponse();
        request.jsonrpc = src["jsonrpc"].to!string;
        if (src["id"].type != Json.Type.undefined)
        {
            if (src["id"].type == Json.Type.null_)
                request.id.nullify;
            else
                request.id = src["id"].to!TId;
        }
        if (src["result"].type != Json.Type.undefined)
            request.result = src["result"].nullable;
        if (src["error"].type != Json.Type.undefined)
            request.error = deserializeJson!JsonRpcError(src["error"]).nullable;
        return request;
    }

    /// Convert to Json string.
    override string toString() const @safe
    {
        return toJson().toString();
    }

    /// Parse from Json string.
    static JsonRpcResponse fromString(string src) @safe
    {
        return fromJson(parseJson(src));
    }
}

///
@("Test JsonRpcResponse")
unittest
{
    auto r1 = new JsonRpcResponse!int();
    Json json = "hello";
    r1.result = json;
    r1.id = 42;
    r1.toString().should == `{"result":"hello","id":42,"jsonrpc":"2.0"}`;

    auto error = new JsonRpcError();
    error.code = -32600;
    error.message = "Invalid Request";

    auto r2 = new JsonRpcResponse!int();
    r2.error = error;
    r2.id = 1;
    r2.toString().should == `{"error":{"code":-32600,"message":"Invalid Request"},"id":1,"jsonrpc":"2.0"}`;
}

/// Encapsulate a json-rpc error response.
class JsonRpcMethodException: RpcException
{
    import std.conv: to;

    this(JsonRpcError error) @safe
    {
        if (error.data.type == Json.Type.object)
            super(error.message ~ " (" ~ to!string(error.code) ~ "): " ~ error.data.toString());
        else
            super(error.message ~ " (" ~ to!string(error.code) ~ ")");
    }

    this(string msg) @safe
    {
        super(msg);
    }
}

/// Exception to be used inside rpc handler, to throw user defined json-rpc error.
class JsonRpcUserException: RpcException
{
    import vibe.data.json;

public:
    int code;
    Json data;

    this(T)(int code, string msg, T data) @safe
    {
        super(msg);
        this.code = code;
        this.data = serializeToJson(data);
    }
}

///
package class RawJsonRpcClient(TId,
    TReq: JsonRpcRequest!TId=JsonRpcRequest!TId,
    TResp: JsonRpcResponse!TId=JsonRpcResponse!TId) :
        RawRpcClient!(TId, TReq, TResp)
{
    import core.time : Duration;
    import vibe.data.json;
    import vibe.stream.operations: readAllUTF8;
    import vibe.core.stream: InputStream, OutputStream;

private:
    IIdGenerator!TId _idGenerator;
    TResp[TId] _pendingResponse;

public:
    this(OutputStream ostream, InputStream istream) @safe
    {
        super(ostream, istream);
        _idGenerator = new IdGenerator!TId();
    }

    /** Send a request with an auto-generated id.
        Throws:
            JSONException
    */
    TResp sendRequestAndWait(TReq request, Duration timeout = Duration.max()) @safe
    {
        request.id = _idGenerator.getNextId();
        _ostream.write(request.toString());
        return waitForResponse(request.id, timeout);
    }

    // Process the input stream once.
    override void tick() @safe
    {
        string rawJson = _istream.readAllUTF8();
        Json json = parseJson(rawJson);

        void process(Json jsonObject)
        {
            auto response = deserializeJson!TResp(jsonObject);
            _pendingResponse[response.id] = response;
        }

        // batch of commands
        if (json.type == Json.Type.array)
        {
            foreach(object; json.byValue)
            {
                process(object);
            }
        }
        else
        {
            process(json);
        }
    }

protected:
    TResp waitForResponse(TId id, Duration timeout) @safe
    {
        import std.conv: to;

        // check if response already received
        if (id in _pendingResponse)
        {
            scope(exit) _pendingResponse.remove(id);
            return _pendingResponse[id];
        }
        else
        {
            throw new RpcTimeoutException("No reponse");
        }

    }
}

/// Represents a Json rpc client.
alias IJsonRpcClient(TId, TReq: JsonRpcRequest!TId, TResp: JsonRpcResponse!TId) = IRpcClient!(TId, TReq, TResp);

/// An http json-rpc client
package alias HttpJsonRpcClient(TId,
    TReq: JsonRpcRequest!TId=JsonRpcRequest!TId,
    TResp: JsonRpcResponse!TId=JsonRpcResponse!TId) = HttpRpcClient!(TId, TReq, TResp);

///
package class TcpJsonRpcClient(TId,
    TReq: JsonRpcRequest!TId=JsonRpcRequest!TId,
    TResp: JsonRpcResponse!TId=JsonRpcResponse!TId): IJsonRpcClient!(TId, TReq, TResp)
{
    import vibe.core.net : TCPConnection, TCPListener, connectTCP;
    import vibe.stream.operations : readLine;
    import core.time;
    import std.conv: to;

private:
    string _host;
    ushort _port;
    bool _connected;
    IIdGenerator!TId _idGenerator;
    JsonRpcResponse!TId[TId] _pendingResponse;
    TCPConnection _conn;
    RpcInterfaceSettings _settings;

public:
    @property bool connected() { return _connected; }

    this(string host, ushort port, RpcInterfaceSettings settings)
    {
        _host = host;
        _port = port;
        _settings = settings;
        this.connect();
        _idGenerator = new IdGenerator!TId();
    }

    bool connect() @safe nothrow
    in {
        assert(!_connected);
    }
    do {
        try {
            _conn = connectTCP(_host, _port);
            _connected = true;
        } catch (Exception e) {
            _connected = false;
        }

        return _connected;
    }

    /// auto-generate id
    TResp sendRequestAndWait(TReq request, core.time.Duration timeout = core.time.Duration.max()) @safe
    {
        if (!_connected)
            throw new RpcNotConnectedException("tcp client not connected ! call connect() first.");

        request.id = _idGenerator.getNextId();
        logTrace("tcp send request: %s", request);
        _conn.write(request.toString() ~ _settings.linesep);

        if (_conn.waitForData(timeout)) {
            char[] raw = cast(char[]) _conn.readLine(size_t.max, _settings.linesep);
            string json = to!string(raw);
            logTrace("tcp server request response: %s", json);
            auto response = deserializeJson!TResp(json);
            return response;
        }
        else
            throw new RpcTimeoutException("waitForData timeout");
    }

    @disable void tick() @safe {}
}

/// Represents a Json rpc server.
alias IJsonRpcServer(TId,
    TReq: JsonRpcRequest!TId=JsonRpcRequest!TId,
    TResp: JsonRpcResponse!TId=JsonRpcResponse!TId) =
        IRpcServer!(TId, TReq, TResp);

///
alias JsonRpcRequestHandler(TId, TReq=JsonRpcRequest!TId, TResp=JsonRpcResponse!TId) =
    RpcRequestHandler!(TReq, TResp);

///
class RawJsonRpcServer(TId, TReq=JsonRpcRequest!TId, TResp=JsonRpcResponse!TId):
    RawRpcServer!(TId, TReq, TResp),
    IRpcServerOutput!TResp
{
    import vibe.stream.operations: readAllUTF8;
    import vibe.core.stream: InputStream, OutputStream;

    alias RequestHandler = JsonRpcRequestHandler!(TId, TReq, TResp);

private:
    RequestHandler[string] _requestHandler;

public:
    this(OutputStream ostream, InputStream istream) @safe
    {
        super(ostream, istream);
    }

    void registerRequestHandler(string method, RequestHandler handler)
    {
        _requestHandler[method] = handler;
    }

    void sendResponse(TResp reponse) @safe
    {
        _ostream.write(reponse.toString());
    }

    void tick() @safe
    {
        string rawJson = _istream.readAllUTF8();
        Json json = parseJson(rawJson);

        void process(Json jsonObject)
        {
            auto request = deserializeJson!TReq(jsonObject);
            if (request.method in _requestHandler)
            {
                _requestHandler[request.method](request, this);
            }
        }

        // batch of commands
        if (json.type == Json.Type.array)
        {
            foreach(object; json.byValue)
            {
                process(object);
            }
        }
        else
        {
            process(json);
        }
    }
}

/// An http json-rpc client
class HttpJsonRpcServer(TId,
    TReq: JsonRpcRequest!TId=JsonRpcRequest!TId,
    TResp: JsonRpcResponse!TId=JsonRpcResponse!TId):
        HttpRpcServer!(TId, TReq, TResp)
{
    import vibe.data.json: JSONException;
    import vibe.http.router: URLRouter;

    this(URLRouter router, string path)
    {
        super(router, path);
    }

    override RpcRespHandler createReponseHandler(HTTPServerResponse res)
    @safe nothrow {
        return new class RpcRespHandler
        {
            override void sendResponse(TResp reponse) @safe nothrow
            {
                logTrace("post request response: %s", reponse);
                try {
                    res.writeJsonBody(reponse.toJson());
                } catch (Exception e) {
                    logCritical("unable to send response: %s", e.msg);
                    // TODO: add a delgate to allow the user to handle error
                }
            }
        };
    }

    @disable void tick() @safe {}

    protected override TResp buildResponseFromException(Exception e) @safe nothrow
    {
        auto response = new TResp();
        if (is(typeof(e) == JSONException))
        {
            response.error = new JsonRpcError(JsonRpcError.StdCodes.parseError);
            return response;
        }
        else
        {
            response.error = new JsonRpcError(JsonRpcError.StdCodes.internalError);
            return response;
        }
    }

    void registerInterface(I)(I instance, RpcInterfaceSettings settings = null)
    {
        import std.algorithm : filter, map, all;
        import std.array : array;
        import std.range : front;
        import vibe.internal.meta.uda : findFirstUDA;

        alias Info = InterfaceInfo!I;

        foreach (i, Func; Info.Methods) {
            enum methodNameAtt = findFirstUDA!(RpcMethodAttribute, Func);
            enum smethod = Info.staticMethods[i];

            auto handler = jsonRpcMethodHandler!(TId, TReq, TResp, Func, i, I)(instance);

            // select rpc name (attribute or function name):
            static if (methodNameAtt.found)
                this.registerRequestHandler(methodNameAtt.value.method, handler);
            else
                this.registerRequestHandler(smethod.name, handler);

        }
    }
}

///
class TcpJsonRpcServer(TId,
    TReq: JsonRpcRequest!TId=JsonRpcRequest!TId,
    TResp: JsonRpcResponse!TId=JsonRpcResponse!TId): IJsonRpcServer!(TId, TReq, TResp)
{
    import vibe.core.net : TCPConnection, TCPListener, listenTCP;
    import vibe.stream.operations : readLine;
    import std.conv : to;

private:
    class ResponseWriter: JsonRpcRespHandler
    {
        private TCPConnection _conn;

        this(TCPConnection conn)
        {
            _conn = conn;
        }

        void sendResponse(TResp reponse)
        @safe {
            logTrace("tcp request response: %s", reponse);
            try {
                _conn.write(reponse.toString() ~ _settings.linesep);
            } catch (Exception e) {
                logTrace("unable to send response: %s", e.msg);
                // TODO: add a delgate to allow the user to handle error
            }
        }
    }

    class TCPClient
    {
    private:
        TCPConnection _connection;
        JsonRpcRequestHandler!(TId, TReq, TResp)[string] _requestHandler;

    public /*properties*/:
        @property auto conn() { return _connection; }

    public:
        this(TCPConnection connection)
        {
            _connection = connection;
        }

        void run() @safe nothrow
        {
            try {
                auto writer = new ResponseWriter(_connection);

                while (!_connection.empty) {
                    auto json = cast(const(char)[])_connection.readLine(size_t.max, _settings.linesep);
                    logTrace("tcp request received: %s", json);

                    this.process(json.to!string, writer);
                }
            } catch (Exception e) {
                logError("Failed to read from client: %s", e.msg);
                if (_settings !is null)
                    _settings.errorHandler(e);
            }
        }

        void process(string data, JsonRpcRespHandler respHandler) @safe
        {
            Json json = parseJson(data);

            void process(Json jsonObject)
            {
                auto request = deserializeJson!TReq(jsonObject);
                if (request.method in _requestHandler)
                {
                    _requestHandler[request.method](request, respHandler);
                }
            }

            // batch of commands
            if (json.type == Json.Type.array)
            {
                foreach(object; json.byValue)
                {
                    process(object);
                }
            }
            else
            {
                process(json);
            }
        }

        void registerRequestHandler(string method, JsonRpcRequestHandler!(TId, TReq, TResp) handler) @safe nothrow
        {
            _requestHandler[method] = handler;
        }

        void registerInterface(I)(I instance) @safe nothrow
        {
            import std.algorithm : filter, map, all;
            import std.array : array;
            import std.range : front;

            alias Info = InterfaceInfo!I;

            foreach (i, Func; Info.Methods) {
                enum smethod = Info.staticMethods[i];

                // normal handler
                auto handler = jsonRpcMethodHandler!(TId, TReq, TResp, Func, i)(instance);

                this.registerRequestHandler(smethod.name, handler);
            }

        }
    }

    alias FactoryDel(I) = I delegate(TCPConnection);
    alias NewClientDel = void delegate(TCPClient) @safe nothrow;
    alias JsonRpcRespHandler = IRpcServerOutput!TResp;
    JsonRpcRequestHandler!(TId, TReq, TResp)[string] _requestHandler;
    RpcInterfaceSettings _settings;
    NewClientDel[] _newClientDelegates;

public:
    this(ushort port, RpcInterfaceSettings settings = new RpcInterfaceSettings())
    {
        _settings = settings;

        listenTCP(port, (conn) @safe nothrow {
            logTrace("new client: %s", conn);
            auto client = new TCPClient(conn);

            foreach(newClientDel; _newClientDelegates)
                    newClientDel(client);

            client.run();

            conn.close();
        });
    }

    void registerInterface(I)(I instance)
    {
        _newClientDelegates ~= (client) @safe nothrow {
            client.registerInterface!I(instance);
        };
    }

    void registerInterface(I)(FactoryDel!I factory)
    {
        _newClientDelegates ~= (client) {
            // instanciate an API for each client:
            I instance = factory(client.conn);

            client.registerInterface!I(instance);
        };
    }

    @disable void tick() @safe {}

    void registerRequestHandler(string method, JsonRpcRequestHandler!(TId, TReq, TResp) handler)
    {
        _requestHandler[method] = handler;
    }

    void process(string data, JsonRpcRespHandler respHandler)
    {
        Json json = parseJson(data);

        void process(Json jsonObject)
        {
            auto request = deserializeJson!TReq(jsonObject);
            if (request.method in _requestHandler)
            {
                _requestHandler[request.method](request, respHandler);
            }
        }

        // batch of commands
        if (json.type == Json.Type.array)
        {
            foreach(object; json.byValue)
            {
                process(object);
            }
        }
        else
        {
            process(json);
        }
    }
}

/// Return an handler to match a json-rpc request on an interface method.
package JsonRpcRequestHandler!(TId, TReq, TResp) jsonRpcMethodHandler(TId, TReq, TResp, alias Func, size_t n, T)(T inst)
{
    import std.traits;
    import std.meta : AliasSeq;
    import std.string : format;
    import vibe.utils.string : sanitizeUTF8;
    import vibe.internal.meta.funcattr : IsAttributedParameter, computeAttributedParameterCtx;
    import vibe.internal.meta.traits : derivedMethod;
    import vibe.internal.meta.uda : findFirstUDA;

    enum Method = __traits(identifier, Func);
    alias PTypes = ParameterTypeTuple!Func;
    alias PDefaults = ParameterDefaultValueTuple!Func;
    alias CFuncRaw = derivedMethod!(T, Func);
    static if (AliasSeq!(CFuncRaw).length > 0) alias CFunc = CFuncRaw;
    else alias CFunc = Func;
    alias RT = ReturnType!(FunctionTypeOf!Func);
    static const sroute = InterfaceInfo!T.staticMethods[n];
    enum objectParamAtt = findFirstUDA!(RpcMethodObjectParams, Func);

    void handler(TReq req, IRpcServerOutput!TResp serv) @safe
    {
        auto response = new TResp();
        response.id = req.id;
        PTypes params;

        // build a custom json error object tobe sent in json rpc error response.
        Json buildErrorData(string details)
        @safe {
            auto json = Json.emptyObject;
            json["details"] = details;
            json["request"] = req.toJson();
            return json;
        }

        try {
            // check params consistency beetween rpc-request and function parameters
            static if (PTypes.length > 1 && !objectParamAtt.found)
            {
                // we expect a json array
                if (req.params.type != Json.Type.array)
                {
                    response.error = new JsonRpcError(JsonRpcError.StdCodes.invalidParams);
                    response.error.data = buildErrorData("Expected a json array for params");
                    serv.sendResponse(response);
                    return;
                }
                // req.params is a json array
                else if (req.params.length != PTypes.length)
                {
                    response.error = new JsonRpcError(JsonRpcError.StdCodes.invalidParams);
                    response.error.data = buildErrorData("Missing params");
                    serv.sendResponse(response);
                    return;
                }
            }
            else if (PTypes.length > 1 && objectParamAtt.found)
            {
                // in object mode, check param count
                if (req.params.type == Json.Type.object)
                {
                    if (req.params.length != PTypes.length)
                    {
                        response.error = new JsonRpcError(JsonRpcError.StdCodes.invalidParams);
                        response.error.data = buildErrorData("Missing entry in params");
                        serv.sendResponse(response);
                        return;
                    }
                }
            }

            foreach (i, PT; PTypes) {
                enum sparam = sroute.parameters[i];

                static if (!objectParamAtt.found)
                {
                    enum pname = sparam.name;
                    auto fieldname = sparam.name;

                    params[i] = deserializeJson!PT(req.params[i]);
                }
                else
                {
                    enum pname = sparam.name;

                    if (pname in objectParamAtt.value.names)
                        params[i] = deserializeJson!PT(req.params[objectParamAtt.value.names[pname]]);
                    else
                        params[i] = deserializeJson!PT(req.params[pname]);
                }
            }
        } catch (Exception e) {
            // handleException(e, HTTPStatus.badRequest);
            return;
        }

        try {
            import vibe.internal.meta.funcattr;

            static if (!__traits(compiles, () @safe { __traits(getMember, inst, Method)(params); }))
                pragma(msg, "Non-@safe methods are deprecated in REST interfaces - Mark "~T.stringof~"."~Method~" as @safe.");

            static if (is(RT == void)) {
                // TODO: return null
            } else {
                auto ret = () @trusted { return __traits(getMember, inst, Method)(params); } (); // TODO: remove after deprecation period

                static if (!__traits(compiles, () @safe { evaluateOutputModifiers!Func(ret, req, res); } ()))
                    pragma(msg, "Non-@safe @after evaluators are deprecated - annotate @after evaluator function for "~T.stringof~"."~Method~" as @safe.");

                static if (!__traits(compiles, () @safe { res.writeJsonBody(ret); }))
                    pragma(msg, "Non-@safe serialization of REST return types deprecated - ensure that "~RT.stringof~" is safely serializable.");
                () @trusted {
                    // build reponse
                    response.id = req.id;
                    response.result = serializeToJson(ret);
                    serv.sendResponse(response);
                }();
            }
        }
        // catch user-defined json-rpc errors.
        catch (JsonRpcUserException e)
        {
            response.error = new JsonRpcError();
            response.error.code = e.code;
            response.error.message = e.msg;
            response.error.data = e.data;
            serv.sendResponse(response);
            return;
        }
        catch (Exception e) {
            response.error = new JsonRpcError();
            response.error.code = 0;
            response.error.message = e.msg;
            serv.sendResponse(response);
            return;
        }
    }

    return &handler;
}

/** Base class for creating a Json RPC automatic client.
*/
package class JsonRpcAutoClient(I,
    TId,
    TReq: JsonRpcRequest!TId=JsonRpcRequest!TId,
    TResp: JsonRpcResponse!TId=JsonRpcResponse!TId)
{
    import std.traits;

protected:
    IRpcClient!(TId, TReq, TResp) _client;
    RpcInterfaceSettings _settings;

    ReturnType!Func executeMethod(alias Func, ARGS...)(ARGS args) @safe
    {
        import vibe.internal.meta.uda : findFirstUDA;
        import std.traits;
        import std.array : appender;
        import core.time;
        import vibe.data.json;

        // retrieve some compile time informations
        // alias Info  = RpcInterface!I;
        alias RT    = ReturnType!Func;
        alias PTT   = ParameterTypeTuple!Func;
        alias PTN   = ParameterIdentifierTuple!Func;

        enum objectParamAtt = findFirstUDA!(RpcMethodObjectParams, Func);
        enum methodNameAtt = findFirstUDA!(RpcMethodAttribute, Func);
        // parameters are rendered as array if annotated with @rpcArrayParams
        enum bool paramsAsArray = hasRpcArrayParams!Func || (PTT.length > 1);

        try
        {
            auto jsonParams = Json.undefined;

            // Render params as unique param or array
            static if (!objectParamAtt.found)
            {
                // if several params, then build an a json array
                static if (paramsAsArray)
                    jsonParams = Json.emptyArray;

                // fill the json array or the unique value
                static foreach (i, PT; PTT) {
                    static if (paramsAsArray)
                        jsonParams.appendArrayElement(serializeToJson(args[i]));
                    else
                        jsonParams = serializeToJson(args[i]);
                }
            }
            // render params as a json object by using the param name
            // for the key or the uda if exists
            else
            {
                jsonParams = Json.emptyObject;

                // fill object
                static foreach (i, PT; PTT) {
                    if (PTN[i] in objectParamAtt.value.names)
                        jsonParams[objectParamAtt.value.names[PTN[i]]] = serializeToJson(args[i]);
                    else
                        jsonParams[PTN[i]] = serializeToJson(args[i]);
                }
            }


            static if (!is(RT == void))
                RT jret;

            // create a json-rpc request
            auto request = new TReq();

            static if (methodNameAtt.found)
                request.method = methodNameAtt.value.method;
            else
                request.method = __traits(identifier, Func);

            request.params = jsonParams; // set rpc call params

            auto response = _client.sendRequestAndWait(request, _settings.responseTimeout); // send packet and wait

            if (response.isError())
            {
                throw new JsonRpcMethodException(response.error.get);
            }

            // void return type
            static if (is(RT == void))
            {

            }
            else
            {
                return deserializeJson!RT(response.result.get);
            }
        }
        catch (JSONException e)
        {
            throw new RpcParsingException(e.msg, e);
        }
        catch (Exception e)
        {
            throw new RpcException(e.msg, e);
        }
    }

public:
    this(IRpcClient!(TId, TReq, TResp) client, RpcInterfaceSettings settings)
    {
        _client = client;
        _settings = settings;
    }

    @property auto client() @safe { return _client; }
}

///
package class JsonRpcAutoAttributeClient(I) : I
{
    import autointf;

private:
    // compile-time
    // Extract RPC id type from attribute:
    static if (hasUDA!(I, RpcIdTypeAttribute!int))
        alias TId = int;
    else static if (hasUDA!(I, RpcIdTypeAttribute!string))
        alias TId = string;
    else
        alias TId = int;

protected:
    alias TReq = JsonRpcRequest!TId;
    alias TResp = JsonRpcResponse!TId;
    alias AutoClient(I) = JsonRpcAutoClient!(I, TId, TReq, TResp);
    alias RpcClient = IRpcClient!(TId, TReq, TResp);
    AutoClient!I _autoClient;

    pragma(inline, true)
    ReturnType!Func executeMethod(alias Func, ARGS...)(ARGS args) @safe
    {
        return _autoClient.executeMethod!(Func, ARGS)(args);
    }

public:
    this(RpcClient client, RpcInterfaceSettings settings) @safe
    {
        _autoClient = new AutoClient!I(client, settings);
    }

    pragma(inline, true)
    @property auto client() @safe { return _autoClient.client; }

    mixin(autoImplementMethods!(I, executeMethod)());
}

/** Used to create an auto-implemented raw Rpc client from an interface.

    ---
    auto input = `{"jsonrpc":"2.0","id":2,"result":` ~ to!string(getValue!int) ~ "}";
    auto istream = createMemoryStream(input.toBytes());
    auto ostream = createMemoryOutputStream();

    auto api = new RawJsonRpcAutoClient!IAPI(ostream, istream);

    // test the client side:
    // inputstream not processed: timeout
    api.add(1, 2).shouldThrowExactly!RpcException;
    ostream.str.should.be == JsonRpcRequest!int.make(1, "add", [1, 2]).toString();

    // process input stream
    api.client.tick();

    // client must send a reponse
    api.add(1, 2).should.be == getValue!int;
    ---
*/
class RawJsonRpcAutoClient(I) : JsonRpcAutoAttributeClient!I
{
    import vibe.core.stream: InputStream, OutputStream;

public:
    this(OutputStream ostream, InputStream istream, RpcInterfaceSettings settings = new RpcInterfaceSettings()) @safe
    {
        super(new RawJsonRpcClient!TId(ostream, istream), settings);
    }
}

/** Used to create an auto-implemented Http Rpc client from an interface.

    ---
    interface IAPI
    {
        void send(string data);
    }

    auto client = new HttpJsonRpcAutoClient!IAPI("http://127.0.0.1:8080/rpc_2");
    client.send("data");
    ---
*/
class HttpJsonRpcAutoClient(I) : JsonRpcAutoAttributeClient!I
{
public:
    this(string host, RpcInterfaceSettings settings = new RpcInterfaceSettings()) @safe
    {
        super(new HttpJsonRpcClient!TId(host), settings);
    }
}

/** Used to create an auto-implemented Tcp Rpc client from an interface.

    ---
    interface IAPI
    {
        void send(string data);
    }

    auto client = new TcpJsonRpcAutoClient!IAPI("http://127.0.0.1:8080/rpc_2");
    client.send("data");
    ---
*/
class TcpJsonRpcAutoClient(I) : JsonRpcAutoAttributeClient!I
{
public:
    this(string host, ushort port, RpcInterfaceSettings settings = new RpcInterfaceSettings()) @safe
    {
        super(new TcpJsonRpcClient!TId(host, port, settings), settings);
    }
}

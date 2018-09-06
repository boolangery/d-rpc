/**
	Json-Rpc 2.0 implementation.

	Copyright: © 2018 Eliott Dumeix
	License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
*/
module rpc.protocol.json;

import rpc.core;
import std.typecons: Nullable, nullable;
import vibe.data.json;
import vibe.core.stream: OutputStream;
import vibe.core.log;

import autointf : InterfaceInfo;


/**
    Json-Rpc 2.0 error.
*/
class JsonRpcError
{
    int code;
    string message;
    @optional Json data;

    /// Default constructor.
    this() @safe nothrow {}

    /// Standard error constructor.
    this(StdCodes code)
    @safe nothrow {
        this.code = code;
        this.message = CODES_MESSAGE[this.code];
    }

    static enum StdCodes
    {
        parseError      = -32700,
        invalidRequest  = -32600,
        methodNotFound  = -32601,
        invalidParams   = -32602,
        internalError   = -32603
    }

    private static immutable string[int] CODES_MESSAGE;

    static this()
    @safe {
        CODES_MESSAGE[StdCodes.parseError]     = "Parse error";
        CODES_MESSAGE[StdCodes.invalidRequest] = "Invalid Request";
        CODES_MESSAGE[StdCodes.methodNotFound] = "Method not found";
        CODES_MESSAGE[StdCodes.invalidParams]  = "Invalid params";
        CODES_MESSAGE[StdCodes.internalError]  = "Internal error";
    }
}

/**
    Json-Rpc request.

    Template_Params:
		TId = The type used to identify rpc request.
*/
class JsonRpcRequest(TId): IRpcRequest!TId
{
    @property TId requestId() { return id; }
    string jsonrpc;
    string method;
    @optional TId id;
    @optional Nullable!Json params;

    this() @safe
    {
        params = Nullable!Json.init;
    }

    static JsonRpcRequest!TId make(T)(TId id, string method, T params)
    {
        import vibe.data.json : serializeToJson;

        auto request = new JsonRpcRequest!TId();
        request.id = id;
        request.method = method;
        request.params = serializeToJson!T(params);

        return request;
    }

    static JsonRpcRequest!TId make(TId id, string method)
    {
        import vibe.data.json : serializeToJson;

        auto request = new JsonRpcRequest!TId();
        request.id = id;
        request.method = method;

        return request;
    }

    bool hasParams() @safe
    {
        return !params.isNull;
    }

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

    override string toString() const @safe
    {
        return toJson().toString();
    }


    static JsonRpcRequest fromString(string src) @safe
    {
        return fromJson(parseJson(src));
    }
}

@("Test JsonRpcRequest")
unittest
{
    import vibe.data.json;

    auto r1 = new JsonRpcRequest!int();
    auto json = Json.emptyObject;
    json["foo"] = 42;

    r1.method = "foo";
    assert(`{"jsonrpc":"2.0","id":0,"method":"foo"}` == r1.toString());

    auto r2 = new JsonRpcRequest!int();
    r2.method = "foo";
    r2.params = json;
    assert(`{"jsonrpc":"2.0","id":0,"method":"foo","params":{"foo":42}}` == r2.toString());

    auto r3 = deserializeJson!(JsonRpcRequest!int)(r1.toString());
    assert(r3.id == r1.id);
    assert(r3.params == r1.params);
    assert(r3.method == r1.method);

    // string id:
    auto r10 = new JsonRpcRequest!string();
    r10.method = "foo";
    r10.id = "bar";
    assert(`{"jsonrpc":"2.0","id":"bar","method":"foo"}` == r10.toString());
}

/**
    Json-Rpc response.

    Template_Params:
		TId = The type used to identify rpc request.
*/
class JsonRpcResponse(TId): IRpcResponse
{
    string jsonrpc;
    Nullable!TId id;
    @optional Nullable!Json result;
    @optional Nullable!JsonRpcError error;

    this()
    @safe nothrow {
        result = Nullable!Json.init;
        error = Nullable!JsonRpcError.init;
    }

    bool isError()
    @safe nothrow {
        return !error.isNull;
    }

    bool isSuccess()
    @safe nothrow {
        return !result.isNull;
    }

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

    override string toString() const @safe
    {
        return toJson().toString();
    }

    static JsonRpcResponse fromString(string src) @safe
    {
        return fromJson(parseJson(src));
    }
}

@("Test JsonRpcResponse")
unittest
{
    auto r1 = new JsonRpcResponse!int();
    Json json = "hello";
    r1.result = json;
    r1.id = 42;
    assert(`{"jsonrpc":"2.0","result":"hello","id":42}` == r1.toString());

    auto error = new JsonRpcError();
    error.code = -32600;
    error.message = "Invalid Request";

    auto r2 = new JsonRpcResponse!int();
    r2.error = error;
    r2.id = 1;
    assert(`{"jsonrpc":"2.0","id":1,"error":{"message":"Invalid Request","code":-32600}}` == r2.toString());
}


/// Encapsulate a json-rpc error response.
class JsonRpcMethodException: RpcException
{
    import std.conv: to;

    this(JsonRpcError error)
    @safe {
        if (error.data.type == Json.Type.object)
            super(error.message ~ " (" ~ to!string(error.code) ~ "): " ~ error.data.toString());
        else
            super(error.message ~ " (" ~ to!string(error.code) ~ ")");
    }

    this(string msg)
    @safe {
        super(msg);
    }
}

/// Exception to be used inside rpc handler, to throw user defined json-rpc error.
class JsonRpcUserException: RpcException
{
    import vibe.data.json;

    int code;
    public Json data;

    this(T)(int code, string msg, T data)
    @safe{
        super(msg);
        this.code = code;
        this.data = serializeToJson(data);
    }
}


// ////////////////////////////////////////////////////////////////////////////
// Client                                                                    //
// ////////////////////////////////////////////////////////////////////////////
class RawJsonRpcClient(TId): RawRpcClient!(TId, JsonRpcRequest!TId, JsonRpcResponse!TId)
{
    import vibe.data.json;
    import vibe.stream.operations: readAllUTF8;

    private IRpcIdGenerator!TId _idGenerator;
    private JsonRpcResponse!TId[TId] _pendingResponse;

    this(OutputStream ostream, InputStream istream) @safe
    {
        super(ostream, istream);
        _idGenerator = new BasicIdGenerator!TId();
    }

    /** Send a request with an auto-generated id.
        Throws:
            JSONException
    */
    JsonRpcResponse!TId sendRequestAndWait(JsonRpcRequest!TId request, Duration timeout = Duration.max())
    @safe {
        request.id = _idGenerator.getNextId();
        _ostream.write(request.toString());
        return waitForResponse(request.id, timeout);
    }

    protected JsonRpcResponse!TId waitForResponse(TId id, Duration timeout) @safe
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

    // Process the input stream once.
    void tick() @safe
    {
        string rawJson = _istream.readAllUTF8();
        Json json = parseJson(rawJson);

        void process(Json jsonObject)
        {
            auto response = deserializeJson!(JsonRpcResponse!TId)(jsonObject);
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
}

alias IJsonRpcClient(TId) = IRpcClient!(TId, JsonRpcRequest!TId, JsonRpcResponse!TId);

/// An http json-rpc client
alias HttpJsonRpcClient(TId) = HttpRpcClient!(TId, JsonRpcRequest!TId, JsonRpcResponse!TId);

class TcpJsonRpcClient(TId): IJsonRpcClient!TId
{
    import vibe.core.net : TCPConnection, TCPListener, connectTCP;
    import vibe.stream.operations : readLine;
    import core.time;
    import std.conv: to;

    private string _host;
    private ushort _port;
    private bool _connected;
    private IRpcIdGenerator!TId _idGenerator;
    private JsonRpcResponse!TId[TId] _pendingResponse;
    private TCPConnection _conn;

    @property bool connected() { return _connected; }

    this(string host, ushort port)
    {
        _host = host;
        _port = port;
        this.connect();
        _idGenerator = new BasicIdGenerator!TId();
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
    JsonRpcResponse!TId sendRequestAndWait(JsonRpcRequest!TId request, core.time.Duration timeout = core.time.Duration.max())
    @safe {
        if (!_connected)
            throw new RpcNotConnectedException("tcp client not connected ! call connect() first.");

        request.id = _idGenerator.getNextId();
        logTrace("tcp send request: %s", request);
        _conn.write(request.toString() ~ "\r\n");

        if (_conn.waitForData(timeout)) {
            char[] raw = cast(char[]) _conn.readLine();
            string json = to!string(raw);
            logTrace("tcp server request response: %s", json);
            auto response = deserializeJson!(JsonRpcResponse!TId)(json);
            return response;
        }
        else
            throw new RpcTimeoutException("waitForData timeout");
    }

    void process(string data)
    @safe {

    }

    void tick() @safe {}
}

// ////////////////////////////////////////////////////////////////////////////
// Server                                                                    //
// ////////////////////////////////////////////////////////////////////////////
alias IJsonRpcServer(TId) = IRpcServer!(TId, JsonRpcRequest!TId, JsonRpcResponse!TId);

alias JsonRpcRequestHandler(TId) = RpcRequestHandler!(JsonRpcRequest!TId, JsonRpcResponse!TId);

class RawJsonRpcServer(TId): RawRpcServer!(TId, JsonRpcRequest!TId, JsonRpcResponse!TId),
    IRpcServerOutput!(JsonRpcResponse!TId)
{
    import vibe.stream.operations: readAllUTF8;

    private JsonRpcRequestHandler!TId[string] _requestHandler;

    this(OutputStream ostream, InputStream istream) @safe
    {
        super(ostream, istream);
    }

    void registerRequestHandler(string method, JsonRpcRequestHandler!TId handler)
    {
        _requestHandler[method] = handler;
    }

    void sendResponse(JsonRpcResponse!TId reponse)
    @safe {
        _ostream.write(reponse.toString());
    }

    void tick()
    @safe {
        string rawJson = _istream.readAllUTF8();
        Json json = parseJson(rawJson);

        void process(Json jsonObject)
        {
            auto request = deserializeJson!(JsonRpcRequest!TId)(jsonObject);
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

/**
    An http json-rpc server.

    Template_Params:
	    TId = The type to use for request and response json-rpc id.
*/

/// An http json-rpc client
class JsonRpcHTTPServer(TId): HttpRpcServer!(TId, JsonRpcRequest!TId, JsonRpcResponse!TId)
{
    import vibe.data.json: JSONException;
    import vibe.http.router: URLRouter;

    this(URLRouter router, string path)
    {
        super(router, path);
    }

    void tick() @safe {}

    protected override JsonRpcResponse!TId buildResponseFromException(Exception e) @safe nothrow
    {
        auto response = new JsonRpcResponse!TId();
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
        InterfaceInfo!I* info = new Info();

        foreach (i, ovrld; Info.SubInterfaceFunctions) {
            enum fname = __traits(identifier, Info.SubInterfaceFunctions[i]);
            alias R = ReturnType!ovrld;

            static if (isInstanceOf!(Collection, R)) {
                auto ret = __traits(getMember, instance, fname)(R.ParentIDs.init);
                router.registerRestInterface!(R.Interface)(ret.m_interface, info.subInterfaces[i].settings);
            } else {
                auto ret = __traits(getMember, instance, fname)();
                router.registerRestInterface!R(ret, info.subInterfaces[i].settings);
            }
        }

        foreach (i, Func; Info.Methods) {
            enum methodNameAtt = findFirstUDA!(RpcMethodAttribute, Func);
            enum smethod = Info.staticMethods[i];

            auto handler = jsonRpcMethodHandler!(TId, Func, i, I)(instance, *info);

            // select rpc name (attribute or function name):
            static if (methodNameAtt.found)
                this.registerRequestHandler(methodNameAtt.value.method, handler);
            else
                this.registerRequestHandler(smethod.name, handler);

        }
    }
}

class JsonRpcTCPServer(TId): IJsonRpcServer!TId
{
    import vibe.core.net : TCPConnection, TCPListener, listenTCP;
    import vibe.stream.operations : readLine;

    private alias JsonRpcRespHandler = IRpcServerOutput!(JsonRpcResponse!TId);

    private JsonRpcRequestHandler!TId[string] _requestHandler;

    private class ResponseWriter: JsonRpcRespHandler
    {
        private TCPConnection _conn;

        this(TCPConnection conn)
        {
            _conn = conn;
        }

        void sendResponse(JsonRpcResponse!TId reponse)
        @safe {
            logTrace("tcp request response: %s", reponse);
            try {
                _conn.write(reponse.toString() ~ "\r\n");
            } catch (Exception e) {
                logTrace("unable to send response: %s", e.msg);
                // TODO: add a delgate to allow the user to handle error
            }
        }
    }

    this(ushort port)
    {
        listenTCP(port, (conn) {
            logTrace("new client: %s", conn);
            try {

                auto writer = new ResponseWriter(conn);

                while (!conn.empty) {
                    auto json = cast(const(char)[])conn.readLine();
                    logTrace("tcp request received: %s", json);


                    this.process(cast(string) json, writer);
                }
            } catch (Exception e) {
                logError("Failed to read from client: %s", e.msg);
            }

            conn.close();
        });
    }

    void registerInterface(I)(I instance, RpcInterfaceSettings settings = null)
    {
        import std.algorithm : filter, map, all;
        import std.array : array;
        import std.range : front;

        alias Info = InterfaceInfo!I;
        InterfaceInfo!I* info = new Info();

        foreach (i, Func; Info.Methods) {
            enum smethod = Info.staticMethods[i];

            // normal handler
            auto handler = jsonRpcMethodHandler!(TId, Func, i)(instance, *info);

            this.registerRequestHandler(smethod.name, handler);
        }

    }

    public void tick() @safe {}

    void registerRequestHandler(string method, JsonRpcRequestHandler!TId handler)
    {
        _requestHandler[method] = handler;
    }


    void process(string data, JsonRpcRespHandler respHandler)
    {
        Json json = parseJson(data);

        void process(Json jsonObject)
        {
            auto request = deserializeJson!(JsonRpcRequest!TId)(jsonObject);
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
public JsonRpcRequestHandler!TId jsonRpcMethodHandler(TId, alias Func, size_t n, T)(T inst, ref InterfaceInfo!T intf)
{
    import std.traits;
    import std.meta : AliasSeq;
    import std.string : format;
    import vibe.utils.string : sanitizeUTF8;
    import vibe.internal.meta.funcattr : IsAttributedParameter, computeAttributedParameterCtx;
    import vibe.internal.meta.traits : derivedMethod;

    enum Method = __traits(identifier, Func);
    alias PTypes = ParameterTypeTuple!Func;
    alias PDefaults = ParameterDefaultValueTuple!Func;
    alias CFuncRaw = derivedMethod!(T, Func);
    static if (AliasSeq!(CFuncRaw).length > 0) alias CFunc = CFuncRaw;
    else alias CFunc = Func;
    alias RT = ReturnType!(FunctionTypeOf!Func);
    static const sroute = InterfaceInfo!T.staticMethods[n];
    auto method = intf.methods[n];

    void handler(JsonRpcRequest!TId req, IRpcServerOutput!(JsonRpcResponse!TId) serv)
    @safe {
        auto response = new JsonRpcResponse!TId();
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
            if (PTypes.length > 1)
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

            foreach (i, PT; PTypes) {
                enum sparam = sroute.parameters[i];

                enum pname = sparam.name;
                auto fieldname = sparam.name;
                static if (isInstanceOf!(Nullable, PT)) PT v;
                else Nullable!PT v;

                v = deserializeJson!PT(req.params[i]);

                params[i] = v;
            }
        } catch (Exception e) {
            //handleException(e, HTTPStatus.badRequest);
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
            //returnHeaders();
            //handleException(e, HTTPStatus.internalServerError);
            response.error = new JsonRpcError();
            response.error.code = 0;
            response.error.message = e.msg;
            serv.sendResponse(response);
            return;
        }
    }

    return &handler;
}

class JsonRpcSettings
{
    Duration responseTimeout = 500.msecs;
}

abstract class JsonRpcAutoClient(I) : I
{
    import std.traits : hasUDA;

    private:
        // The json rpc id type to use: string or int
        static if (hasUDA!(I, RpcIdTypeAttribute!int))
            alias TId = int;
        else static if (hasUDA!(I, RpcIdTypeAttribute!string))
            alias TId = string;
        else
            alias TId = int;

    protected:
        IRpcClient!(TId, JsonRpcRequest!TId, JsonRpcResponse!TId) _client;
        JsonRpcSettings _settings;

        RT executeMethod(I, RT, int n, ARGS...)(ref InterfaceInfo!I info, ARGS args) @safe
        {
            import vibe.internal.meta.uda : findFirstUDA;
            import std.traits;
            import std.array : appender;
            import core.time;
            import vibe.data.json;

            // retrieve some compile time informations
            // alias Info  = RpcInterface!I;
            alias Func  = info.Methods[n];
            alias RT    = ReturnType!Func;
            alias PTT   = ParameterTypeTuple!Func;
            enum sroute = info.staticMethods[n];
            auto method = info.methods[n];

            enum objectParamAtt = findFirstUDA!(RpcMethodObjectParams, Func);
            enum methodNameAtt = findFirstUDA!(RpcMethodAttribute, Func);

            try
            {
                auto jsonParams = Json.undefined;

                // Render params as unique param or array
                static if (!objectParamAtt.found)
                {
                    // if several params, then build an a json array
                    if (PTT.length > 1)
                        jsonParams = Json.emptyArray;

                    // fill the json array or the unique value
                    foreach (i, PT; PTT) {
                        if (PTT.length > 1)
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
                    foreach (i, PT; PTT) {
                        if (sroute.parameters[i].name in objectParamAtt.value.names)
                            jsonParams[objectParamAtt.value.names[sroute.parameters[i].name]] = serializeToJson(args[i]);
                        else
                            jsonParams[sroute.parameters[i].name] = serializeToJson(args[i]);
                    }
                }


                static if (!is(RT == void))
                    RT jret;

                // create a json-rpc request
                auto request = new JsonRpcRequest!TId();
                static if (methodNameAtt.found)
                    request.method = methodNameAtt.value.method;
                else
                    request.method = method.name;
                request.params = jsonParams; // set rpc call params

                auto response = _client.sendRequestAndWait(request, _settings.responseTimeout); // send packet and wait

                if (response.isError())
                {
                    throw new JsonRpcMethodException(response.error);
                }

                // void return type
                static if (is(RT == void))
                {

                }
                else
                {
                    return deserializeJson!RT(response.result);
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
        @property auto client() @safe { return _client; }

    // mixin(autoImplementMethods!I());
}


class RawJsonRpcAutoClient(I) : JsonRpcAutoClient!I
{
    import autointf;

    public:
        this(OutputStream ostream, InputStream istream) @safe
        {
            _client = new RawJsonRpcClient!TId(ostream, istream);
            _settings = new JsonRpcSettings();
        }

    mixin(autoImplementMethods!I());
}

class JsonRpcAutoHTTPClient(I) : JsonRpcAutoClient!I
{
    import autointf;

    public:
        this(string host) @safe
        {
            _client = new HttpJsonRpcClient!TId(host);
            _settings = new JsonRpcSettings();
        }

    mixin(autoImplementMethods!I());
}

class JsonRpcAutoTCPClient(I) : JsonRpcAutoClient!I
{
    import autointf;

    public:
        this(string host, ushort port) @safe
        {
            _client = new TcpJsonRpcClient!TId(host, port);
            _settings = new JsonRpcSettings();
        }

    mixin(autoImplementMethods!I());
}

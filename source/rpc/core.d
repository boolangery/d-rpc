/**
    Core functionnalities of the RPC framework.

    Copyright: © 2018 Eliott Dumeix
    License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
*/
module rpc.core;

import std.traits : hasUDA;
import vibe.internal.meta.uda : onlyAsUda;

version(RpcUnitTest) { public import unit_threaded; }
else { enum ShouldFail; } // so production builds compile


// ////////////////////////////////////////////////////////////////////////////
// Attributes																 //
// ////////////////////////////////////////////////////////////////////////////
package struct NoRPCMethodAttribute
{
}

/// Methods marked with this attribute will not be treated as rpc endpoints.
@property NoRPCMethodAttribute noRpcMethod() @safe
{
    if (!__ctfe)
        assert(false, onlyAsUda!__FUNCTION__);
    return NoRPCMethodAttribute();
}

///
unittest
{
    interface IAPI
    {
        @noRpcMethod
        void submit();
    }
}

package struct RPCMethodAttribute
{
    string method;
}

/// Methods marked with this attribute will be treated as rpc endpoints.
/// Params:
///     method = RPC method name
RPCMethodAttribute rpcMethod(string method) @safe
{
    if (!__ctfe)
        assert(false, onlyAsUda!__FUNCTION__);
    return RPCMethodAttribute(method);
}

///
unittest
{
    interface IAPI
    {
        @rpcMethod("do_submit")
        void submit();
    }
}

/// Allow to specify the id type used by some rpc protocol (like json-rpc 2.0)
package struct RPCIdTypeAttribute(T) if (is(T == int) || is(T == string))
{
    alias idType = T;
}
alias rpcIdType(T) = RPCIdTypeAttribute!T;

/// attributes utils
private enum IsRPCMethod(alias M) = !hasUDA!(M, NoRPCMethodAttribute);

/// On a rpc method, when RPCMethodObjectParams.asObject is selected, this
/// attribute is used to customize the name rendered for each arg in the params object.
package struct RPCMethodObjectParams
{
    string[string] names;
}

/// Methods marked with this attribute will see its parameters rendered as an object (if applicable by the protocol).
RPCMethodObjectParams rpcObjectParams() @safe
{
    if (!__ctfe)
        assert(false, onlyAsUda!__FUNCTION__);
    return RPCMethodObjectParams();
}

///
unittest
{
    interface IAPI
    {
        @rpcObjectParams
        void submit(string hash);
        // In json-rpc params will be rendered as: "params": {"hash": "dZf4F"}
    }
}

/// ditto
RPCMethodObjectParams rpcObjectParams(string[string] names) @safe
{
    if (!__ctfe)
        assert(false, onlyAsUda!__FUNCTION__);
    return RPCMethodObjectParams(names);
}

///
unittest
{
    interface IAPI
    {
        @rpcObjectParams(["hash": "hash_renamed"])
        void submit(string hash);
        // In json-rpc params will be rendered as: "params": {"hash_renamed": "dZf4F"}
    }
}

// Attribute to force params to be sended as array (even if alone)
package struct RPCArrayParams
{
}

/// Methods marked with this attribute will see its parameters rendered as an array (if applicable by the protocol).
@property RPCArrayParams rpcArrayParams() @safe
{
    if (!__ctfe)
        assert(false, onlyAsUda!__FUNCTION__);
    return RPCArrayParams();
}

///
unittest
{
    interface IAPI
    {
        @rpcArrayParams
        void submit(string hash);
        // In json-rpc params will be rendered as: "params": ["dZf4F"]
    }
}

/// attributes utils
package enum hasRPCArrayParams(alias M) = hasUDA!(M, RPCArrayParams);


/** Hold settings to be used by the rpc interface.
*/
class RPCInterfaceSettings
{
    import core.time;

public:
    /** Ignores a trailing underscore in method and function names.
        With this setting set to $(D true), it's possible to use names in the
        REST interface that are reserved words in D.
    */
    bool stripTrailingUnderscore = true;

    Duration responseTimeout = 500.msecs;

    string linesep = "\n";

    /** Optional handler used to render custom replies in case of errors.
    */
    RPCErrorHandler errorHandler;
}

///
alias RPCErrorHandler = void delegate(Exception e) @safe nothrow;

/** Define an id generator.

    Template_Params:
        TId = The type used to identify rpc request.
*/
package interface IIdGenerator(TId)
{
    TId getNextId() @safe nothrow;
}

/** An int id generator.
*/
package class IdGenerator(TId: int): IIdGenerator!TId
{
    private TId _id;

    override TId getNextId() @safe nothrow
    {
        _id++;
        return _id;
    }
}

/** A string id generator.
*/
package class IdGenerator(TId: string): IIdGenerator!TId
{
    import std.string : succ;

    private TId _id = "0";

    override  TId getNextId() @safe nothrow
    {
        _id = succ(_id);
        return _id;
    }
}

/** An RPC request identified by an id of type TId.
*/
package interface IRPCRequest(TId)
{
    /// Get the request id
    @property TId requestId();
}

/// An RPC response.
package interface IRPCResponse
{
    string toString() @safe;
}

/**
    An RPC client working with TRequest and TResponse.
*/
interface IRPCClient(TId, TRequest, TResponse)
    if (is(TRequest: IRPCRequest!TId) && is(TResponse: IRPCResponse))
{
    import core.time : Duration;

    /// Returns true if the client is connected.
    @property bool connected() @safe nothrow;

    /// Try to connect the client.
    bool connect() @safe nothrow;

    /**
        Send a request and wait a response for the specified timeout.

        Params:
            request = The request to send.
            timeout = How mush to wait for a response.

        Throws:
            Any of RPCException sub-classes.
    */
    TResponse sendRequestAndWait(TRequest request, Duration timeout = Duration.max()) @safe;

    /// Tell to process the input stream once.
    void tick() @safe;
}

/**
    A raw rpc client sending TRequest and receiving TResponse object through
    Input/Output stream.

    Template_Params:
        TId = The type used to identify rpc request.
        TRequest = Request type, must be an IRPCRequest.
        TResponse = Reponse type, must be an IRPCResponse.
*/
abstract class RawRPCClient(TId, TRequest, TResponse): IRPCClient!(TId, TRequest, TResponse)
{
    import vibe.core.stream: InputStream, OutputStream;

    protected OutputStream _ostream;
    protected InputStream _istream;

    this(OutputStream ostream, InputStream istream) @safe
    {
        _ostream = ostream;
        _istream = istream;
    }

    @disable @property bool connected() @safe nothrow { return true; }
    @disable bool connect() @safe nothrow { return true; }
    override void tick() @safe { }
}

/**
    Base implementation of an Http RPC client.

    Template_Params:
        TId = The type used to identify rpc request.
        TRequest = Request type, must be an IRPCRequest.
        TResponse = Reponse type, must be an IRPCResponse.
*/

class HttpRPCClient(TId, TRequest, TResponse): IRPCClient!(TId, TRequest, TResponse)
{
    import vibe.data.json;
    import vibe.http.client;
    import vibe.stream.operations;
    import std.conv: to;
    import vibe.core.log;

private:
    string _url;
    IIdGenerator!TId _idGenerator;
    TResponse[TId] _pendingResponse;

public:
    this(string url)
    {
        _url = url;
        _idGenerator = new IdGenerator!TId();
    }

    override TResponse sendRequestAndWait(TRequest request, Duration timeout = Duration.max()) @safe
    {
        request.id = _idGenerator.getNextId();

        TResponse reponse;

        requestHTTP(_url,
            (scope req) {
                req.method = HTTPMethod.POST;

                req.writeJsonBody(request);
                logTrace("client request: %s", request);
            },
            (scope res) {
                if (res.statusCode == 200)
                {
                    string json = res.bodyReader.readAllUTF8();
                    logTrace("client response: %s", json);
                    reponse = deserializeJson!TResponse(json);
                }
                else
                {
                    throw new RPCTimeoutException("HTTP " ~ to!string(res.statusCode) ~ ": " ~ res.statusPhrase);
                }
            }
        );

        return reponse;
    }

    @disable @property bool connected() { return true; }
    @disable bool connect() @safe nothrow { return true; }
    @disable void tick() @safe nothrow { }
}

/**
    Represent server to client stream.

    Template_Params:
        TResponse = Reponse type, must be an IRPCResponse.
*/
interface IRPCServerOutput(TResponse: IRPCResponse)
{
    void sendResponse(TResponse reponse) @safe;
}

/// A RPC request handler
alias RPCRequestHandler(TRequest, TResponse) = void delegate(TRequest req, IRPCServerOutput!TResponse serv) @safe;

/** An RPC server that can register handler.

    Template_Params:
        TId = The type used to identify RPC request.

        TRequest = Request type, must be an IRPCRequest.

        TResponse = Reponse type, must be an IRPCResponse.
*/
interface IRPCServer(TId, TRequest, TResponse)
    if (is(TRequest: IRPCRequest!TId) && is(TResponse: IRPCResponse))
{
    /** Register a delegate to be called on reception of a request matching 'method'.

        Params:
            method = The RPC method to match.
            handler = The delegate to call.
    */
    void registerRequestHandler(string method, RPCRequestHandler!(TRequest, TResponse) handler);

    /** Auto-register all method in an interface.

        Template_Params:
            TImpl = The interface type.

        Params:
            instance = The interface instance.
            settings = Optional RPC settings.
    */
    void registerInterface(TImpl)(TImpl instance, RPCInterfaceSettings settings = null);

    void tick() @safe;
}


abstract class RawRPCServer(TId, TRequest, TResponse): IRPCServer!(TId, TRequest, TResponse)
{
    import vibe.core.stream: InputStream, OutputStream;

    protected OutputStream _ostream;
    protected InputStream _istream;

    this(OutputStream ostream, InputStream istream) @safe
    {
        _ostream = ostream;
        _istream = istream;
    }
}

/** An HTTP RPC server.
*/
class HttpRPCServer(TId, TRequest, TResponse): IRPCServer!(TId, TRequest, TResponse)
{
    import vibe.core.log;
    import vibe.data.json: Json, parseJson, deserializeJson;
    import vibe.http.router;
    import vibe.stream.operations;
    public import vibe.http.server : HTTPServerResponse;

    alias RPCRespHandler = IRPCServerOutput!TResponse;
    alias RequestHandler = RPCRequestHandler!(TRequest, TResponse);

private:
    URLRouter _router;
    RequestHandler[string] _requestHandler;

public:
    this(URLRouter router, string path)
    {
        _router = router;
        _router.post(path, &onPostRequest);
    }

    @disable void registerInterface(I)(I instance, RPCInterfaceSettings settings = null)
    {
    }

    void registerRequestHandler(string method, RequestHandler handler)
    {
        _requestHandler[method] = handler;
    }

protected:
    /** Handle all HTTP POST request on the RPC route and
        forward call to the service.
    */
    void onPostRequest(HTTPServerRequest req, HTTPServerResponse res)
    {
        string json = req.bodyReader.readAllUTF8();
        logTrace("post request received: %s", json);

        this.process(json, createReponseHandler(res));
    }

    /// Creates a new response handler.
    abstract RPCRespHandler createReponseHandler(HTTPServerResponse res) @safe nothrow;

    void process(string data, RPCRespHandler respHandler)
    @safe nothrow {
        try
        {
            Json json = parseJson(data);

            void process(Json jsonObject)
            @safe {
                auto request = deserializeJson!TRequest(jsonObject);
                if (request.method in _requestHandler)
                {
                    _requestHandler[request.method](request, respHandler);
                }
            }

            // batch of commands
            if (json.type == Json.Type.array)
            {
                foreach (object; json.byValue)
                {
                    process(object);
                }
            }
            else
            {
                process(json);
            }
        }
        catch (Exception e)
        {
            // request parse error, so send a response without id
            auto response = buildResponseFromException(e);
            try {
                respHandler.sendResponse(response);
            } catch (Exception e) {
                logCritical("unable to send response: %s", e.msg);
                // TODO: add a delgate to allow the user to handle error
            }
        }
    }

    abstract TResponse buildResponseFromException(Exception e) @safe nothrow;
}


/// Base class for RPC exceptions.
class RPCException: Exception {
    public Exception inner;

    this(string msg, Exception inner = null)
    @safe {
        super(msg);
        this.inner = inner;
    }
}

/// Client not connected exception
class RPCNotConnectedException: RPCException {
    this(string msg)
    @safe {
        super(msg);
    }
}

/// Parsing exception.
class RPCParsingException: RPCException {
    this(string msg, Exception inner = null)
    @safe {
        super(msg, inner);
    }
}

/// Unhandled RPC method on server-side.
class UnhandledRPCMethod: RPCException
{
    this(string msg)
    @safe {
        super(msg);
    }
}

/// RPC call timeout on client-side.
class RPCTimeoutException: RPCException
{
    this(string msg)
    @safe {
        super(msg);
    }
}

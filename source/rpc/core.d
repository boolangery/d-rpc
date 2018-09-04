/**
	Rpc framework core.

	Copyright: © 2018 Eliott Dumeix
	License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
*/
module rpc.core;

import std.traits : hasUDA;
import vibe.internal.meta.uda : onlyAsUda;
import std.typecons : Flag;

public import vibe.core.stream: InputStream, OutputStream, IOMode;
public import core.time;


/// List of available rpc protocol.
enum RpcProtocol
{
	jsonRpc2_0	// Json-Rpc 2.0
}
alias Json2_0 = RpcProtocol.jsonRpc2_0;

// ////////////////////////////////////////////////////////////////////////////
// Attributes																 //
// ////////////////////////////////////////////////////////////////////////////
/// Methods marked with this attribute will not be treated as rpc endpoints.
package struct NoRpcMethodAttribute {}
NoRpcMethodAttribute noRpcMethod()
@safe {
	if (!__ctfe)
		assert(false, onlyAsUda!__FUNCTION__);
	return NoRpcMethodAttribute();
}

/// Methods marked with this attribute will be treated as rpc endpoints.
/// An attribute to tell if params must be passed as an array or as an
/// object.
package struct RpcMethodAttribute
{
    string method;
}

RpcMethodAttribute rpcMethod(string method)
@safe {
	if (!__ctfe)
		assert(false, onlyAsUda!__FUNCTION__);
	return RpcMethodAttribute(method);
}

/// Allow to specify the id type used by some rpc protocol (like json-rpc 2.0)
package struct RpcIdTypeAttribute(T) if (is(T == int) || is(T == string))
{
	alias idType = T;
}
alias rpcIdType(T) = RpcIdTypeAttribute!T;

/// attributes utils
private enum IsRpcMethod(alias M) = !hasUDA!(M, NoRpcMethodAttribute);

/// On a rpc method, when RpcMethodParamsType.asObject is selected, this
/// attribute is used to customize the name rendered for each arg in the params object.
package struct RpcMethodObjectParams
{
    string[string] names;
}

RpcMethodObjectParams rpcObjectParams(string[string] names)
@safe {
	if (!__ctfe)
		assert(false, onlyAsUda!__FUNCTION__);
	return RpcMethodObjectParams(names);
}

RpcMethodObjectParams rpcObjectParams()
@safe {
	if (!__ctfe)
		assert(false, onlyAsUda!__FUNCTION__);
	return RpcMethodObjectParams();
}

// ////////////////////////////////////////////////////////////////////////////
// Interfaces																 //
// ////////////////////////////////////////////////////////////////////////////
/// Encapsulates settings used to customize the generated RPC interface.
class RpcInterfaceSettings
{
	/** Ignores a trailing underscore in method and function names.
		With this setting set to $(D true), it's possible to use names in the
		REST interface that are reserved words in D.
	*/
	bool stripTrailingUnderscore = true;

	Duration responseTimeout = 500.msecs;

	this()
	@safe {
		import vibe.core.stream: nullSink;
	}

	/** Optional handler used to render custom replies in case of errors.
	*/
	RpcErrorHandler errorHandler;

	@property RpcInterfaceSettings dup()
	const @safe {
		auto ret = new RpcInterfaceSettings;
		ret.stripTrailingUnderscore = this.stripTrailingUnderscore;
		return ret;
	}
}

alias RpcErrorHandler = void delegate() @safe;

/**
	Define an id generator.

	Template_Params:
		TId = The type used to identify rpc request.
*/
interface IRpcIdGenerator(TId)
{
	TId getNextId() @safe;
}

class BasicIdGenerator(TId: int): IRpcIdGenerator!TId
{
	private TId _id;

	TId getNextId()
	@safe {
		_id++;
		return _id;
	}
}

class BasicIdGenerator(TId: string): IRpcIdGenerator!TId
{
	import std.string : succ;

	private TId _id = "0";

	TId getNextId()
	@safe {
		_id = succ(_id);
		return _id;
	}
}

/**
	Define a generic rpc request identified by an id.

	Template_Params:
		TId = The type used to identify rpc request.
*/
interface IRpcRequest(TId)
{
	@property TId requestId();
}

/// Define a generic rpc response.
interface IRpcResponse
{

}

//interface IRpcProcessor
//{
//	void process(string data) @safe;
//}

/**
	Define a rpc client sending RpcRequest object identified by
	a TId, and receiving TResponse object.

	Template_Params:
		TId = The type used to identify rpc request.
		TRequest = Request type, must be an IRpcRequest.
		TResponse = Reponse type, must be an IRpcResponse.
*/
interface IRpcClient(TId, TRequest, TResponse)
	if (is(TRequest: IRpcRequest!TId) && is(TResponse: IRpcResponse))
{
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
			Any of RpcException sub-classes.
	*/
	TResponse sendRequestAndWait(TRequest request, Duration timeout = Duration.max()) @safe;

	/// Tell to process the input stream once
	void tick() @safe;
}

/**
	A raw rpc client sending RpcRequest and receiving TResponse object through
	Input/Output stream.

	Template_Params:
		TId = The type used to identify rpc request.
		TRequest = Request type, must be an IRpcRequest.
		TResponse = Reponse type, must be an IRpcResponse.
*/
abstract class RawRpcClient(TId, TRequest, TResponse): IRpcClient!(TId, TRequest, TResponse)
{
	protected OutputStream _ostream;
	protected InputStream _istream;

	this(OutputStream ostream, InputStream istream) @safe
	{
		_ostream = ostream;
		_istream = istream;
	}

	@property bool connected() @safe nothrow { return true; } // not used

	bool connect() @safe nothrow { return true; } // not used
}

/**
	Base implementation of an Http rpc client.

	Template_Params:
		TId = The type used to identify rpc request.
		TRequest = Request type, must be an IRpcRequest.
		TResponse = Reponse type, must be an IRpcResponse.
*/

class HttpRpcClient(TId, TRequest, TResponse): IRpcClient!(TId, TRequest, TResponse)
{
    import vibe.data.json;
    import vibe.http.client;
    import vibe.stream.operations;
    import std.conv: to;
	import vibe.core.log;

    private string _url;
    private IRpcIdGenerator!TId _idGenerator;
    private TResponse[TId] _pendingResponse;

    @property bool connected() { return true; }

    bool connect() @safe nothrow { return true; }

    this(string url)
    {
        _url = url;
        _idGenerator = new BasicIdGenerator!TId();
    }


    TResponse sendRequestAndWait(TRequest request, Duration timeout = Duration.max())
    @safe {
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
                    throw new RpcTimeoutException("HTTP " ~ to!string(res.statusCode) ~ ": " ~ res.statusPhrase);
                }
            }
        );

        return reponse;
    }

	// TODO: remove me ?
	void process(string data) @safe {}

	void tick() @safe {}
}

/**
	Represent server to client stream.

	Template_Params:
		TResponse = Reponse type, must be an IRpcResponse.
*/
interface IRpcServerOutput(TResponse)
{
	void sendResponse(TResponse reponse) @safe;
}

/// A rpc request handler
alias RpcRequestHandler(TRequest, TResponse) = void delegate(TRequest req, IRpcServerOutput!TResponse serv) @safe;

/**
	Represent a rpc server that can register handler.

	Template_Params:
		TId = The type used to identify rpc request.
		TRequest = Request type, must be an IRpcRequest.
		TResponse = Reponse type, must be an IRpcResponse.
*/
interface IRpcServer(TId, TRequest, TResponse)
	if (is(TRequest: IRpcRequest!TId) && is(TResponse: IRpcResponse))
{
	/**
		Register a delegate to be called on reception of a request matching 'method'.

		Params:
			method = The rpc method to match.
			handler = The delegate to call.
	*/
	void registerRequestHandler(string method, RpcRequestHandler!(TRequest, TResponse) handler);

	/**
		Auto-register all method in an interface.

		Template_Params:
			TImpl = The interface type.
		Params:
			instance = The interface instance.
			settings = Optional rpc settings.
	*/
	void registerRpcInterface(TImpl)(TImpl instance, RpcInterfaceSettings settings = null);

	void tick() @safe;
}


abstract class RawRpcServer(TId, TRequest, TResponse): IRpcServer!(TId, TRequest, TResponse)
{
	protected OutputStream _ostream;
	protected InputStream _istream;

	this(OutputStream ostream, InputStream istream) @safe
	{
		_ostream = ostream;
		_istream = istream;
	}
}


class HttpRpcServer(TId, TRequest, TResponse): IRpcServer!(TId, TRequest, TResponse)
{
	import vibe.core.log;
	import vibe.data.json: Json, parseJson, deserializeJson;
    import vibe.http.router;
    import vibe.stream.operations;

    alias RpcRespHandler = IRpcServerOutput!TResponse;
	alias RequestHandler = RpcRequestHandler!(TRequest, TResponse);

    private URLRouter _router;
    private RequestHandler[string] _requestHandler;

    this(URLRouter router, string path)
    {
        _router = router;
        _router.post(path, &onPostRequest);
    }

    void registerInterface(I)(I instance, RpcInterfaceSettings settings = null)
    {
        static assert(false, "must be overrided in derived classe");
    }

    protected void onPostRequest(HTTPServerRequest req, HTTPServerResponse res)
    {
        string json = req.bodyReader.readAllUTF8();
        logTrace("post request received: %s", json);
        this.process(json, new class RpcRespHandler {
            void sendResponse(TResponse reponse)
            @safe nothrow {
                logTrace("post request response: %s", reponse);
                try {
                    res.writeJsonBody(reponse.toJson());
                } catch (Exception e) {
                    logCritical("unable to send response: %s", e.msg);
                    // TODO: add a delgate to allow the user to handle error
                }
            }
        });
    }

    void registerRequestHandler(string method, RequestHandler handler)
    {
        _requestHandler[method] = handler;
    }


    protected void process(string data, RpcRespHandler respHandler)
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

	protected abstract TResponse buildResponseFromException(Exception e) @safe nothrow;
}


// ////////////////////////////////////////////////////////////////////////////
// Exceptions																 //
// ////////////////////////////////////////////////////////////////////////////
/// Base class for rpc exceptions.
class RpcException: Exception {
	public Exception inner;

	this(string msg, Exception inner = null)
	@safe {
		super(msg);
		this.inner = inner;
	}
}

/// Client not connected exception
class RpcNotConnectedException: RpcException {
	this(string msg)
	@safe {
		super(msg);
	}
}

/// Parsing exception.
class RpcParsingException: RpcException {
	this(string msg, Exception inner = null)
	@safe {
		super(msg, inner);
	}
}

/// Unhandled rpc method on server-side.
class UnhandledRpcMethod: RpcException
{
    this(string msg)
    @safe {
        super(msg);
    }
}

/// Rpc call timeout on client-side.
class RpcTimeoutException: RpcException
{
    this(string msg)
    @safe {
        super(msg);
    }
}

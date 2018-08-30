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

    void registerInterface(TImpl)(TImpl instance, RpcInterfaceSettings settings = null)
    {
        import std.algorithm : filter, map, all;
        import std.array : array;
        import std.range : front;

        auto intf = RpcInterface!TImpl(settings, false);

        foreach (i, ovrld; intf.SubInterfaceFunctions) {
            enum fname = __traits(identifier, intf.SubInterfaceFunctions[i]);
            alias R = ReturnType!ovrld;

            static if (isInstanceOf!(Collection, R)) {
                auto ret = __traits(getMember, instance, fname)(R.ParentIDs.init);
                router.registerRestInterface!(R.Interface)(ret.m_interface, intf.subInterfaces[i].settings);
            } else {
                auto ret = __traits(getMember, instance, fname)();
                router.registerRestInterface!R(ret, intf.subInterfaces[i].settings);
            }
        }

        foreach (i, func; intf.RouteFunctions) {
            auto route = intf.routes[i];
            auto handler = jsonRpcMethodHandler!(TId, func, i)(instance, intf);
            this.registerRequestHandler(route.pattern, handler);
        }
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
                    logTrace("unable to send response: %s", e.msg);
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
            respHandler.sendResponse(response);
        }
    }

	protected abstract TResponse buildResponseFromException(Exception e) @safe nothrow;
}

/// Provides all necessary tools to implement an automated Json-Rpc interface.
/// inspired by /web/vibe/web/internal/rest/common.d
struct RpcInterface(TImpl) if (is(TImpl == class) || is(TImpl == interface))
{
    @safe:

		import std.meta : anySatisfy, Filter;
        import std.traits : FunctionTypeOf, InterfacesTuple, MemberFunctionsTuple,
            ParameterIdentifierTuple, ParameterStorageClass,
            ParameterStorageClassTuple, ParameterTypeTuple, ReturnType;
        import std.typetuple : TypeTuple;
        import vibe.internal.meta.funcattr : IsAttributedParameter;
        import vibe.internal.meta.traits : derivedMethod;
        import vibe.internal.meta.uda;

	/// The settings used to generate the interface
	RpcInterfaceSettings settings;

    // determine the implementation interface I and check for validation errors
	private alias BaseInterfaces = InterfacesTuple!TImpl;
	static assert (BaseInterfaces.length > 0 || is (TImpl == interface),
		       "Cannot registerRestInterface type '" ~ TImpl.stringof
		       ~ "' because it doesn't implement an interface");
	static if (BaseInterfaces.length > 1)
		pragma(msg, "Type '" ~ TImpl.stringof ~ "' implements more than one interface: make sure the one describing the REST server is the first one");

    // alias the base interface
    static if (is(TImpl == interface))
		alias I = TImpl;
	else
        alias I = BaseInterfaces[0];

	/// The rpc id type to use
	static if (hasUDA!(I, RpcIdTypeAttribute!int))
		alias rpcIdType = int;
    else static if (hasUDA!(I, RpcIdTypeAttribute!string))
		alias rpcIdType = string;
	else
		alias rpcIdType = int;

    /// The name of each interface member
    enum memberNames = [__traits(allMembers, I)];

    /// Aliases to all interface methods
    alias AllMethods = GetAllMethods!();

    /** Aliases for each route method
		This tuple has the same number of entries as `routes`.
	*/
	alias RouteFunctions = GetRouteFunctions!();

    enum routeCount = RouteFunctions.length;

	/** Information about each route
		This array has the same number of fields as `RouteFunctions`
	*/
	Route[routeCount] routes;

	/// Static (compile-time) information about each route
	static if (routeCount) static const StaticRoute[routeCount] staticRoutes = computeStaticRoutes();
	else static const StaticRoute[0] staticRoutes;


	/** Aliases for each sub interface method
		This array has the same number of entries as `subInterfaces` and
		`SubInterfaceTypes`.
	*/
	alias SubInterfaceFunctions = getSubInterfaceFunctions!();

	/** The type of each sub interface
		This array has the same number of entries as `subInterfaces` and
		`SubInterfaceFunctions`.
	*/
	alias SubInterfaceTypes = GetSubInterfaceTypes!();

	enum subInterfaceCount = SubInterfaceFunctions.length;

	/** Information about sub interfaces
		This array has the same number of entries as `SubInterfaceFunctions` and
		`SubInterfaceTypes`.
	*/
	SubInterface[subInterfaceCount] subInterfaces;

	/** Fills the struct with information.
		Params:
			settings = Optional settings object.
	*/
	this(RpcInterfaceSettings settings, bool is_client)
	{
		import vibe.internal.meta.uda : findFirstUDA;

		this.settings = settings ? settings.dup : new RpcInterfaceSettings;

		computeRoutes();
		computeSubInterfaces();
	}

	// copying this struct is costly, so we forbid it
	@disable this(this);

	private void computeRoutes()
	{
		import std.algorithm.searching : any;

		foreach (si, RF; RouteFunctions) {
			enum sroute = staticRoutes[si];

			Route route;
			route.functionName = sroute.functionName;
			route.pattern = sroute.functionName;
			route.paramsAsObject = sroute.paramsAsObject;

			static if (sroute.pathOverride)
				route.pattern = sroute.rawName;

			route.parameters.length = sroute.parameters.length;

			bool prefix_id = false;

			alias PT = ParameterTypeTuple!RF;
			foreach (i, _; PT) {
				enum sparam = sroute.parameters[i];
				Parameter pi;
				pi.name = sparam.name;

				route.parameters[i] = pi;
			}

			routes[si] = route;
		}
	}

	private void computeSubInterfaces()
	{
		foreach (i, func; SubInterfaceFunctions) {
			enum meta = extractHTTPMethodAndName!(func, false)();

			static if (meta.hadPathUDA) string url = meta.url;
			else string url = computeDefaultPath!func(meta.url);

			SubInterface si;
			si.settings = settings.dup;
			si.settings.baseURL = URL(concatURL(this.baseURL, url, true));
			subInterfaces[i] = si;
		}

		assert(subInterfaces.length == SubInterfaceFunctions.length);
	}

	// ////////////////////////////////////////////////////////////////////////
	// compile time methods
	// ////////////////////////////////////////////////////////////////////////
    private template GetAllMethods() {
		template Impl(size_t idx) {
			static if (idx < memberNames.length) {
				enum name = memberNames[idx];
				static if (name.length != 0)
					alias Impl = TypeTuple!(Filter!(IsRpcMethod, MemberFunctionsTuple!(I, name)), Impl!(idx+1));
				else alias Impl = Impl!(idx+1);
			} else alias Impl = TypeTuple!();
		}
		alias GetAllMethods = Impl!0;
	}

    private template GetRouteFunctions() {
		template Impl(size_t idx) {
			static if (idx < AllMethods.length) {
				alias F = AllMethods[idx];
				alias SI = SubInterfaceType!F;
				static if (is(SI == void))
					alias Impl = TypeTuple!(F, Impl!(idx+1));
				else alias Impl = Impl!(idx+1);
			} else alias Impl = TypeTuple!();
		}
		alias GetRouteFunctions = Impl!0;
	}

	private static StaticRoute[routeCount] computeStaticRoutes()
	{
		static import std.traits;
		import std.algorithm.searching : any, count;
		import std.algorithm: countUntil;
		import std.meta : AliasSeq;

		assert(__ctfe);

		StaticRoute[routeCount] ret;

		foreach (fi, func; RouteFunctions) {
			StaticRoute sroute;
			sroute.functionName = __traits(identifier, func);

			static if (!is(TImpl == I))
				alias cfunc = derivedMethod!(TImpl, func);
			else
				alias cfunc = func;

			alias FuncType = FunctionTypeOf!func;
			alias ParameterTypes = ParameterTypeTuple!FuncType;
			alias ReturnType = std.traits.ReturnType!FuncType;
			enum parameterNames = [ParameterIdentifierTuple!func];

			enum meta = extractMethodMeta!(func, false)();
			sroute.rawName = meta.method;
			sroute.pathOverride = meta.hadPathUDA;
			sroute.paramsAsObject = meta.paramsAsObject;

			foreach (i, PT; ParameterTypes) {
				enum pname = parameterNames[i];

				// Comparison template for anySatisfy
				// template Cmp(WebParamAttribute attr) { enum Cmp = (attr.identifier == ParamNames[i]); }
				// alias CompareParamName = GenCmp!("Loop"~func.mangleof, i, parameterNames[i]);
				// mixin(CompareParamName.Decl);
				StaticParameter pi;
				pi.name = parameterNames[i];

				enum paramIdx = countUntil(meta.paramIds, pname);

				static if (paramIdx != -1)
				    pi.objectName = meta.paramNames[paramIdx];
				else
				    pi.objectName = pi.name;

				// determine in/out storage class
				enum SC = ParameterStorageClassTuple!func[i];
				static assert(!(SC & ParameterStorageClass.out_));

				sroute.parameters ~= pi;
			}

			ret[fi] = sroute;
		}

		return ret;
	}

	private template getSubInterfaceFunctions() {
		template Impl(size_t idx) {
			static if (idx < AllMethods.length) {
				alias SI = SubInterfaceType!(AllMethods[idx]);
				static if (!is(SI == void)) {
					alias Impl = TypeTuple!(AllMethods[idx], Impl!(idx+1));
				} else {
					alias Impl = Impl!(idx+1);
				}
			} else alias Impl = TypeTuple!();
		}
		alias getSubInterfaceFunctions = Impl!0;
	}

	private template GetSubInterfaceTypes() {
		template Impl(size_t idx) {
			static if (idx < AllMethods.length) {
				alias SI = SubInterfaceType!(AllMethods[idx]);
				static if (!is(SI == void)) {
					alias Impl = TypeTuple!(SI, Impl!(idx+1));
				} else {
					alias Impl = Impl!(idx+1);
				}
			} else alias Impl = TypeTuple!();
		}
		alias GetSubInterfaceTypes = Impl!0;
	}
}

struct StaticRoute {
	string functionName; // D name of the function
	string rawName; // raw name as returned
	bool pathOverride; // @path UDA was used
	bool paramsAsObject; // the way to render params
	StaticParameter[] parameters;
}

struct StaticParameter {
	string name;
	string objectName; // used in object params
}

/// Describe a rpc route
struct Route {
	string functionName; // D name of the function
	string pattern; // relative route path (relative to baseURL)
	bool paramsAsObject; // the way to render params
	Parameter[] parameters;
}

struct Parameter {
	string name;
	string fieldName;
}

template SubInterfaceType(alias F) {
	import std.traits : ReturnType, isInstanceOf;
	alias RT = ReturnType!F;
	static if (is(RT == interface)) alias SubInterfaceType = RT;
	//else static if (isInstanceOf!(Collection, RT)) alias SubInterfaceType = RT.Interface;
	else alias SubInterfaceType = void;
}

/**
	Determines the rpc path for a given method.
	This function is designed for CTFE usage and will assert at run time.
	Returns:
		A tuple of two elements is returned:
		$(UL
			$(LI flag "was UDA used to override path")
			$(LI path extracted)
		)
 */
auto extractMethodMeta(alias Func, bool indexSpecialCase)()
{
	if (!__ctfe)
		assert(false);

	struct HandlerMeta
	{
		bool hadPathUDA;
		string method;
		bool paramsAsObject;
		string[] paramIds;
		string[] paramNames;
	}

	import vibe.internal.meta.uda : findFirstUDA;

	enum name = __traits(identifier, Func);
	// alias T = typeof(&Func);

	// Workaround for Nullable incompetence
	enum rpcMethod = findFirstUDA!(RpcMethodAttribute, Func);
	enum rpcObjectParams = findFirstUDA!(RpcMethodObjectParams, Func);

	string[] paramIds;
	string[] paramNames;

	static if (rpcObjectParams.found) {
		foreach(id, name; rpcObjectParams.value.names) {
            paramIds ~= id;
            paramNames ~= name;
		}
    }

	static if (rpcMethod.found) {
		return HandlerMeta(true, rpcMethod.value.method, rpcObjectParams.found, paramIds, paramNames);
	}
	else {
		return HandlerMeta(false, name, rpcObjectParams.found, paramIds, paramNames);
	}
}

struct SubInterface {
	RpcInterfaceSettings settings;
}

@("Test wrong base interface / class")
unittest {
    interface I{ int add(int a, int b); }
    class S: I { int add(int a, int b){ return 0;} }
    class D {}

    static assert(__traits(compiles, RpcInterface!I()));
    static assert(__traits(compiles, RpcInterface!S()));
    static assert(!__traits(compiles, RpcInterface!D()));
}

@("Test AllMethods, RouteFunctions")
unittest {
    import std.stdio, std.typecons, std.algorithm;

    interface I
	{
		@noRpcMethod() int add(int a, int b);
		int sub(int a, int b);
	}
    class S: I
	{
		int add(int a, int b){ return a + b;}
		int sub(int a, int b) { return a + b; }
	}

    auto intf = RpcInterface!S(null, false);
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

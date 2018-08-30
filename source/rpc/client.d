/**
	Rpc client interface generator based on the work from vibed rest interfaces.

	Copyright: © 2018 Eliott Dumeix
	License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
*/
module rpc.client;

public import rpc.core;


/**
	Implements the given interface by forwarding all public methods to a RPC server.
**/
class RpcInterfaceClient(I, RpcProtocol protocol=Json2_0) : I
{
    import std.typetuple : staticMap;

    private alias Info = RpcInterface!I;
    private alias TId = Info.rpcIdType;

    // storing this struct directly causes a segfault when built with
    // LDC 0.15.x, so we are using a pointer here:
    private RpcInterface!I* m_intf;
    private staticMap!(RpcInterfaceClient, Info.SubInterfaceTypes) m_subInterfaces;


    /// Creates a new REST client implementation of $(D I).
    private this(RpcInterfaceSettings settings = null)
    {
        if (settings is null)
            settings = new RpcInterfaceSettings();
        m_intf = new Info(settings, true);

        foreach (i, SI; Info.SubInterfaceTypes)
            m_subInterfaces[i] = new RpcInterfaceClient!SI(m_intf.subInterfaces[i].settings);
    }

    /// The rpcClient to use
    static if (protocol == RpcProtocol.jsonRpc2_0)
    {
        import rpc.protocol.json;

        private alias TRpcClient = IJsonRpcClient!TId;

        // Construct a json rpc 2.0 with an existing client
        this(TRpcClient client, RpcInterfaceSettings settings = null)
        {
            this(settings);
            this._client = client;
        }

        // Construct a json rpc 2.0 http client
        this(string host, RpcInterfaceSettings settings = null)
        {
            this(settings);
            this._client = new HttpJsonRpcClient!TId(host);
        }

        // Construct a json rpc 2.0 tcp client
        this(string host, ushort port, RpcInterfaceSettings settings = null)
        {
            this(settings);
            this._client = new TcpJsonRpcClient!TId(host, port);
        }

        // Construct a json rpc 2.0 raw client
        this(OutputStream ostream, InputStream istream, RpcInterfaceSettings settings = null)
        {
            this(settings);
            this._client = new RawJsonRpcClient!TId(ostream, istream);
        }
    }

    @property bool connected() { return _client.connected; }

    bool connect()
    {
        return _client.connect();
    }

    void tick() { _client.tick(); }

    private TRpcClient _client;

    mixin(generateRestClientMethods!I());
}


private string generateRestClientMethods(I)()
{
    import std.array : join;
    import std.string : format;
    import std.traits : fullyQualifiedName, isInstanceOf, ParameterIdentifierTuple;

    alias Info = RpcInterface!I;

    string ret = q{
		import vibe.internal.meta.codegen : CloneFunction;
	};

    // generate sub interface methods
    foreach (i, SI; Info.SubInterfaceTypes) {
        alias F = Info.SubInterfaceFunctions[i];
        alias RT = ReturnType!F;
        alias ParamNames = ParameterIdentifierTuple!F;
        static if (ParamNames.length == 0) enum pnames = "";
        else enum pnames = ", " ~ [ParamNames].join(", ");
        static if (isInstanceOf!(Collection, RT)) {
            ret ~= q{
					mixin CloneFunction!(Info.SubInterfaceFunctions[%1$s], q{
						return Collection!(%2$s)(m_subInterfaces[%1$s]%3$s);
					});
				}.format(i, fullyQualifiedName!SI, pnames);
        } else {
            ret ~= q{
					mixin CloneFunction!(Info.SubInterfaceFunctions[%1$s], q{
						return m_subInterfaces[%1$s];
					});
				}.format(i);
        }
    }

    // generate route methods
    foreach (i, F; Info.RouteFunctions) {
        alias ParamNames = ParameterIdentifierTuple!F;
        static if (ParamNames.length == 0) enum pnames = "";
        else enum pnames = ", " ~ [ParamNames].join(", ");

        ret ~= q{
				mixin CloneFunction!(Info.RouteFunctions[%1$s], q{
					return executeRpcClientMethod!(I, TRpcClient, protocol, %1$s%2$s)(*m_intf, _client);
				});
			}.format(i, pnames);
    }

    return ret;
}

private auto executeRpcClientMethod(I, TRpcClient, RpcProtocol protocol, size_t ridx, ARGS...)
(ref RpcInterface!I intf, TRpcClient _client)
@safe {
    import std.traits;
    import std.array : appender;
    import core.time;

    // retrieve some compile time informations
    alias TId   = intf.rpcIdType;
    alias Info  = RpcInterface!I;
    alias Func  = Info.RouteFunctions[ridx];
    alias RT    = ReturnType!Func;
    alias PTT   = ParameterTypeTuple!Func;
    enum sroute = Info.staticRoutes[ridx];
    auto route  = intf.routes[ridx];


    // each protocol must be handled speratly here
    static if (protocol == RpcProtocol.jsonRpc2_0)
    {
        import rpc.protocol.json;

        import vibe.data.json;
        try
        {
            auto jsonParams = Json.undefined;

            // Render params as unique param or array
            static if (!sroute.paramsAsObject)
            {
                // if several params, then build an a json array
                if (PTT.length > 1)
                    jsonParams = Json.emptyArray;

                // fill the json array or the unique value
                foreach (i, PT; PTT) {
                    if (PTT.length > 1)
                        jsonParams.appendArrayElement(serializeToJson(ARGS[i]));
                    else
                        jsonParams = serializeToJson(ARGS[i]);
                }
            }
            // render params as a json object by using the param name
            // for the key or the uda if exists
            else
            {
                jsonParams = Json.emptyObject;

                // fill object
                foreach (i, PT; PTT) {
                    jsonParams[sroute.parameters[i].objectName] = serializeToJson(ARGS[i]);
                }
            }


            static if (!is(RT == void))
                RT jret;

            // create a json-rpc request
            auto request = new JsonRpcRequest!TId();
            request.method = route.pattern;
            request.params = jsonParams; // set rpc call params

            auto response = _client.sendRequestAndWait(request, intf.settings.responseTimeout); // send packet and wait

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
}

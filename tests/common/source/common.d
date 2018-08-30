/**
	This module contains common tests utilities.
	License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
	Authors: Eliott Dumeix
*/
public import rpc.server;
public import rpc.client;

public import unit_threaded;
public import vibe.stream.memory;


/** API with an int id
*/
@rpcIdType!int
interface IAPI
{
	void set(string value);

	int add(int a, int b);

	int div(int a, int b);

	void doNothing();

	@rpcObjectParams(["value": "my_value"])
	void asObject(string value, int number);
}

/** API with a string id
*/
@rpcIdType!string
interface IStringAPI
{
	int add(int a, int b);

	int div(int a, int b);

	void doNothing();
}

/** Represent a bad client implementation of IAPI.
*/
@rpcIdType!int
interface IBadAPI
{
	int add(int b);
}

/** Api implementation.
*/
class API: IAPI
{
	void set(string value)
	{
		// do nothing
	}

	int add(int a, int b)
	{
		return a + b;
	}

	int div(int a, int b)
	{
		if (b == 0)
			throw new Exception("invalid diviser (0)");
		else
			return a/b;
	}

	void doNothing() {}

	void asObject(string value, int number) {}
}

/// MemoryOutputStream helper to get data as a string.
string str(MemoryOutputStream stream)
{
	import std.conv: to;
	return to!string(cast(char[])stream.data);
}

ubyte[] toBytes(string str) @safe
{
	return cast(ubyte[])(str.dup);
}

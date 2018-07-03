/**
	This module contains common tests utilities.
	License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
	Authors: Eliott Dumeix
*/
public import rpc.server;
public import rpc.client;

public import unit_threaded;
public import vibe.stream.memory;


/** The API to test.
*/
@rpcIdType!int
interface IAPI
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

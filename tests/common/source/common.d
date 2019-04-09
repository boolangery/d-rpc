/**
	This module contains common tests utilities.
	License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
	Authors: Eliott Dumeix
*/
import std.conv : to;
public import unit_threaded;
public import vibe.stream.memory;
public import rpc.core;

/** API with an int id
*/
@rpcIdType!int()
interface IAPI
{
	void set(string value) @safe;

	int add(int a, int b) @safe;

	int div(int a, int b) @safe;

	void doNothing() @safe;

	@rpcObjectParams(["value": "my_value"])
	string asObject(string value, int number) @safe;

	@rpcMethod("name_changed")
	string nameChanged() @safe;
}

/** API with a string id
*/
@rpcIdType!string()
interface IStringAPI
{
	int add(int a, int b) @safe;

	int div(int a, int b) @safe;

	void doNothing() @safe;
}

/** Represent a bad client implementation of IAPI.
*/
@rpcIdType!int()
interface IBadAPI
{
	int add(int b) @safe;
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

	string asObject(string value, int number)
	{
		return value ~ number.to!string;
	}

	string nameChanged() { return "foo"; };
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


/**
 * Forms the symbols available to all D programs. Includes
 * Object, which is the root of the class object heirarchy.
 *
 * This module is implicitly imported.
 * Macros:
 *      WIKI = Object
 */

/*
 *  Copyright (C) 2004-2006 by Digital Mars, www.digitalmars.com
 *  Written by Walter Bright
 *
 *  This software is provided 'as-is', without any express or implied
 *  warranty. In no event will the authors be held liable for any damages
 *  arising from the use of this software.
 *
 *  Permission is granted to anyone to use this software for any purpose,
 *  including commercial applications, and to alter it and redistribute it
 *  freely, in both source and binary form, subject to the following
 *  restrictions:
 *
 *  o  The origin of this software must not be misrepresented; you must not
 *     claim that you wrote the original software. If you use this software
 *     in a product, an acknowledgment in the product documentation would be
 *     appreciated but is not required.
 *  o  Altered source versions must be plainly marked as such, and must not
 *     be misrepresented as being the original software.
 *  o  This notice may not be removed or altered from any source
 *     distribution.
 */

/*
 *  Modified by Sean Kelly <sean@f4.ca> for use with the Ares project.
 */

module object;

private
{
    import tango.stdc.string;
    import util.string;
}

// NOTE: For some reason, this declaration method doesn't work
//       in this particular file (and this file only).  It must
//       be a DMD thing.
//alias typeof(int.sizeof)                    size_t;
//alias typeof(cast(void*)0 - cast(void*)0)   ptrdiff_t;

version( X86_64 )
{
    alias ulong size_t;
    alias long  ptrdiff_t;
}
else
{
    alias uint  size_t;
    alias int   ptrdiff_t;
}

alias size_t hash_t;

/******************
 * All D class objects inherit from Object.
 */
class Object
{
    /**
     * Convert Object to a human readable string.
     */
    char[] toUtf8()
    {
        return this.classinfo.name;
    }

    /**
     * Compute hash function for Object.
     */
    hash_t toHash()
    {
        // BUG: this prevents a compacting GC from working, needs to be fixed
        return cast(hash_t)cast(void*)this;
    }

    /**
     * Compare with another Object obj.
     * Returns:
     *  $(TABLE
     *  $(TR $(TD this &lt; obj) $(TD &lt; 0))
     *  $(TR $(TD this == obj) $(TD 0))
     *  $(TR $(TD this &gt; obj) $(TD &gt; 0))
     *  )
     */
    int opCmp(Object o)
    {
	    // BUG: this prevents a compacting GC from working, needs to be fixed
	    //return cast(int)cast(void*)this - cast(int)cast(void*)o;

	    //throw new Exception("need opCmp for class " ~ this.classinfo.name);
	    return this !is o;
    }

    /**
     * Returns !=0 if this object does have the same contents as obj.
     */
    int opEquals(Object o)
    {
        return this is o;
    }
}

/**
 * Information about an interface.
 */
struct Interface
{
    ClassInfo classinfo;        /// .classinfo for this interface
    void *[] vtbl;
    int offset;                 // offset to Interface 'this' from Object 'this'
}

/**
 * Runtime type information about a class. Can be retrieved for any class type
 * or instance by using the .classinfo property.
 */
class ClassInfo : Object
{
    byte[] init;                /** class static initializer
                                 * (init.length gives size in bytes of class)
                                 */
    char[] name;                /// class name
    void *[] vtbl;              /// virtual function pointer table
    Interface[] interfaces;     /// interfaces this class implements
    ClassInfo base;             /// base class
    void *destructor;
    void (*classInvariant)(Object);
     uint flags;
    //  1:                      // IUnknown
    void *deallocator;
}


/**
 * Runtime type information about a type.
 * Can be retrieved for any type using a
 * <a href="../expression.html#typeidexpression">TypeidExpression</a>.
 */
class TypeInfo
{
    hash_t toHash()
    {   hash_t hash;

        foreach (char c; this.classinfo.name)
            hash = hash * 9 + c;
        return hash;
    }

    int opCmp(Object o)
    {
        return stringCompare(this.classinfo.name, o.classinfo.name);
    }

    int opEquals(Object o)
    {
        /* TypeInfo instances are singletons, but duplicates can exist
         * across DLL's. Therefore, comparing for a name match is
         * sufficient.
         */
        return this is o || this.classinfo.name == o.classinfo.name;
    }

    /// Returns a hash of the instance of a type.
    hash_t getHash(void *p) { return cast(uint)p; }

    /// Compares two instances for equality.
    int equals(void *p1, void *p2) { return p1 == p2; }

    /// Compares two instances for &lt;, ==, or &gt;.
    int compare(void *p1, void *p2) { return 0; }

    /// Returns size of the type.
    size_t tsize() { return 0; }

    /// Swaps two instances of the type.
    void swap(void *p1, void *p2)
    {
        size_t n = tsize();
        for (size_t i = 0; i < n; i++)
        {   byte t;

            t = (cast(byte *)p1)[i];
            (cast(byte *)p1)[i] = (cast(byte *)p2)[i];
            (cast(byte *)p2)[i] = t;
        }
    }
}


class TypeInfo_Typedef : TypeInfo
{
    char[] toUtf8() { return name; }
    hash_t getHash(void *p) { return base.getHash(p); }
    int equals(void *p1, void *p2) { return base.equals(p1, p2); }
    int compare(void *p1, void *p2) { return base.compare(p1, p2); }
    size_t tsize() { return base.tsize(); }
    void swap(void *p1, void *p2) { return base.swap(p1, p2); }

    TypeInfo base;
    char[] name;
}

class TypeInfo_Enum : TypeInfo_Typedef
{
}

class TypeInfo_Pointer : TypeInfo
{
    char[] toUtf8() { return next.toUtf8() ~ "*"; }

    hash_t getHash(void *p)
    {
        return cast(uint)*cast(void* *)p;
    }

    int equals(void *p1, void *p2)
    {
        return *cast(void* *)p1 == *cast(void* *)p2;
    }

    int compare(void *p1, void *p2)
    {
        return *cast(void* *)p1 - *cast(void* *)p2;
    }

    size_t tsize()
    {
        return (void*).sizeof;
    }

    void swap(void *p1, void *p2)
    {   void* tmp;
        tmp = *cast(void**)p1;
        *cast(void**)p1 = *cast(void**)p2;
        *cast(void**)p2 = tmp;
    }

    TypeInfo next;
}

class TypeInfo_Array : TypeInfo
{
    char[] toUtf8() { return next.toUtf8() ~ "[]"; }

    hash_t getHash(void *p)
    {   size_t sz = next.tsize();
        hash_t hash = 0;
        void[] a = *cast(void[]*)p;
        for (size_t i = 0; i < a.length; i++)
            hash += next.getHash(a.ptr + i * sz);
        return hash;
    }

    int equals(void *p1, void *p2)
    {
        void[] a1 = *cast(void[]*)p1;
        void[] a2 = *cast(void[]*)p2;
        if (a1.length != a2.length)
            return 0;
        size_t sz = next.tsize();
        for (size_t i = 0; i < a1.length; i++)
        {
            if (!next.equals(a1.ptr + i * sz, a2.ptr + i * sz))
                return 0;
        }
        return 1;
    }

    int compare(void *p1, void *p2)
    {
        void[] a1 = *cast(void[]*)p1;
        void[] a2 = *cast(void[]*)p2;
        size_t sz = next.tsize();
        size_t len = a1.length;

        if (a2.length < len)
            len = a2.length;
        for (size_t u = 0; u < len; u++)
        {
            int result = next.compare(a1.ptr + u * sz, a2.ptr + u * sz);
            if (result)
                return result;
        }
        return cast(int)a1.length - cast(int)a2.length;
    }

    size_t tsize()
    {
        return (void[]).sizeof;
    }

    void swap(void *p1, void *p2)
    {   void[] tmp;
        tmp = *cast(void[]*)p1;
        *cast(void[]*)p1 = *cast(void[]*)p2;
        *cast(void[]*)p2 = tmp;
    }

    TypeInfo next;
}


class TypeInfo_StaticArray : TypeInfo
{
    char[] toUtf8()
    {
        char [10] tmp = void;
        return next.toUtf8() ~ "[" ~ intToUtf8(tmp, len) ~ "]";
    }

    hash_t getHash(void *p)
    {   size_t sz = next.tsize();
        hash_t hash = 0;
        for (size_t i = 0; i < len; i++)
            hash += next.getHash(p + i * sz);
        return hash;
    }

    int equals(void *p1, void *p2)
    {
        size_t sz = next.tsize();

        for (size_t u = 0; u < len; u++)
        {
            if (!next.equals(p1 + u * sz, p2 + u * sz))
                return 0;
        }
        return 1;
    }

    int compare(void *p1, void *p2)
    {
        size_t sz = next.tsize();

        for (size_t u = 0; u < len; u++)
        {
            int result = next.compare(p1 + u * sz, p2 + u * sz);
            if (result)
                return result;
        }
        return 0;
    }

    size_t tsize()
    {
        return len * next.tsize();
    }

    void swap(void *p1, void *p2)
    {   ubyte* tmp;
        size_t sz = next.tsize();
        ubyte[16] buffer;
        ubyte* pbuffer;

        if (sz < buffer.sizeof)
            tmp = buffer;
        else
            tmp = pbuffer = new ubyte[sz];

        for (size_t u = 0; u < len; u += sz)
        {   size_t o = u * sz;
            memcpy(tmp, p1 + o, sz);
            memcpy(p1 + o, p2 + o, sz);
            memcpy(p2 + o, tmp, sz);
        }
        if (pbuffer)
            delete pbuffer;
    }

    TypeInfo next;
    size_t len;
}

class TypeInfo_AssociativeArray : TypeInfo
{
    char[] toUtf8()
    {
        return next.toUtf8() ~ "[" ~ key.toUtf8() ~ "]";
    }

    // BUG: need to add the rest of the functions

    size_t tsize()
    {
        return (void[]).sizeof;
    }

    TypeInfo next;
    TypeInfo key;
}

class TypeInfo_Function : TypeInfo
{
    char[] toUtf8()
    {
        return next.toUtf8() ~ "()";
    }

    // BUG: need to add the rest of the functions

    size_t tsize()
    {
        return 0;       // no size for functions
    }

    TypeInfo next;
}

class TypeInfo_Delegate : TypeInfo
{
    char[] toUtf8()
    {
        return next.toUtf8() ~ " delegate()";
    }

    // BUG: need to add the rest of the functions

    size_t tsize()
    {   alias int delegate() dg;
        return dg.sizeof;
    }

    TypeInfo next;
}

class TypeInfo_Class : TypeInfo
{
    char[] toUtf8() { return info.name; }

    hash_t getHash(void *p)
    {
        Object o = *cast(Object*)p;
        assert(o);
        return o.toHash();
    }

    int equals(void *p1, void *p2)
    {
        Object o1 = *cast(Object*)p1;
        Object o2 = *cast(Object*)p2;

        return o1 == o2 || (o1 && o1.opCmp(o2) == 0);
    }

    int compare(void *p1, void *p2)
    {
        Object o1 = *cast(Object*)p1;
        Object o2 = *cast(Object*)p2;
        int c = 0;

        // Regard null references as always being "less than"
        if (o1 != o2)
        {
            if (o1)
            {   if (!o2)
                    c = 1;
                else
                    c = o1.opCmp(o2);
            }
            else
                c = -1;
        }
        return c;
    }

    size_t tsize()
    {
        return Object.sizeof;
    }

    ClassInfo info;
}

class TypeInfo_Struct : TypeInfo
{
    char[] toUtf8() { return name; }

    hash_t getHash(void *p)
    {   hash_t h;

        assert(p);
        if (xtoHash)
        {   //printf("getHash() using xtoHash\n");
            h = (*xtoHash)(p);
        }
        else
        {
            //printf("getHash() using default hash\n");
            // A sorry hash algorithm.
            // Should use the one for strings.
            // BUG: relies on the GC not moving objects
            for (size_t i = 0; i < xsize; i++)
            {   h = h * 9 + *cast(ubyte*)p;
                p++;
            }
        }
        return h;
    }

    int equals(void *p2, void *p1)
    {   int c;

        if (p1 == p2)
            c = 1;
        else if (!p1 || !p2)
            c = 0;
        else if (xopEquals)
            c = (*xopEquals)(p1, p2);
        else
            // BUG: relies on the GC not moving objects
            c = (memcmp(p1, p2, xsize) == 0);
        return c;
    }

    int compare(void *p2, void *p1)
    {
        int c = 0;

        // Regard null references as always being "less than"
        if (p1 != p2)
        {
            if (p1)
            {   if (!p2)
                    c = 1;
                else if (xopCmp)
                    c = (*xopCmp)(p1, p2);
                else
                    // BUG: relies on the GC not moving objects
                    c = memcmp(p1, p2, xsize);
            }
            else
                c = -1;
        }
        return c;
    }

    size_t tsize()
    {
        return xsize;
    }

    char[] name;
    size_t xsize;

    hash_t function(void*)    xtoHash;
    int function(void*,void*) xopEquals;
    int function(void*,void*) xopCmp;
    char[] function(void*)    xtoString;
}

class Exception : Object
{
    char[]      msg;
    char[]      file;
    size_t      line;
    Exception   next;

    this(char[] msg, Exception next = null)
    {
        this.msg = msg;
        this.next = next;
    }

    this(char[] msg, char[] file, size_t line, Exception next = null)
    {
        this(msg, next);
        this.file = file;
        this.line = line;
    }

    char[] toUtf8()
    {
        return msg;
    }
}

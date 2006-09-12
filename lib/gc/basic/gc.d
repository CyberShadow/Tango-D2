/**
 * This module contains the garbage collector front-end.
 *
 * Copyright: Copyright (C) 2005-2006 Digital Mars, www.digitalmars.com.
 *            All rights reserved.
 * License:
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
 * Authors:   Walter Bright, Sean Kelly
 */

private import gcx;
private import tango.stdc.stdlib;

version=GCCLASS;

version (GCCLASS)
    alias GC gc_t;
else
    alias GC* gc_t;

gc_t _gc;

extern (C) void thread_init();

extern (C) void gc_init()
{
    version (GCCLASS)
    {   void* p;
        ClassInfo ci = GC.classinfo;

        p = tango.stdc.stdlib.malloc(ci.init.length);
        (cast(byte*)p)[0 .. ci.init.length] = ci.init[];
        _gc = cast(GC)p;
    }
    else
    {
        _gc = cast(GC*) tango.stdc.stdlib.calloc(1, GC.sizeof);
    }
    _gc.initialize();
    // NOTE: The GC must initialize the thread library
    //       before its first collection.
    thread_init();
}

extern (C) void gc_term()
{
    _gc.fullCollectNoStack();
}

extern (C) void gc_enable()
{
    _gc.enable();
}

extern (C) void gc_disable()
{
    _gc.disable();
}

extern (C) void gc_collect()
{
    _gc.fullCollect();
}

extern (C) uint gc_getAttr( void* p )
{
    return _gc.getAttr( p );
}

extern (C) uint gc_setAttr( void* p, uint a )
{
    return _gc.setAttr( p, a );
}

extern (C) uint gc_clrAttr( void* p, uint a )
{
    return _gc.clrAttr( p, a );
}

extern (C) void* gc_malloc( size_t sz, uint ba = 0 )
{
    return _gc.malloc( sz, ba );
}

extern (C) void* gc_calloc( size_t sz, uint ba = 0 )
{
    return _gc.calloc( sz, ba );
}

extern (C) void* gc_realloc( void* p, size_t sz, uint ba = 0 )
{
    return _gc.realloc( p, sz, ba );
}

extern (C) void gc_free( void* p )
{
    _gc.free( p );
}

extern (C) size_t gc_sizeOf( void* p )
{
    return _gc.sizeOf( p );
}

extern (C) void gc_addRoot( void* p )
{
    _gc.addRoot( p );
}

extern (C) void gc_addRange( void* p, size_t sz )
{
    _gc.addRange( p, sz );
}

extern (C) void gc_removeRoot( void *p )
{
    _gc.removeRoot( p );
}

extern (C) void gc_removeRange( void *p )
{
    _gc.removeRange( p );
}
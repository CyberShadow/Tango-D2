/**
 * Macros:
 *	WIKI = Phobos/StdFile
 */

/*
 *  Copyright (C) 2001-2004 by Digital Mars, www.digitalmars.com
 * Written by Walter Bright, Christopher E. Miller, Andre Fornacon
 *
 *  This software is provided 'as-is', without any express or implied
 *  warranty. In no event will the authors be held liable for any damages
 *  arising from the use of this software.
 *
 *  Permission is granted to anyone to use this software for any purpose,
 *  including commercial applications, and to alter it and redistribute it
 *  freely, subject to the following restrictions:
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

module phobos.file;

version( Posix ){
    import tango.stdc.posix.dirent;
}
import tango.stdc.errno;
import phobos.c.stdio;
import phobos.c.stdlib;
import phobos.path;
import phobos.string;
import phobos.regexp;

/* =========================== Win32 ======================= */

version (Win32)
{

private import phobos.c.windows.windows;
private import phobos.utf;
private import phobos.windows.syserror;
private import phobos.windows.charset;
private import phobos.date;

int useWfuncs = 1;

static this()
{
    // Win 95, 98, ME do not implement the W functions
    useWfuncs = (GetVersion() < 0x80000000);
}

/***********************************
 * Exception thrown for file I/O errors.
 */

class FileException : Exception
{

    uint errno;			// operating system error code

    this(char[] name)
    {
	this(name, "file I/O");
    }

    this(char[] name, char[] message)
    {
	super(name ~ ": " ~ message);
    }

    this(char[] name, uint errno)
    {
	this(name, sysErrorString(errno));
	this.errno = errno;
    }
}

/* **********************************
 * Basic File operations.
 */

/********************************************
 * Read file name[], return array of bytes read.
 * Throws:
 *	FileException on error.
 */

void[] read(char[] name)
{
    DWORD size;
    DWORD numread;
    HANDLE h;
    byte[] buf;

    if (useWfuncs)
    {
	wchar* namez = phobos.utf.toUTF16z(name);
	h = CreateFileW(namez,GENERIC_READ,FILE_SHARE_READ,null,OPEN_EXISTING,
	    FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN,cast(HANDLE)null);
    }
    else
    {
	char* namez = toMBSz(name);
	h = CreateFileA(namez,GENERIC_READ,FILE_SHARE_READ,null,OPEN_EXISTING,
	    FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN,cast(HANDLE)null);
    }

    if (h == INVALID_HANDLE_VALUE)
	goto err1;

    size = GetFileSize(h, null);
    if (size == INVALID_FILE_SIZE)
	goto err2;

    buf = new byte[size];

    if (ReadFile(h,buf,size,&numread,null) != 1)
	goto err2;

    if (numread != size)
	goto err2;

    if (!CloseHandle(h))
	goto err;

    return buf;

err2:
    CloseHandle(h);
err:
    delete buf;
err1:
    throw new FileException(name, GetLastError());
}

/*********************************************
 * Write buffer[] to file name[].
 * Throws: FileException on error.
 */

void write(char[] name, void[] buffer)
{
    HANDLE h;
    DWORD numwritten;

    if (useWfuncs)
    {
	wchar* namez = phobos.utf.toUTF16z(name);
	h = CreateFileW(namez,GENERIC_WRITE,0,null,CREATE_ALWAYS,
	    FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN,cast(HANDLE)null);
    }
    else
    {
	char* namez = toMBSz(name);
	h = CreateFileA(namez,GENERIC_WRITE,0,null,CREATE_ALWAYS,
	    FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN,cast(HANDLE)null);
    }
    if (h == INVALID_HANDLE_VALUE)
	goto err;

    if (WriteFile(h,buffer,buffer.length,&numwritten,null) != 1)
	goto err2;

    if (buffer.length != numwritten)
	goto err2;
    
    if (!CloseHandle(h))
	goto err;
    return;

err2:
    CloseHandle(h);
err:
    throw new FileException(name, GetLastError());
}


/*********************************************
 * Append buffer[] to file name[].
 * Throws: FileException on error.
 */

void append(char[] name, void[] buffer)
{
    HANDLE h;
    DWORD numwritten;

    if (useWfuncs)
    {
	wchar* namez = phobos.utf.toUTF16z(name);
	h = CreateFileW(namez,GENERIC_WRITE,0,null,OPEN_ALWAYS,
	    FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN,cast(HANDLE)null);
    }
    else
    {
	char* namez = toMBSz(name);
	h = CreateFileA(namez,GENERIC_WRITE,0,null,OPEN_ALWAYS,
	    FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN,cast(HANDLE)null);
    }
    if (h == INVALID_HANDLE_VALUE)
	goto err;

    SetFilePointer(h, 0, null, FILE_END);

    if (WriteFile(h,buffer,buffer.length,&numwritten,null) != 1)
	goto err2;

    if (buffer.length != numwritten)
	goto err2;
    
    if (!CloseHandle(h))
	goto err;
    return;

err2:
    CloseHandle(h);
err:
    throw new FileException(name, GetLastError());
}


/***************************************************
 * Rename file from[] to to[].
 * Throws: FileException on error.
 */

void rename(char[] from, char[] to)
{
    BOOL result;

    if (useWfuncs)
	result = MoveFileW(phobos.utf.toUTF16z(from), phobos.utf.toUTF16z(to));
    else
	result = MoveFileA(toMBSz(from), toMBSz(to));
    if (!result)
	throw new FileException(to, GetLastError());
}


/***************************************************
 * Delete file name[].
 * Throws: FileException on error.
 */

void remove(char[] name)
{
    BOOL result;

    if (useWfuncs)
	result = DeleteFileW(phobos.utf.toUTF16z(name));
    else
	result = DeleteFileA(toMBSz(name));
    if (!result)
	throw new FileException(name, GetLastError());
}


/***************************************************
 * Get size of file name[].
 * Throws: FileException on error.
 */

ulong getSize(char[] name)
{
    HANDLE findhndl;
    uint resulth;
    uint resultl;

    if (useWfuncs)
    {
	WIN32_FIND_DATAW filefindbuf;

	findhndl = FindFirstFileW(phobos.utf.toUTF16z(name), &filefindbuf);
	resulth = filefindbuf.nFileSizeHigh;
	resultl = filefindbuf.nFileSizeLow;
    }
    else
    {
	WIN32_FIND_DATA filefindbuf;

	findhndl = FindFirstFileA(toMBSz(name), &filefindbuf);
	resulth = filefindbuf.nFileSizeHigh;
	resultl = filefindbuf.nFileSizeLow;
    }

    if (findhndl == cast(HANDLE)-1)
    {
	throw new FileException(name, GetLastError());
    }
    FindClose(findhndl);
    return (cast(ulong)resulth << 32) + resultl;
}

/***************************************************
 * Does file name[] (or directory) exist?
 * Return 1 if it does, 0 if not.
 */

int exists(char[] name)
{
    uint result;

    if (useWfuncs)
	// http://msdn.microsoft.com/library/default.asp?url=/library/en-us/fileio/base/getfileattributes.asp
	result = GetFileAttributesW(phobos.utf.toUTF16z(name));
    else
	result = GetFileAttributesA(toMBSz(name));

    return (result == 0xFFFFFFFF) ? 0 : 1;
}

/***************************************************
 * Get file name[] attributes.
 * Throws: FileException on error.
 */

uint getAttributes(char[] name)
{
    uint result;

    if (useWfuncs)
	result = GetFileAttributesW(phobos.utf.toUTF16z(name));
    else
	result = GetFileAttributesA(toMBSz(name));
    if (result == 0xFFFFFFFF)
    {
	throw new FileException(name, GetLastError());
    }
    return result;
}

/****************************************************
 * Is name[] a file?
 * Throws: FileException if name[] doesn't exist.
 */

int isfile(char[] name)
{
    return (getAttributes(name) & FILE_ATTRIBUTE_DIRECTORY) == 0;
}

/****************************************************
 * Is name[] a directory?
 * Throws: FileException if name[] doesn't exist.
 */

int isdir(char[] name)
{
    return (getAttributes(name) & FILE_ATTRIBUTE_DIRECTORY) != 0;
}

/****************************************************
 * Change directory to pathname[].
 * Throws: FileException on error.
 */

void chdir(char[] pathname)
{   BOOL result;

    if (useWfuncs)
	result = SetCurrentDirectoryW(phobos.utf.toUTF16z(pathname));
    else
	result = SetCurrentDirectoryA(toMBSz(pathname));

    if (!result)
    {
	throw new FileException(pathname, GetLastError());
    }
}

/****************************************************
 * Make directory pathname[].
 * Throws: FileException on error.
 */

void mkdir(char[] pathname)
{   BOOL result;

    if (useWfuncs)
	result = CreateDirectoryW(phobos.utf.toUTF16z(pathname), null);
    else
	result = CreateDirectoryA(toMBSz(pathname), null);

    if (!result)
    {
	throw new FileException(pathname, GetLastError());
    }
}

/****************************************************
 * Remove directory pathname[].
 * Throws: FileException on error.
 */

void rmdir(char[] pathname)
{   BOOL result;

    if (useWfuncs)
	result = RemoveDirectoryW(phobos.utf.toUTF16z(pathname));
    else
	result = RemoveDirectoryA(toMBSz(pathname));

    if (!result)
    {
	throw new FileException(pathname, GetLastError());
    }
}

/****************************************************
 * Get current directory.
 * Throws: FileException on error.
 */

char[] getcwd()
{
    if (useWfuncs)
    {
	wchar[] dir;
	int len;
	wchar c;

	len = GetCurrentDirectoryW(0, &c);
	if (!len)
	    goto Lerr;
	dir = new wchar[len];
	len = GetCurrentDirectoryW(len, dir);
	if (!len)
	    goto Lerr;
	return phobos.utf.toUTF8(dir[0 .. len]); // leave off terminating 0
    }
    else
    {
	char[] dir;
	int len;
	char c;

	len = GetCurrentDirectoryA(0, &c);
	if (!len)
	    goto Lerr;
	dir = new char[len];
	len = GetCurrentDirectoryA(len, dir);
	if (!len)
	    goto Lerr;
	return dir[0 .. len];		// leave off terminating 0
    }

Lerr:
    throw new FileException("getcwd", GetLastError());
}

/***************************************************
 * Directory Entry
 */

struct DirEntry
{
    char[] name;			/// file or directory name
    ulong size = ~0UL;			/// size of file in bytes
    d_time creationTime = d_time_nan;	/// time of file creation
    d_time lastAccessTime = d_time_nan;	/// time file was last accessed
    d_time lastWriteTime = d_time_nan;	/// time file was last written to
    uint attributes;		// Windows file attributes OR'd together

    void init(char[] path, WIN32_FIND_DATA *fd)
    {
	wchar[] wbuf;
	size_t clength;
	size_t wlength;
	size_t n;

	clength = phobos.string.strlen(fd.cFileName);

	// Convert cFileName[] to unicode
	wlength = MultiByteToWideChar(0,0,fd.cFileName,clength,null,0);
	if (wlength > wbuf.length)
	    wbuf.length = wlength;
	n = MultiByteToWideChar(0,0,fd.cFileName,clength,cast(wchar*)wbuf,wlength);
	assert(n == wlength);
	// toUTF8() returns a new buffer
	name = phobos.path.join(path, phobos.utf.toUTF8(wbuf[0 .. wlength]));

	size = (cast(ulong)fd.nFileSizeHigh << 32) | fd.nFileSizeLow;
	creationTime = phobos.date.FILETIME2d_time(&fd.ftCreationTime);
	lastAccessTime = phobos.date.FILETIME2d_time(&fd.ftLastAccessTime);
	lastWriteTime = phobos.date.FILETIME2d_time(&fd.ftLastWriteTime);
	attributes = fd.dwFileAttributes;
    }

    void init(char[] path, WIN32_FIND_DATAW *fd)
    {
	size_t clength = phobos.string.wcslen(fd.cFileName);
	name = phobos.path.join(path, phobos.utf.toUTF8(fd.cFileName[0 .. clength]));
	size = (cast(ulong)fd.nFileSizeHigh << 32) | fd.nFileSizeLow;
	creationTime = phobos.date.FILETIME2d_time(&fd.ftCreationTime);
	lastAccessTime = phobos.date.FILETIME2d_time(&fd.ftLastAccessTime);
	lastWriteTime = phobos.date.FILETIME2d_time(&fd.ftLastWriteTime);
	attributes = fd.dwFileAttributes;
    }

    /****
     * Return !=0 if DirEntry is a directory.
     */
    int isdir()
    {
	return attributes & FILE_ATTRIBUTE_DIRECTORY;
    }

    /****
     * Return !=0 if DirEntry is a file.
     */
    int isfile()
    {
	return !(attributes & FILE_ATTRIBUTE_DIRECTORY);
    }
}


/***************************************************
 * Return contents of directory pathname[].
 * The names in the contents do not include the pathname.
 * Throws: FileException on error
 * Example:
 *	This program lists all the files and subdirectories in its
 *	path argument.
 * ----
 * import phobos.stdio;
 * import phobos.file;
 *
 * void main(char[][] args)
 * {
 *    auto dirs = std.file.listdir(args[1]);
 *
 *    foreach (d; dirs)
 *	writefln(d);
 * }
 * ----
 */

char[][] listdir(char[] pathname)
{
    char[][] result;
    
    bool listing(char[] filename)
    {
	result ~= filename;
	return true; // continue
    }
    
    listdir(pathname, &listing);
    return result;
}


/*****************************************************
 * Return all the files in the directory and its subdirectories
 * that match pattern or regular expression r.
 * Params:
 *	pathname = Directory name
 *	pattern = String with wildcards, such as $(RED "*.d"). The supported
 *		wildcard strings are described under fnmatch() in
 *		$(LINK2 std_path.html, std.path).
 *	r = Regular expression, for more powerful _pattern matching.
 * Example:
 *	This program lists all the files with a "d" extension in
 *	the path passed as the first argument.
 * ----
 * import phobos.stdio;
 * import phobos.file;
 *
 * void main(char[][] args)
 * {
 *    auto d_source_files = std.file.listdir(args[1], "*.d");
 *
 *    foreach (d; d_source_files)
 *	writefln(d);
 * }
 * ----
 * A regular expression version that searches for all files with "d" or
 * "obj" extensions:
 * ----
 * import phobos.stdio;
 * import phobos.file;
 * import phobos.regexp;
 *
 * void main(char[][] args)
 * {
 *    auto d_source_files = std.file.listdir(args[1], RegExp(r"\.(d|obj)$"));
 *
 *    foreach (d; d_source_files)
 *	writefln(d);
 * }
 * ----
 */

char[][] listdir(char[] pathname, char[] pattern)
{   char[][] result;
    
    bool callback(DirEntry* de)
    {
	if (de.isdir)
	    listdir(de.name, &callback);
	else
	{   if (phobos.path.fnmatch(de.name, pattern))
		result ~= de.name;
	}
	return true; // continue
    }
    
    listdir(pathname, &callback);
    return result;
}

/** Ditto */

char[][] listdir(char[] pathname, RegExp r)
{   char[][] result;
    
    bool callback(DirEntry* de)
    {
	if (de.isdir)
	    listdir(de.name, &callback);
	else
	{   if (r.test(de.name))
		result ~= de.name;
	}
	return true; // continue
    }
    
    listdir(pathname, &callback);
    return result;
}

/******************************************************
 * For each file and directory name in pathname[],
 * pass it to the callback delegate.
 * Params:
 *	callback =	Delegate that processes each
 *			filename in turn. Returns true to
 *			continue, false to stop.
 * Example:
 *	This program lists all the files in its
 *	path argument, including the path.
 * ----
 * import phobos.stdio;
 * import phobos.path;
 * import phobos.file;
 *
 * void main(char[][] args)
 * {
 *    auto pathname = args[1];
 *    char[][] result;
 *
 *    bool listing(char[] filename)
 *    {
 *      result ~= std.path.join(pathname, filename);
 *      return true; // continue
 *    }
 *
 *    listdir(pathname, &listing);
 *
 *    foreach (name; result)
 *      writefln("%s", name);
 * }
 * ----
 */

void listdir(char[] pathname, bool delegate(char[] filename) callback)
{
    bool listing(DirEntry* de)
    {
	return callback(phobos.path.getBaseName(de.name));
    }

    listdir(pathname, &listing);
}

/******************************************************
 * For each file and directory DirEntry in pathname[],
 * pass it to the callback delegate.
 * Params:
 *	callback =	Delegate that processes each
 *			DirEntry in turn. Returns true to
 *			continue, false to stop.
 * Example:
 *	This program lists all the files in its
 *	path argument and all subdirectories thereof.
 * ----
 * import phobos.stdio;
 * import phobos.file;
 *
 * void main(char[][] args)
 * {
 *    bool callback(DirEntry* de)
 *    {
 *      if (de.isdir)
 *        listdir(de.name, &callback);
 *      else
 *        writefln(de.name);
 *      return true;
 *    }
 *
 *    listdir(args[1], &callback);
 * }
 * ----
 */

void listdir(char[] pathname, bool delegate(DirEntry* de) callback)
{
    char[] c;
    HANDLE h;
    DirEntry de;

    c = phobos.path.join(pathname, "*.*");
    if (useWfuncs)
    {
	WIN32_FIND_DATAW fileinfo;

	h = FindFirstFileW(phobos.utf.toUTF16z(c), &fileinfo);
	if (h != INVALID_HANDLE_VALUE)
	{
	    try
	    {
		do
		{
		    // Skip "." and ".."
		    if (phobos.string.wcscmp(fileinfo.cFileName, ".") == 0 ||
			phobos.string.wcscmp(fileinfo.cFileName, "..") == 0)
			continue;

		    de.init(pathname, &fileinfo);
		    if (!callback(&de))
			break;
		} while (FindNextFileW(h,&fileinfo) != FALSE);
	    }
	    finally
	    {
		FindClose(h);
	    }
	}
    }
    else
    {
	WIN32_FIND_DATA fileinfo;

	h = FindFirstFileA(toMBSz(c), &fileinfo);
	if (h != INVALID_HANDLE_VALUE)	// should we throw exception if invalid?
	{
	    try
	    {
		do
		{
		    // Skip "." and ".."
		    if (phobos.string.strcmp(fileinfo.cFileName, ".") == 0 ||
			phobos.string.strcmp(fileinfo.cFileName, "..") == 0)
			continue;

		    de.init(pathname, &fileinfo);
		    if (!callback(&de))
			break;
		} while (FindNextFileA(h,&fileinfo) != FALSE);
	    }
	    finally
	    {
		FindClose(h);
	    }
	}
    }
}

/******************************************
 * Since Win 9x does not support the "W" API's, first convert
 * to wchar, then convert to multibyte using the current code
 * page.
 * (Thanks to yaneurao for this)
 * Deprecated: use std.windows.charset.toMBSz instead.
 */

char* toMBSz(char[] s)
{
    return phobos.windows.charset.toMBSz(s);
}


/***************************************************
 * Copy a file from[] to[].
 */

void copy(char[] from, char[] to)
{
    BOOL result;

    if (useWfuncs)
	result = CopyFileW(phobos.utf.toUTF16z(from), phobos.utf.toUTF16z(to), false);
    else
	result = CopyFileA(toMBSz(from), toMBSz(to), false);
    if (!result)
         throw new FileException(to, GetLastError());
}


}

/* =========================== linux ======================= */

version (linux)
{

private import phobos.date;
private import phobos.c.linux.linux;
private import tango.sys.linux.linux;

extern (C) char* strerror(int);

/***********************************
 */

class FileException : Exception
{

    uint errno;			// operating system error code

    this(char[] name)
    {
	this(name, "file I/O");
    }

    this(char[] name, char[] message)
    {
	super(name ~ ": " ~ message);
    }

    this(char[] name, uint errno)
    {	char* s = strerror(errno);
	this(name, phobos.string.toString(s).dup);
	this.errno = errno;
    }
}

/********************************************
 * Read a file.
 * Returns:
 *	array of bytes read
 */

void[] read(char[] name)
{
    uint size;
    uint numread;
    int fd;
    struct_stat statbuf;
    byte[] buf;
    char *namez;

    namez = toStringz(name);
    //printf("file.read('%s')\n",namez);
    fd = phobos.c.linux.linux.open(namez, O_RDONLY);
    if (fd == -1)
    {
        //printf("\topen error, errno = %d\n",errno());
        goto err1;
    }

    //printf("\tfile opened\n");
    if (phobos.c.linux.linux.fstat(fd, &statbuf))
    {
        //printf("\tfstat error, errno = %d\n",errno());
        goto err2;
    }
    size = statbuf.st_size;
    buf = new byte[size];

    numread = phobos.c.linux.linux.read(fd, cast(char*)buf, size);
    if (numread != size)
    {
        //printf("\tread error, errno = %d\n",errno());
        goto err2;
    }

    if (phobos.c.linux.linux.close(fd) == -1)
    {
	//printf("\tclose error, errno = %d\n",errno());
        goto err;
    }

    return buf;

err2:
    phobos.c.linux.linux.close(fd);
err:
    delete buf;

err1:
    throw new FileException(name, errno());
}

/*********************************************
 * Write a file.
 * Returns:
 *	0	success
 */

void write(char[] name, void[] buffer)
{
    int fd;
    int numwritten;
    char *namez;

    namez = toStringz(name);
    fd = phobos.c.linux.linux.open(namez, O_CREAT | O_WRONLY | O_TRUNC, 0660);
    if (fd == -1)
        goto err;

    numwritten = phobos.c.linux.linux.write(fd, buffer, buffer.length);
    if (buffer.length != numwritten)
        goto err2;

    if (phobos.c.linux.linux.close(fd) == -1)
        goto err;

    return;

err2:
    phobos.c.linux.linux.close(fd);
err:
    throw new FileException(name, errno());
}


/*********************************************
 * Append to a file.
 */

void append(char[] name, void[] buffer)
{
    int fd;
    int numwritten;
    char *namez;

    namez = toStringz(name);
    fd = phobos.c.linux.linux.open(namez, O_APPEND | O_WRONLY | O_CREAT, 0660);
    if (fd == -1)
        goto err;

    numwritten = phobos.c.linux.linux.write(fd, buffer, buffer.length);
    if (buffer.length != numwritten)
        goto err2;

    if (phobos.c.linux.linux.close(fd) == -1)
        goto err;

    return;

err2:
    phobos.c.linux.linux.close(fd);
err:
    throw new FileException(name, errno());
}


/***************************************************
 * Rename a file.
 */

void rename(char[] from, char[] to)
{
    char *fromz = toStringz(from);
    char *toz = toStringz(to);

    if (phobos.c.stdio.rename(fromz, toz) == -1)
	throw new FileException(to, errno());
}


/***************************************************
 * Delete a file.
 */

void remove(char[] name)
{
    if (phobos.c.stdio.remove(toStringz(name)) == -1)
	throw new FileException(name, errno());
}


/***************************************************
 * Get file size.
 */

ulong getSize(char[] name)
{
    uint size;
    int fd;
    struct_stat statbuf;
    char *namez;

    namez = toStringz(name);
    //printf("file.getSize('%s')\n",namez);
    fd = phobos.c.linux.linux.open(namez, O_RDONLY);
    if (fd == -1)
    {
        //printf("\topen error, errno = %d\n",errno());
        goto err1;
    }

    //printf("\tfile opened\n");
    if (phobos.c.linux.linux.fstat(fd, &statbuf))
    {
        //printf("\tfstat error, errno = %d\n",errno());
        goto err2;
    }
    size = statbuf.st_size;

    if (phobos.c.linux.linux.close(fd) == -1)
    {
	//printf("\tclose error, errno = %d\n",errno());
        goto err;
    }

    return size;

err2:
    phobos.c.linux.linux.close(fd);
err:
err1:
    throw new FileException(name, errno());
}


/***************************************************
 * Get file attributes.
 */

uint getAttributes(char[] name)
{
    struct_stat statbuf;
    char *namez;

    namez = toStringz(name);
    if (phobos.c.linux.linux.stat(namez, &statbuf))
    {
	throw new FileException(name, errno());
    }

    return statbuf.st_mode;
}

/****************************************************
 * Does file/directory exist?
 */

int exists(char[] name)
{
    return access(toStringz(name),0) == 0;

/+
    struct_stat statbuf;
    char *namez;

    namez = toStringz(name);
    if (phobos.c.linux.linux.stat(namez, &statbuf))
    {
	return 0;
    }
    return 1;
+/
}

unittest
{
    assert(exists("."));
}

/****************************************************
 * Is name a file?
 */

int isfile(char[] name)
{
    return (getAttributes(name) & S_IFMT) == S_IFREG;	// regular file
}

/****************************************************
 * Is name a directory?
 */

int isdir(char[] name)
{
    return (getAttributes(name) & S_IFMT) == S_IFDIR;
}

/****************************************************
 * Change directory.
 */

void chdir(char[] pathname)
{
    if (phobos.c.linux.linux.chdir(toStringz(pathname)))
    {
	throw new FileException(pathname, errno());
    }
}

/****************************************************
 * Make directory.
 */

void mkdir(char[] pathname)
{
    if (phobos.c.linux.linux.mkdir(toStringz(pathname), 0777))
    {
	throw new FileException(pathname, errno());
    }
}

/****************************************************
 * Remove directory.
 */

void rmdir(char[] pathname)
{
    if (phobos.c.linux.linux.rmdir(toStringz(pathname)))
    {
	throw new FileException(pathname, errno());
    }
}

/****************************************************
 * Get current directory.
 */

char[] getcwd()
{   char* p;

    p = phobos.c.linux.linux.getcwd(null, 0);
    if (!p)
    {
	throw new FileException("cannot get cwd", errno());
    }

    size_t len = phobos.string.strlen(p);
    char[] buf = new char[len];
    buf[] = p[0 .. len];
    phobos.c.stdlib.free(p);
    return buf;
}

/***************************************************
 * Directory Entry
 */

struct DirEntry
{
    char[] name;			/// file or directory name
    ulong _size = ~0UL;			// size of file in bytes
    d_time _creationTime = d_time_nan;	// time of file creation
    d_time _lastAccessTime = d_time_nan; // time file was last accessed
    d_time _lastWriteTime = d_time_nan;	// time file was last written to
    ubyte d_type;
    ubyte didstat;			// done lazy evaluation of stat()

    void init(char[] path, dirent *fd)
    {	size_t len = phobos.string.strlen(fd.d_name);
	name = phobos.path.join(path, fd.d_name[0 .. len]);
	d_type = fd.d_type;
	didstat = 0;
    }

    int isdir()
    {
	return d_type & DT_DIR;
    }

    int isfile()
    {
	return d_type & DT_REG;
    }

    ulong size()
    {
	if (!didstat)
	    doStat();
	return _size;
    }

    d_time creationTime()
    {
	if (!didstat)
	    doStat();
	return _creationTime;
    }

    d_time lastAccessTime()
    {
	if (!didstat)
	    doStat();
	return _lastAccessTime;
    }

    d_time lastWriteTime()
    {
	if (!didstat)
	    doStat();
	return _lastWriteTime;
    }

    /* This is to support lazy evaluation, because doing stat's is
     * expensive and not always needed.
     */

    void doStat()
    {
	int fd;
	struct_stat statbuf;
	char* namez;

	namez = toStringz(name);
	if (phobos.c.linux.linux.stat(namez, &statbuf))
	{
	    //printf("\tstat error, errno = %d\n",errno());
	    return;
	}
	_size = statbuf.st_size;
	_creationTime = cast(d_time)statbuf.st_ctime * phobos.date.TicksPerSecond;
	_lastAccessTime = cast(d_time)statbuf.st_atime * phobos.date.TicksPerSecond;
	_lastWriteTime = cast(d_time)statbuf.st_mtime * phobos.date.TicksPerSecond;

	didstat = 1;
    }
}


/***************************************************
 * Return contents of directory.
 */

char[][] listdir(char[] pathname)
{
    char[][] result;
    
    bool listing(char[] filename)
    {
	result ~= filename;
	return true; // continue
    }
    
    listdir(pathname, &listing);
    return result;
}

char[][] listdir(char[] pathname, char[] pattern)
{   char[][] result;
    
    bool callback(DirEntry* de)
    {
	if (de.isdir)
	    listdir(de.name, &callback);
	else
	{   if (phobos.path.fnmatch(de.name, pattern))
		result ~= de.name;
	}
	return true; // continue
    }
    
    listdir(pathname, &callback);
    return result;
}

char[][] listdir(char[] pathname, RegExp r)
{   char[][] result;
    
    bool callback(DirEntry* de)
    {
	if (de.isdir)
	    listdir(de.name, &callback);
	else
	{   if (r.test(de.name))
		result ~= de.name;
	}
	return true; // continue
    }
    
    listdir(pathname, &callback);
    return result;
}

void listdir(char[] pathname, bool delegate(char[] filename) callback)
{
    bool listing(DirEntry* de)
    {
	return callback(phobos.path.getBaseName(de.name));
    }

    listdir(pathname, &listing);
}

void listdir(char[] pathname, bool delegate(DirEntry* de) callback)
{
    DIR* h;
    dirent* fdata;
    DirEntry de;

    h = opendir(toStringz(pathname));
    if (h)
    {
	try
	{
	    while((fdata = readdir(h)) != null)
	    {
		// Skip "." and ".."
		if (!phobos.string.strcmp(fdata.d_name, ".") ||
		    !phobos.string.strcmp(fdata.d_name, ".."))
			continue;

		de.init(pathname, fdata);
		if (!callback(&de))	    
		    break;
	    }
	}
	finally
	{
	    closedir(h);
	}
    }
    else
    {
        throw new FileException(pathname, errno());
    }
}


/***************************************************
 * Copy a file.
 * Bugs:
 *	If the file is very large, this won't work.
 *	Doesn't maintain the file timestamps.
 */

void copy(char[] from, char[] to)
{
    void[] buffer;

    buffer = read(from);
    write(to, buffer);
    delete buffer;
}



}

unittest
{
    listdir (".", delegate bool (DirEntry * de)
    {
	auto s = phobos.string.format("%s : c %s, w %s, a %s", de.name,
		toUTCString (de.creationTime),
		toUTCString (de.lastWriteTime),
		toUTCString (de.lastAccessTime));
	return true;
    }
    );
}



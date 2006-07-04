/*
 *  Copyright (C) 2005-2006 by Digital Mars, www.digitalmars.com
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

/**
 * Code coverage analyzer.
 * Bugs:
 *	$(UL
 *	$(LI the execution counters are 32 bits in size, and can overflow)
 *	$(LI inline asm statements are not counted)
 *	)
 * Macros:
 *	WIKI = Phobos/StdCover
 */

module phobos.cover;

private import phobos.stdio;
private import phobos.file;
private import phobos.bitarray;

private
{
    struct Cover
    {
	char[] filename;
	BitArray valid;
	uint[] data;
    }

    Cover[] gdata;
    char[] srcpath;
    char[] dstpath;
    bool merge;
}

/***********************************
 * Set path to where source files are located.
 */

void setSourceDir(char[] pathname)
{
    srcpath = pathname;
}

/***********************************
 * Set path to where listing files are to be written.
 */

void setDestDir(char[] pathname)
{
    srcpath = pathname;
}

/***********************************
 * Set merge mode.
 * Params:
 *	flag = true means new data is summed with existing data in the
 *		listing file; false means a new listing file is always
 *		created.
 */

void setMerge(bool flag)
{
    merge = flag;
}

extern (C) void _d_cover_register(char[] filename, BitArray valid, uint[] data)
{
    //printf("_d_cover_register()\n");
    //printf("\tfilename = '%.*s'\n", filename);

    Cover c;
    c.filename = filename;
    c.valid = valid;
    c.data = data;

    gdata ~= c;
}

static ~this()
{
    //printf("cover.~this()\n");

    foreach (Cover c; gdata)
    {
	//printf("filename = '%.*s'\n", c.filename);

	// Generate source file name
	char[] srcfilename = phobos.path.join(srcpath, c.filename);

	char[] buf = cast(char[])phobos.file.read(srcfilename);
	char[][] lines = phobos.string.splitlines(buf);

	// Generate listing file name
	char[] lstfilename = phobos.path.addExt(phobos.path.getBaseName(c.filename), "lst");

	if (merge && exists(lstfilename) && isfile(lstfilename))
	{
	    char[] lst = cast(char[])phobos.file.read(lstfilename);
	    char[][] lstlines = phobos.string.splitlines(lst);

	    for (size_t i = 0; i < lstlines.length; i++)
	    {
		if (i >= c.data.length)
		    break;
		int count = 0;
		foreach (char c; lstlines[i])
		{
		    switch (c)
		    {	case ' ':
			    continue;
			case '0': case '1': case '2': case '3': case '4':
			case '5': case '6': case '7': case '8': case '9':
			    count = count * 10 + c - '0';
			    continue;
			default:
			    break;
		    }
		    break;
		}
		//printf("[%d] %d\n", i, count);
		c.data[i] += count;
	    }
	}

	FILE *flst = phobos.c.stdio.fopen(lstfilename, "wb");
	if (!flst)
	    throw new phobos.file.FileException(lstfilename, "cannot open for write");

	uint nno;
	uint nyes;

	for (int i = 0; i < c.data.length; i++)
	{
	    //printf("[%2d] = %u\n", i, c.data[i]);
	    if (i < lines.length)
	    {
		uint n = c.data[i];
		char[] line = lines[i];
		line = phobos.string.expandtabs(line);
		if (n == 0)
		{
		    if (c.valid[i])
		    {	nno++;
			fwritefln(flst, "0000000|%s", line);
		    }
		    else
			fwritefln(flst, "       |%s", line);
		}
		else
		{   nyes++;
		    fwritefln(flst, "%7s|%s", n, line);
		}
	    }
	}

	if (nyes + nno)		// no divide by 0 bugs
	    fwritefln(flst, "%s is %s%% covered", c.filename, (nyes * 100) / (nyes + nno));

	phobos.c.stdio.fclose(flst);
    }
}


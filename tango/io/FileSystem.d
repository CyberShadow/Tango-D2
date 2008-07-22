/*******************************************************************************

        copyright:      Copyright (c) 2004 Kris Bell. All rights reserved

        license:        BSD style: $(LICENSE)

        version:        Mar 2004: Initial release
        version:        Feb 2007: Now using mutating paths

        author:         Kris, Chris Sauls (Win95 file support)

*******************************************************************************/

module tango.io.FileSystem;

private import  tango.sys.Common;

private import  tango.io.Path;

private import  tango.io.FilePath;

private import  tango.core.Exception;

version (Win32)
        {
        private import Text = tango.text.Util;
        private extern (Windows) DWORD GetLogicalDriveStringsA (DWORD, LPSTR);
        }

version (Posix)
        {
        private import tango.stdc.string;
        private import tango.stdc.posix.unistd;

        private import tango.io.FileConduit;
        private import Integer = tango.text.convert.Integer;
        }

/*******************************************************************************

        Models an OS-specific file-system. Included here are methods to
        manipulate the current working directory, and to convert a path
        to its absolute form.

*******************************************************************************/

struct FileSystem
{
        /***********************************************************************

                Convert the provided path to an absolute path, using the
                current working directory where prefix is not provided. 
                If the given path is already an absolute path, return it 
                intact.

                Returns the provided path, adjusted as necessary

        ***********************************************************************/

        static FilePath toAbsolute (FilePath target, char[] prefix=null)
        {
                if (! target.isAbsolute)
                   {
                   if (prefix is null)
                       prefix = getDirectory;

                   target.prepend (target.padded(prefix));
                   }
                return target;
        }

        /***********************************************************************

                Convert the provided path to an absolute path, using the
                current working directory where prefix is not provided. 
                If the given path is already an absolute path, return it 
                intact.

                Returns the provided path, adjusted as necessary

        ***********************************************************************/

        static char[] toAbsolute (char[] path, char[] prefix=null)
        {
                scope target = new FilePath (path);
                return toAbsolute (target, prefix).toString;
        }

        /***********************************************************************

                Compare to paths for absolute equality. The given prefix
                is prepended to the paths where they are not already in
                absolute format (start with a '/'). Where prefix is not
                provided, the current working directory will be used

                Returns true if the paths are equivalent, false otherwise

        ***********************************************************************/

        static bool equals (char[] path1, char[] path2, char[] prefix=null)
        {
                scope p1 = new FilePath (path1);
                scope p2 = new FilePath (path2);
                return (toAbsolute(p1, prefix) == toAbsolute(p2, prefix)) is 0;
        }

        /***********************************************************************

        ***********************************************************************/

        private static void exception (char[] msg)
        {
                throw new IOException (msg);
        }

        /***********************************************************************

        ***********************************************************************/

        version (Win32)
        {
                /***************************************************************

                        Set the current working directory

                ***************************************************************/

                static void setDirectory (char[] path)
                {
                        version (Win32SansUnicode)
                                {
                                char[MAX_PATH+1] tmp = void;
                                tmp[0..path.length] = path;
                                tmp[path.length] = 0;

                                if (! SetCurrentDirectoryA (tmp.ptr))
                                      exception ("Failed to set current directory");
                                }
                             else
                                {
                                // convert into output buffer
                                wchar[MAX_PATH+1] tmp = void;
                                assert (path.length < tmp.length);
                                auto i = MultiByteToWideChar (CP_UTF8, 0, 
                                                              cast(PCHAR)path.ptr, path.length, 
                                                              tmp.ptr, tmp.length);
                                tmp[i] = 0;

                                if (! SetCurrentDirectoryW (tmp.ptr))
                                      exception ("Failed to set current directory");
                                }
                }

                /***************************************************************

                        Return the current working directory

                ***************************************************************/

                static char[] getDirectory ()
                {
                        char[] path;

                        version (Win32SansUnicode)
                                {
                                int len = GetCurrentDirectoryA (0, null);
                                auto dir = new char [len];
                                GetCurrentDirectoryA (len, dir.ptr);
                                if (len)
                                   {
                                   dir[len-1] = '/';                                   
                                   path = standard (dir);
                                   }
                                else
                                   exception ("Failed to get current directory");
                                }
                             else
                                {
                                wchar[MAX_PATH+2] tmp = void;

                                auto len = GetCurrentDirectoryW (0, null);
                                assert (len < tmp.length);
                                auto dir = new char [len * 3];
                                GetCurrentDirectoryW (len, tmp.ptr); 
                                auto i = WideCharToMultiByte (CP_UTF8, 0, tmp.ptr, len, 
                                                              cast(PCHAR)dir.ptr, dir.length, null, null);
                                if (len && i)
                                   {
                                   path = standard (dir[0..i]);
                                   path[$-1] = '/';
                                   }
                                else
                                   exception ("Failed to get current directory");
                                }

                        return path;
                }

                /***************************************************************
                        
                        List the set of root devices (C:, D: etc)

                ***************************************************************/

                static char[][] roots ()
                {
                        int             len;
                        char[]          str;
                        char[][]        roots;

                        // acquire drive strings
                        len = GetLogicalDriveStringsA (0, null);
                        if (len)
                           {
                           str = new char [len];
                           GetLogicalDriveStringsA (len, cast(PCHAR)str.ptr);

                           // split roots into seperate strings
                           roots = Text.delimit (str [0 .. $-1], "\0");
                           }
                        return roots;
                }
        }

        /***********************************************************************

        ***********************************************************************/

        version (Posix)
        {
                /***************************************************************

                        Set the current working directory

                ***************************************************************/

                static void setDirectory (char[] path)
                {
                        char[512] tmp = void;
                        tmp [path.length] = 0;
                        tmp[0..path.length] = path;

                        if (tango.stdc.posix.unistd.chdir (tmp.ptr))
                            exception ("Failed to set current directory");
                }

                /***************************************************************

                        Return the current working directory

                ***************************************************************/

                static char[] getDirectory ()
                {
                        char[512] tmp = void;

                        char *s = tango.stdc.posix.unistd.getcwd (tmp.ptr, tmp.length);
                        if (s is null)
                            exception ("Failed to get current directory");

                        auto path = s[0 .. strlen(s)+1].dup;
                        path[$-1] = '/';
                        return path;
                }

                /***************************************************************

                        List the set of root devices.

                 ***************************************************************/

                static char[][] roots ()
                {
                        version(darwin)
                        {
                            assert(0);
                        }
                        else
                        {
                            char[] path = "";
                            char[][] list;
                            int spaces;

                            auto fc = new FileConduit("/etc/mtab");
                            scope (exit)
                                   fc.close;
                            
                            auto content = new char[cast(int) fc.length];
                            fc.input.read (content);
                            
                            for(int i = 0; i < content.length; i++)
                            {
                                if(content[i] == ' ') spaces++;
                                else if(content[i] == '\n')
                                {
                                    spaces = 0;
                                    list ~= path;
                                    path = "";
                                }
                                else if(spaces == 1)
                                {
                                    if(content[i] == '\\')
                                    {
                                        path ~= Integer.parse(content[++i..i+3], 8u);
                                        i += 2;
                                    }
                                    else path ~= content[i];
                                }
                            }
                            
                            return list;
                        }
                }
        }
}


/******************************************************************************

******************************************************************************/

debug (FileSystem)
{
        import tango.io.Stdout;

        static void foo (FilePath path)
        {
        Stdout("all: ") (path).newline;
        Stdout("path: ") (path.path).newline;
        Stdout("file: ") (path.file).newline;
        Stdout("folder: ") (path.folder).newline;
        Stdout("name: ") (path.name).newline;
        Stdout("ext: ") (path.ext).newline;
        Stdout("suffix: ") (path.suffix).newline.newline;
        }

        void main() 
        {
        Stdout.formatln ("dir: {}", FileSystem.getDirectory);

        auto path = new FilePath (".");
        foo (path);

        path.set ("..");
        foo (path); 

        path.set ("...");
        foo (path); 

        path.set (r"/x/y/.file");
        foo (path); 

        path.suffix = ".foo";
        foo (path);

        path.set ("file.bar");
        FileSystem.toAbsolute(path);
        foo(path);

        path.set (r"arf/test");
        foo(path);
        FileSystem.toAbsolute(path);
        foo(path);

        path.name = "foo";
        foo(path);

        path.suffix = ".d";
        path.name = path.suffix;
        foo(path);

        }
}

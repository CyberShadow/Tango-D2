/******************************************************************************
 *
 * copyright:   Copyright &copy; 2007 Daniel Keep.  All rights reserved.
 * license:     BSD style: $(LICENSE)
 * version:     Initial release: December 2007
 * authors:     Daniel Keep
 * credits:     Thanks to John Reimer for helping test this module under
 *              Linux.
 *
 ******************************************************************************/

module tango.io.device.TempFile;

import Path = tango.io.Path;
import tango.math.random.Kiss : Kiss;
import tango.io.device.Device : Device;
import tango.io.device.File : File;
import tango.io.FilePath : FilePath;
import tango.stdc.stringz : toStringz, toString16z;

/******************************************************************************
 ******************************************************************************/

version( Win32 )
{
    import tango.sys.Common : DWORD, LONG, MAX_PATH, PCHAR, CP_UTF8;

    enum : DWORD { FILE_FLAG_OPEN_REPARSE_POINT = 0x00200000 }

    version( Win32SansUnicode )
    {
        import tango.sys.Common :
            GetVersionExA, OSVERSIONINFO,
            CreateFileA, GENERIC_READ, GENERIC_WRITE,
            CREATE_NEW, FILE_ATTRIBUTE_NORMAL, FILE_FLAG_DELETE_ON_CLOSE,
            FILE_SHARE_READ, FILE_SHARE_WRITE,
            LPSECURITY_ATTRIBUTES,
            HANDLE, INVALID_HANDLE_VALUE,
            GetTempPathA, SetFilePointer, GetLastError, ERROR_SUCCESS;

        HANDLE CreateFile(char[] fn, DWORD da, DWORD sm,
                LPSECURITY_ATTRIBUTES sa, DWORD cd, DWORD faa, HANDLE tf)
        {
            return CreateFileA(toStringz(fn), da, sm, sa, cd, faa, tf);
        }

        char[] GetTempPath()
        {
            auto len = GetTempPathA(0, null);
            if( len == 0 )
                throw new Exception("could not obtain temporary path");

            auto result = new char[len+1];
            len = GetTempPathA(len+1, result.ptr);
            if( len == 0 )
                throw new Exception("could not obtain temporary path");
            return Path.standard(result[0..len]);
        }
    }
    else
    {
        import tango.sys.Common :
            MultiByteToWideChar, WideCharToMultiByte,
            GetVersionExW, OSVERSIONINFO,
            CreateFileW, GENERIC_READ, GENERIC_WRITE,
            CREATE_NEW, FILE_ATTRIBUTE_NORMAL, FILE_FLAG_DELETE_ON_CLOSE,
            FILE_SHARE_READ, FILE_SHARE_WRITE,
            LPSECURITY_ATTRIBUTES,
            HANDLE, INVALID_HANDLE_VALUE,
            GetTempPathW, SetFilePointer, GetLastError, ERROR_SUCCESS;

        HANDLE CreateFile(char[] fn, DWORD da, DWORD sm,
                LPSECURITY_ATTRIBUTES sa, DWORD cd, DWORD faa, HANDLE tf)
        {
                // convert into output buffer
                wchar[MAX_PATH+1] tmp = void;
                assert (fn.length < tmp.length);
                auto i = MultiByteToWideChar (CP_UTF8, 0, cast(PCHAR) fn.ptr, 
                                              fn.length, tmp.ptr, tmp.length);
                tmp[i] = 0;
                return CreateFileW(tmp.ptr, da, sm, sa, cd, faa, tf);
        }

        char[] GetTempPath()
        {
            auto len = GetTempPathW(0, null);
            if( len == 0 )
                throw new Exception("could not obtain temporary path");

            auto result = new wchar[len+1];
            len = GetTempPathW(len+1, result.ptr);
            if( len == 0 )
                throw new Exception("could not obtain temporary path");

            auto dir = new char [len * 3];
            auto i = WideCharToMultiByte (CP_UTF8, 0, result.ptr, len, 
                                          cast(PCHAR) dir.ptr, dir.length, null, null);
            return Path.standard (dir[0..i]);
        }
    }

    // Determines if reparse points (aka: symlinks) are supported.  Support
    // was introduced in Windows Vista.
    bool reparseSupported()
    {
        OSVERSIONINFO versionInfo = void;
        versionInfo.dwOSVersionInfoSize = versionInfo.sizeof;

        void e(){throw new Exception("could not determine Windows version");};

        version( Win32SansUnicode )
        {
            if( !GetVersionExA(&versionInfo) ) e();
        }
        else
        {
            if( !GetVersionExW(&versionInfo) ) e();
        }

        return (versionInfo.dwMajorVersion >= 6);
    }
}

else version( Posix )
{
    import tango.stdc.posix.fcntl : open, O_CREAT, O_EXCL, O_RDWR;
    import tango.stdc.posix.pwd : getpwnam;
    import tango.stdc.posix.unistd : access, getuid, lseek, unlink, W_OK;
    import tango.stdc.posix.sys.stat : stat, stat_t;
    
    import tango.sys.Environment : Environment;

    enum { O_LARGEFILE = 0x8000 }

    version( linux )
    {
        // NOTE: This constant is actually platform-dependant for some
        // God-only-knows reason.  *sigh*  It should be fine for 'generic'
        // architectures, but other ones will need to be double-checked.
        enum { O_NOFOLLOW = 00400000 }
    }
    else version( darwin )
    {
        enum { O_NOFOLLOW = 0x0100 }
    }
	else version( freebsd )
	{
		enum { O_NOFOLLOW = 0x0100 }
	}
    else
    {
        pragma(msg, "Cannot use TempFile: O_NOFOLLOW is not "
                "defined for this platform.");
        static assert(false);
    }
}

/******************************************************************************
 *
 * The TempFile class aims to provide a safe way of creating and destroying
 * temporary files.  The TempFile class will automatically close temporary
 * files when the object is destroyed, so it is recommended that you make
 * appropriate use of scoped destruction.
 *
 * Temporary files can be created with one of several styles, much like normal
 * Files.  TempFile styles have the following properties:
 *
 * $(UL
 * $(LI $(B Transience): this determines whether the file should be destroyed
 * as soon as it is closed (transient,) or continue to persist even after the
 * application has terminated (permanent.))
 * )
 *
 * Eventually, this will be expanded to give you greater control over the
 * temporary file's properties.
 *
 * For the typical use-case (creating a file to temporarily store data too
 * large to fit into memory,) the following is sufficient:
 *
 * -----
 *  {
 *      scope temp = new TempFile;
 *      
 *      // Use temp as a normal conduit; it will be automatically closed when
 *      // it goes out of scope.
 *  }
 * -----
 *
 * $(B Important):
 * It is recommended that you $(I do not) use files created by this class to
 * store sensitive information.  There are several known issues with the
 * current implementation that could allow an attacker to access the contents
 * of these temporary files.
 *
 * $(B Todo): Detail security properties and guarantees.
 *
 ******************************************************************************/

class TempFile : Device, Device.Seek
{
    //alias File.Cache Cache;
    //alias File.Share Share;

    /+enum Visibility : ubyte
    {
        /**
         * The temporary file will have read and write access to it restricted
         * to the current user.
         */
        User,
        /**
         * The temporary file will have read and write access available to any
         * user on the system.
         */
        World
    }+/

    /**************************************************************************
     * 
     * This enumeration is used to control whether the temporary file should
     * persist after the TempFile object has been destroyed.
     *
     **************************************************************************/

    enum Transience : ubyte
    {
        /**
         * The temporary file should be destroyed along with the owner object.
         */
        Transient,
        /**
         * The temporary file should persist after the object has been
         * destroyed.
         */
        Permanent
    }

    /+enum Sensitivity : ubyte
    {
        /**
         * Transient files will be truncated to zero length immediately
         * before closure to prevent casual filesystem inspection to recover
         * their contents.
         *
         * No additional action is taken on permanent files.
         */
        None,
        /**
         * Transient files will be zeroed-out before truncation, to mask their
         * contents from more thorough filesystem inspection.
         *
         * This option is not compatible with permanent files.
         */
        Low
        /+
        /**
         * Transient files will be overwritten first with zeroes, then with
         * ones, and then with a random 32- or 64-bit pattern (dependant on
         * which is most efficient.)  The file will then be truncated.
         *
         * This option is not compatible with permanent files.
         */
        Medium
        +/
    }+/

    /**************************************************************************
     * 
     * This structure is used to determine how the temporary files should be
     * opened and used.
     *
     **************************************************************************/
    struct Style
    {
        align(1):
        //Visibility visibility;      ///
        Transience transience;      ///
        //Sensitivity sensitivity;    ///
        //Share share;                ///
        //Cache cache;                ///
        int attempts = 10;          ///
    }

    /**
     * Style for creating a transient temporary file that only the current
     * user can access.
     */
    static const Style Transient = {Transience.Transient};
    /**
     * Style for creating a permanent temporary file that only the current
     * user can access.
     */
    static const Style Permanent = {Transience.Permanent};

    // Path to the temporary file
    private char[] _path;

    // Style we've opened with
    private Style _style;

    // Have we been detatched?
    private bool detached = false;

    ///
    this(Style style = Style.init)
    {
        create(style);
    }

    ///
    this(char[] prefix, Style style = Style.init)
    {
        create (prefix, style);
    }

    /// deprecated: please use char[] version instead
    deprecated this(FilePath prefix, Style style = Style.init)
    {
        this (prefix.toString.dup, style);
    }

    ~this()
    {
        if( !detached ) this.detach();
    }

    /**************************************************************************
     *
     * Returns the path of the temporary file.  Please note that depending
     * on your platform, the returned path may or may not actually exist if
     * you specified a transient file.
     *
     **************************************************************************/
    char[] path()
    {
        return _path;
    }

    /**************************************************************************
     *
     * Indicates the style that this TempFile was created with.
     *
     **************************************************************************/
    Style style()
    {
        return _style;
    }

    override char[] toString()
    {
        if( path.length > 0 )
            return path;
        else
            return "<TempFile>";
    }

    /**************************************************************************
     *
     * Returns the current cursor position within the file.
     *
     **************************************************************************/
    long position()
    {
        return seek(0, Anchor.Current);
    }

    /**************************************************************************
     *
     * Returns the total length, in bytes, of the temporary file.
     *
     **************************************************************************/
    long length()
    {
        long pos, ret;
        pos = position;
        ret = seek(0, Anchor.End);
        seek(pos);
        return ret;
    }

    /*
     * Creates a new temporary file with the given style.
     */
    private void create(Style style)
    {
        create(tempPath, style);
    }

    private void create(char[] prefix, Style style)
    {
        for( size_t i=0; i<style.attempts; ++i )
        {
            if( create_path(Path.join(prefix, randomName), style) )
                return;
        }

        error("could not create temporary file");
    }

    version( Win32 )
    {
        private static const DEFAULT_LENGTH = 6;
        private static const DEFAULT_PREFIX = "~t";
        private static const DEFAULT_SUFFIX = ".tmp";

        private static const JUNK_CHARS = 
            "abcdefghijklmnopqrstuvwxyz0123456789";

        /*
         * Returns the path to the temporary directory.
         */
        public static char[] tempPath()
        {
            return GetTempPath;
        }

        /*
         * Creates a new temporary file at the given path, with the specified
         * style.
         */
        private bool create_path(char[] path, Style style)
        {
            // TODO: Check permissions directly and throw an exception;
            // otherwise, we could spin trying to make a file when it's
            // actually not possible.

            // This code is largely stolen from File
            DWORD attr, share, access, create;

            alias DWORD[] Flags;

            // Basic stuff
            access = GENERIC_READ | GENERIC_WRITE;
            share = 0; // No sharing
            create = CREATE_NEW;

            // Set up flags
            attr = FILE_ATTRIBUTE_NORMAL;
            attr |= reparseSupported ? FILE_FLAG_OPEN_REPARSE_POINT : 0;
            if( style.transience == Transience.Transient )
                attr |= FILE_FLAG_DELETE_ON_CLOSE;

            handle = CreateFile(
                    /*lpFileName*/ path,
                    /*dwDesiredAccess*/ access,
                    /*dwShareMode*/ share,
                    /*lpSecurityAttributes*/ null,
                    /*dwCreationDisposition*/ CREATE_NEW,
                    /*dwFlagsAndAttributes*/ attr,
                    /*hTemplateFile*/ null
                    );

            if( handle is INVALID_HANDLE_VALUE )
                return false;

            _path = path;
            _style = style;
            return true;
        }

        // See DDoc version
        override long seek(long offset, Anchor anchor = Anchor.Begin)
        {
            LONG high = cast(LONG) (offset >> 32);
            long result = SetFilePointer (handle, cast(LONG) offset, 
                                          &high, anchor);

            if (result is -1 && 
                GetLastError() != ERROR_SUCCESS)
                error();

            return result + (cast(long) high << 32);
        }
    }
    else version( Posix )
    {
        private static const DEFAULT_LENGTH = 6;
        private static const DEFAULT_PREFIX = ".tmp";

        // Use "~" to work around a bug in DMD where it elides empty constants
        private static const DEFAULT_SUFFIX = "~";

        private static const JUNK_CHARS = 
            "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
            "abcdefghijklmnopqrstuvwxyz0123456789";

        /*
         * Returns the path to the temporary directory.
         */
        public static char[] tempPath()
        {
            // Check for TMPDIR; failing that, use /tmp
            if( auto tmpdir = Environment.get("TMPDIR") )
                return tmpdir.dup;
            else
                return "/tmp/";
        }

        /*
         * Creates a new temporary file at the given path, with the specified
         * style.
         */
        private bool create_path(char[] path, Style style)
        {
            // Check suitability
            {
                auto parent = Path.parse(path).path;
                auto parentz = toStringz(parent);

                // Make sure we have write access
                if( access(parentz, W_OK) == -1 )
                    error("do not have write access to temporary directory");

                // Get info on directory
                stat_t sb;
                if( stat(parentz, &sb) == -1 )
                    error("could not stat temporary directory");

                // Get root's UID
                auto pwe = getpwnam("root");
                if( pwe is null ) error("could not get root's uid");
                auto root_uid = pwe.pw_uid;
                
                // Make sure either we or root are the owner
                if( !(sb.st_uid == root_uid || sb.st_uid == getuid) )
                    error("temporary directory owned by neither root nor user");

                // Check to see if anyone other than us can write to the dir.
                if( (sb.st_mode & 022) != 0 && (sb.st_mode & 01000) == 0 )
                    error("sticky bit not set on world-writable directory");
            }

            // Create file
            {
                auto flags = O_LARGEFILE | O_CREAT | O_EXCL
                    | O_NOFOLLOW | O_RDWR;

                auto pathz = toStringz(path);

                handle = open(pathz, flags, 0600);
                if( handle is -1 )
                    return false;

                if( style.transience == Transience.Transient )
                {
                    // BUG TODO: check to make sure the path still points
                    // to the file we opened.  Pity you can't unlink a file
                    // descriptor...

                    // NOTE: This should be an exception and not simply
                    // returning false, since this is a violation of our
                    // guarantees.
                    if( unlink(pathz) == -1 )
                        error("could not remove transient file");
                }

                _path = path;
                _style = style;

                return true;
            }
        }

        // See DDoc version
        long seek(long offset, Anchor anchor = Anchor.Begin)
        {
            assert( offset <= uint.max );
            long result = lseek(handle, cast(off_t) offset, anchor);
            if (result is -1)
                error();
            return result;
        }
    }
    else version( DDoc )
    {
        /**********************************************************************
         * 
         * Seeks the temporary file's cursor to the given location.
         *
         **********************************************************************/
        long seek(long offset, Anchor anchor = Anchor.Begin);

        /**********************************************************************
         * 
         * Returns the path to the directory where temporary files will be
         * created.  The returned path is safe to mutate.
         *
         **********************************************************************/
        char[] tempPath();
    }
    else
    {
        static assert(false, "Unsupported platform");
    }

    /*
     * Generates a new random file name, sans directory.
     */
    private char[] randomName(uint length=DEFAULT_LENGTH,
            char[] prefix=DEFAULT_PREFIX,
            char[] suffix=DEFAULT_SUFFIX)
    {
        auto junk = new char[length];
        scope(exit) delete junk;

        foreach( ref c ; junk )
            c = JUNK_CHARS[Kiss.instance.toInt($)];

        return prefix~junk~suffix;
    }
    
    override void detach()
    {
        static assert( !is(Sensitivity) );
        super.detach();
        detached = true;
    }
}

version( TempFile_SelfTest ):

import tango.io.Console : Cin;
import tango.io.Stdout : Stdout;

void main()
{
    Stdout(r"
Please ensure that the transient file no longer exists once the TempFile
object is destroyed, and that the permanent file does.  You should also check
the following on both:

 * the file should be owned by you,
 * the owner should have read and write permissions,
 * no other permissions should be set on the file.

For POSIX systems:

 * the temp directory should be owned by either root or you,
 * if anyone other than root or you can write to it, the sticky bit should be
   set,
 * if the directory is writable by anyone other than root or the user, and the
   sticky bit is *not* set, then creating the temporary file should fail.

You might want to delete the permanent one afterwards, too. :)")
    .newline;

    Stdout.formatln("Creating a transient file:");
    {
        scope tempFile = new TempFile(/*TempFile.UserPermanent*/);
        scope(exit) tempFile.detach;

        Stdout.formatln(" .. path: {}", tempFile);

        tempFile.write("Transient temp file.");

        char[] buffer = new char[1023];
        tempFile.seek(0);
        buffer = buffer[0..tempFile.read(buffer)];

        Stdout.formatln(" .. contents: \"{}\"", buffer);

        Stdout(" .. press Enter to destroy TempFile object.").newline;
        Cin.copyln();
    }

    Stdout.newline;

    Stdout.formatln("Creating a permanent file:");
    {
        scope tempFile = new TempFile(TempFile.Permanent);
        scope(exit) tempFile.detach;

        Stdout.formatln(" .. path: {}", tempFile);

        tempFile.write("Permanent temp file.");

        char[] buffer = new char[1023];
        tempFile.seek(0);
        buffer = buffer[0..tempFile.read(buffer)];

        Stdout.formatln(" .. contents: \"{}\"", buffer);

        Stdout(" .. press Enter to destroy TempFile object.").flush;
        Cin.copyln();
    }

    Stdout("\nDone.").newline;
}



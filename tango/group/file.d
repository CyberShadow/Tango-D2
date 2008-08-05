/*******************************************************************************

        copyright:      Copyright (c) 2007 Kris Bell. All rights reserved

        license:        BSD style: $(LICENSE)
        
        version:        Dec 2007: Initial release

        author:         Kris

        Convenience module to import tango.io 

*******************************************************************************/

module tango.group.file;

pragma (msg, "Please post your usage of tango.group to this ticket: http://dsource.org/projects/tango/ticket/1013");

public  import  tango.io.File,
                tango.io.Print,
                tango.io.Stdout,
                tango.io.Buffer,
                tango.io.device.Conduit,
                tango.io.Console,
                tango.io.FilePath,
                tango.io.FileSystem,
                tango.io.device.FileConduit,
                tango.io.UnicodeFile,
                tango.io.MappedBuffer;

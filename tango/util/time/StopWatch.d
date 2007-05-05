/*******************************************************************************

        copyright:      Copyright (c) 2007 Kris Bell. All rights reserved

        license:        BSD style: $(LICENSE)
      
        version:        Feb 2007: Initial release
        
        author:         Kris

*******************************************************************************/

module tango.util.time.StopWatch;

public import tango.core.Type : Interval;

/*******************************************************************************

*******************************************************************************/

version (Win32)
{
        private extern (Windows) 
        {
        int QueryPerformanceCounter   (ulong *count);
        int QueryPerformanceFrequency (ulong *frequency);
        }
}

version (Posix)
{
        private import tango.stdc.posix.sys.time;
}

/*******************************************************************************

        Timer for measuring small intervals, such as the duration of a 
        subroutine or other reasonably granular of code.
        ---
        StopWatch elapsed;

        elapsed.start;

        // do something
        // ...

        Interval i = elapsed.stop;
        ---

        The measured interval is in units of seconds, using floating-
        point to represent fractions. This approach is more flexible 
        than integer arithmetic since it migrates trivially to more
        capable timer hardware (there no implicit granularity to the
        measurable intervals, except the limits of fp representation)

        StopWatch is accurate only to the extent of what the underlying 
        OS supports. On linux systems, this accuracy is typically 1 us at 
        best. Win32 is generally more accurate.

        There is some minor overhead in using StopWatch, so take that into 
        account

*******************************************************************************/

public struct StopWatch
{
        private Interval        started;
        private static Interval multiplier = 1.0 / 1_000_000.0;

        version (Win32)
                 private static ulong timerStart;

        /***********************************************************************
                
                Start the timer

        ***********************************************************************/
        
        void start ()
        {
                started = timer;
        }

        /***********************************************************************
                
                Stop the timer and return elapsed duration since start()

        ***********************************************************************/
        
        Interval stop ()
        {
                return timer - started;
        }

        /***********************************************************************
                
                Setup timing information for later use

        ***********************************************************************/

        static this()
        {
                version (Win32)
                {
                        ulong freq;

                        if (! QueryPerformanceFrequency (&freq))
                              throw new Exception ("high-resolution timer is not available");
                        
                        QueryPerformanceCounter (&timerStart);
                        multiplier = 1.0 / freq;       
                }
        }

        /***********************************************************************
                
                Return the current time as an Interval

        ***********************************************************************/

        private static Interval timer ()
        {
                version (Posix)       
                {
                        timeval tv;
                        if (gettimeofday (&tv, null))
                            throw new Exception ("Timer :: linux timer is not available");

                        return (cast(Interval) tv.tv_sec) + tv.tv_usec * multiplier;
                }

                version (Win32)
                {
                        ulong now;

                        QueryPerformanceCounter (&now);
                        return (now - timerStart) * multiplier;
                }
        }
}


/*******************************************************************************

*******************************************************************************/

debug (StopWatch)
{
        import tango.io.Stdout;

        void main() 
        {
                StopWatch t;
                t.start;

                for (int i=0; i < 10_000_000; ++i)
                    {}
                Stdout.format ("{:f9}", t.stop).newline;
        }
}
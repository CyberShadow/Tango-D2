#!/bin/sh

# Written by Anders F. Björklund
cd "`dirname \"$0\"`"

# set up symbolic links to compilers without version suffix

for target in powerpc-apple-darwin8 i686-apple-darwin8; do
  for prefix in /usr /usr/local /opt/gdc /sw /opt/local; do
  if [ -x $prefix/bin/gdc ]; then
    version=`$prefix/bin/gdc -dumpversion`
    for program in gcc g++ gdc; do
    if [ ! -L "$prefix/bin/$target-$program" ]; then
      if [ -x "$prefix/bin/$target-$program-$version" ]; then
      echo "$prefix/bin/$target-$program -> $target-$program-$version"
      sudo ln -s $target-$program-$version $prefix/bin/$target-$program
      fi
    fi
    done
  fi
  if [ -x "$prefix/bin/gdmd" ]; then
    for program in gdmd; do
    if [ ! -L "$prefix/bin/$target-$program" ]; then
      echo "$prefix/bin/$target-$program -> $program"
      sudo ln -s $program $prefix/bin/$target-$program
    fi
    done
  fi
  done
done

# build Universal Binary versions of the Tango libraries

HOME=`pwd` make -s clean -fgdc-posix.mak

LIBS="common/libtango.a gc/libbasic.a libgphobos.a"

for lib in $LIBS; do test -r $lib && rm $lib; done

./build-gdc-x.sh powerpc-apple-darwin8
for lib in $LIBS; do mv $lib $lib.ppc; done

./build-gdc-x.sh i686-apple-darwin8
for lib in $LIBS; do mv $lib $lib.i386; done

for lib in $LIBS; do \
lipo -create -output $lib $lib.ppc $lib.i386; done

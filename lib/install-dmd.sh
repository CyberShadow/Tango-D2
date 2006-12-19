#!/bin/bash

#
#    Copyright (c) 2006 Alexander Panek
#
# This software is provided 'as-is', without any express or implied warranty.
# In no event will the authors be held liable for any damages arising from the
# use of this software.
#
# Permission is granted to anyone to use this software for any purpose,
# including commercial applications, and to alter it and redistribute it
# freely, subject to the following restrictions:
#
# 1. The origin of this software must not be misrepresented; you must not claim
#    that you wrote the original software. If you use this software in a
#    product, an acknowledgment in the product documentation would be 
#    appreciated but is not required.
#
# 2. Altered source versions must be plainly marked as such, and must not
#    be misrepresented as being the original software.
#
# 3. This notice may not be removed or altered from any source distribution.
#

# local directories
PREFIX=/usr/local
MAN_DIR=/usr/share/man/man1
# mirrors & filename
DMD_MIRROR=http://ftp.digitalmars.com
DMD_FILENAME=dmd.zip
DMD_CONF=/etc/dmd.conf
TANGO_REPOSITORY='http://svn.dsource.org/projects/tango/trunk/'
DSSS_ARCHIVE='http://svn.dsource.org/projects/dsss/downloads/0.9/dsss-0.9-dmd-gnuWlinux.tar.gz'
# state variables (changable through --flags)
ROOT=1
DMD_DOWNLOAD=0
TANGO_DOWNLOAD=0
DMD_INSTALL=0
DSSS_INSTALL=0
#
CLEANALL=1
# 42.
#DEBUG=0
#
#SIMULATE=0
#

## HELPER FUNCTIONS

# 'exception', prints first parameter and exits script totally.
die() {
	echo "$1"
	exit 0
}

# prints usage
usage() {
	cat <<EOF
Usage: $0 <install prefix> [OPTIONS]

Options:
	  --with-dmd: install DMD too (requires a dmd.zip in the current directory; use --download to get a fresh copy)
	              If you want to download DMD yourself, please go to http://digitalmars.com/d/ .
	  --version=[x[.]]xxx : Use a specific version of DMD
	                        Examples:
                               --version=0.176
                               --version=.176
                               --version=0176

	  --with-dsss: install DSSS (D Shared Software System) too. Requires an internet connection, for now.
	               See http://dsource.org/projects/dsss/ for more information on DSSS!

	  --no-root: Do not install a global dmd.conf (default: /etc/dmd.conf)
	  --no-clean: Do not remove DMD archive or Tango copy

	  --download: checkout a fresh copy of Tango (subversion required)
	  --download-dmd: Download a fresh copy of DMD (implies --with-dmd)
	  --download-all: Download DMD and checkout a fresh copy of Tango (implies --dmd, too)

	  --uninstall: Uninstall Tango
	  --uninstall-dmd: Uninstall Tango and DMD
	  --uninstall-dsss: Uninstall DSSS only
	  --uninstall-all: Uninstall Tango, DMD and DSSS

	  --help: Display this text
	
EOF

}

# gets printed after installation is finished successfully
finished() {
	cat <<EOF

-----------------------------------------------------------------
Tango has been installed successfully.
You can find documentation at http://dsource.org/projects/tango,
or locally in ${PREFIX}/include/tango/doc/.

General D documentation can be found at:
  o http://digitalmars.com/d/
  o http://dsource.org/projects/tutorials/wiki
  o http://dprogramming.com/
  o http://www.prowiki.org/wiki4d/wiki.cgi?FrontPage"

Enjoy your stay in the Tango dancing club! \\\\o \\o/ o//

EOF
}

download_dmd() {
	echo "Downloading dmd.zip from ${DMD_MIRROR}..."
	wget -c ${DMD_MIRROR}/${DMD_FILENAME} || die "Error downloading DMD. Aborting."
}

download_tango() {
	echo "Downloading Tango from ${TANGO_MIRROR} (subversion required)..."

	echo "..creating temporary directory tango/..."
	mkdir -p tango || die "Error while creating temporary directory."

	echo "..changing directory to tango/..."
	if [ ${SIMULATE} = 0 ]
	then
		cd tango || die "Error while changing directory (tango/)."
	fi

	echo "..checking out tango/trunk (quietly). This may take some time..."
	svn checkout -q ${TANGO_REPOSITORY} || die "Error while checking out."

	echo "..changing directory to tango/trunk/..."
	cd trunk || die "Error while changing directory (tango/trunk/)."

	echo "..moving dmd archive to current directory..."
	mv ../../${DMD_FILENAME} . || die "Error moving dmd archive to tango/trunk/."
}

install_dmd() {
	unzip_dmd
	copy_dmd
	copy_dmd_include
	copy_dmd_lib
	copy_dmd_doc
	cleanup_dmd
}

unzip_dmd() {
	if [ ! -f ${DMD_FILENAME} ]
	then
		die "Could not find dmd archive. Please use --download-dmd or manually download the file from ${DMD_MIRROR}. Aborting."
	fi

	echo "Extracting zip file..."
	unzip -q -d . ${DMD_FILENAME} || die 'Could not extract zip file. Aborting.'
}

copy_dmd() {
	echo "Copying compiler binaries..."

	echo "..creating ${PREFIX}/bin"
	mkdir -p ${PREFIX}/bin || die "Error creating directory (${PREFIX}/bin)."

	echo "..settin executable flag for dmd, objasm, dumpobj and rdmd..."
	chmod +x dmd/bin/{dmd,obj2asm,dumpobj,rdmd} || die "Error chmod-ing (dmd, objasm, dumpobj, rdmd)."

	echo "..copying executable files to ${PREFIX}/bin..."
	cp dmd/bin/dmd ${PREFIX}/bin || die "Error copying dmd/bin/dmd."
	cp dmd/bin/obj2asm ${PREFIX}/bin || die "Error copying dmd/bin/objasm."
	cp dmd/bin/dumpobj ${PREFIX}/bin || die "Error copying dmd/bin/dumpobj."
	cp dmd/bin/rdmd ${PREFIX}/bin || die "Error copying dmd/bin/rdmd."
}

copy_dmd_include() {
	echo "Copying runtime library sources..."

	echo "..creating ${PREFIX}/include"
	mkdir -p ${PREFIX}/include || die "Error creating ${PREFIX}/include."

	echo "..copying files"
	cp -r dmd/src/phobos ${PREFIX}/include || die "Error copying library sources to ${PREFIX}/include."
}

copy_dmd_doc() {
	echo "Copying D documentation and samples (Phobos)..."

	echo "..creating directories ${PREFIX}/doc/dmd/{src,samples}..."
	mkdir -p {${PREFIX}/doc/dmd/samples,${PREFIX}/doc/dmd/src} || die "Error creating documentation directories."

	cp -r dmd/html/d/* ${PREFIX}/doc/dmd/ || die "Error copying documentation."
	cp -r dmd/samples/d/* ${PREFIX}/doc/dmd/samples/ || die "Error copying samples."
	cp -r dmd/src/dmd/* ${PREFIX}/doc/dmd/src/ || die "Error copying source."
}

copy_dmd_lib() {
	echo "Copying runtime library..."

	echo "..creating ${PREFIX}/lib..."
	mkdir -p ${PREFIX}/lib || die "Error creating directory for runtime library (${PREFIX}/lib)."

	echo "..copying original libphobos.a"
	cp dmd/lib/libphobos.a ${PREFIX}/lib/ || die "Error copying libphobos.a."
#	cp dmd/lib/phobos.lib ${PREFIX}/lib/ || die "Error copying phobos.lib."
}

copy_dmd_man() {
	echo "Copying manpages to ${MAN_DIR}"
	cp dmd/man/man1/* ${MAN_DIR} || die "Error copying manpages."
}

install_tango() {
	echo "Installing Tango..."

	echo "..checking if we have a local copy of the repository or an extracted package..."
	if [ `find . -name .svn | grep '' -c` -gt 0 ]
	then
		echo "...svn files found, using svn export to copy (avoiding recreation of .svn* files)..."

		echo "...checking if directory already exists (svn export will fail, if so)..."
		if [ -f ${PREFIX}/include/tango ]
		then
			die "Error, destination does already exist; please delete it or change prefix."
		else
			echo "....everything fine; doing svn export..."
			mkdir -p ${PREFIX}/include
			svn export --force . ${PREFIX}/include/tango || die "Error exporting Tango via svn export."
		fi
	else
		"...no subversion files found, using normal copy method..."
		echo "...creating directory ${PREFIX}/include..."
		mkdir -p ${PREFIX}/include/tango || die "Error creating Tango directory."
		cp -r ./* ${PREFIX}/include/tango || die "Error copying Tango to new directory."
	fi

	if [ ! -f "lib/libphobos.a" ]
	then
		cd lib/
		./build-dmd.sh || die "Error building library."
		cd ../
	fi
	
	if [ -f "${PREFIX}/lib/libphobos.a" ]
	then
		mv ${PREFIX}/lib/libphobos.a ${PREFIX}/lib/original_libphobos.a || die "Error renaming original libphobos.a"
	fi

	cp lib/libphobos.a ${PREFIX}/lib/libphobos.a || die "Error copying Tango's libphobos.a replacement to ${PREFIX}/lib/libphobos.a"
}

dmd_conf_install() {
	echo "Modifying or creating dmd.conf file (first found by whereis command)..."

	echo "..trying to find dmd.conf..."
	if [ `whereis dmd | tr ' ' '\n' | grep dmd.conf -c` -lt 1 ]
	then
		echo "..no dmd.conf found, installing default one to /etc/dmd.conf..."

		# no dmd.conf installed yet, install a fresh one!
		echo "[Environment]" > ${DMD_CONF} || die "Error writing to ${DMD_CONF}."
		echo ";DFLAGS=-I\"${PREFIX}/include/phobos -L-L${PREFIX}/lib\"" >> ${DMD_CONF} || die "Error writing to ${DMD_CONF}."
		echo "DFLAGS=-I\"${PREFIX}/include/tango -L-L${PREFIX}/lib/\" -version=Posix -version=Tango" >> ${DMD_CONF} || die "Error writing to ${DMD_CONF}."
	else
		echo -n "..dmd.conf found: `whereis dmd | tr ' ' '\n' | grep dmd.conf -m 1` -- doing sed magic."

		sed -e 's/DFLAGS=-I.*phobos.*/;&\nDFLAGS=-I"\${PREFIX}\/include\/tango\/ -L-L\${PREFIX}\/lib\/ -version=Posix -version=Tango"/g' `whereis dmd | tr ' ' '\n' | grep -v X | grep -m 1 dmd.conf` > _dmd.conf || die
		mv _dmd.conf `whereis dmd | tr ' ' '\n' | grep -v X | grep -m 1 dmd.conf` || die # replace old dmd.conf with changed dmd.conf
	fi
}

cleanup_tango() {
	echo "Cleaning up (removing) tango/trunk/..."

	cd ../../ || die "Error while cleaning up."
	rm -rf tango || die "Error while cleaning up."
}
	
cleanup_dmd() {
	echo "Cleaning up tango/trunk/dmd/..."

	rm -rf dmd/ || die "Error while cleaning up."

	if [ ${CLEANALL} = 1 ]
	then
		echo "Removing dmd archive..."
		rm -r ${DMD_FILENAME} || die "Error while removing dmd.zip."
	fi
}

install_dsss() {
	echo "Installing DSSS to ${PREFIX}..."

	echo "..trying to download archive (this may take a while)..."
	wget -c ${DSSS_ARCHIVE} || die "Error downloading DSSS binary archive."

	echo "..extracting archive..."
	unzip -d dsss/ ${DSSS_ARCHIVE##*/} || die "Error extracting DSSS binary archive."

	echo "..copying files over to ${PREFIX}/..."
	cp -r dsss/dsss-0.9-dmd-gnuWlinux/* ${PREFIX}/ || die "Error copying DSSS to ${PREFIX}."

	echo "..cleaning up..."
	rm -rf dsss/ || die "Error while cleaning up DSSS temporaries."

	echo "DSSS installed."
	echo ""
}

## TO BE DONE ##
#uninstall_tango() {
	
#}

## TO BE DONE ##
#uninstall_dmd() {

#}

############################################################################################
############################################################################################
# ACTUAL START OF THE SCRIPT (or end of functions, depends on your pessimism/optimism ;) )
############################################################################################
############################################################################################

if [ -n "$1" ]
then
	PREFIX=$1
else
	usage
	die
fi

# Check for flags
for i in $*; 
do
	case "$i" in
		--with-dmd)
			DMD_INSTALL=1
		;;
		--with-dsss)
			DSSS_INSTALL=1
		;;
		--download)
			TANGO_DOWNLOAD=1
		;;
		--download-dmd)
			DMD_DOWNLOAD=1
			DMD_INSTALL=1
		;;
		--download-all)
			DMD_DOWNLOAD=1
			DMD_INSTALL=1
			TANGO_DOWNLOAD=1
		;;
		--no-root)
			ROOT=0
		;;
		--no-clean)
			CLEANALL=0
		;;
		--version=*)
			VERSION=`echo -n "${i}" | sed -n 's/^--version=[0-9]\?\.\?\([0-9]\{3\}\)/\1/p'` 
			
			if [  -n "${VERSION}" ]
			then
				DMD_FILENAME="dmd.${VERSION}.zip"
			else
				DMD_FILENAME="dmd.zip"
			fi
		;;
		--help)
			usage
			die
		;;
		--debug)
			DEBUG=1
		;;
		--simulate)
			SIMULATE=1
		;;
	esac
done

if [ ${DMD_DOWNLOAD} = 1 ]
then
	download_dmd
fi

if [ ${TANGO_DOWNLOAD} = 1 ]
then
	download_tango
fi

if [ ${DMD_INSTALL} = 1 ]
then
	install_dmd
fi

install_tango

if [ ${ROOT} = 1 ]
then
	dmd_conf_install
fi

if [ ${TANGO_DOWNLOAD} = 1 ]
then
	cleanup_tango
fi

finished

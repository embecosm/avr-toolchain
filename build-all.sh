#!/bin/sh

# Copyright (C) 2013 Embecosm Limited

# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

# This file is a script for building AVR tool chains under git.

# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 3 of the License, or (at your option)
# any later version.

# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.

# You should have received a copy of the GNU General Public License along
# with this program.  If not, see <http://www.gnu.org/licenses/>.          

#		      SCRIPT TO BUILD AVR-ELF TOOL CHAIN
#		      ==================================

# Invocation Syntax

#     build-all.sh [--install-dir <install_dir>]
#                  [--symlink-dir <symlink_dir>]
#                  [--auto-pull | --no-auto-pull]
#                  [--auto-checkout | --no-auto-checkout]
#                  [--unisrc | --no-unisrc]
#                  [--datestamp-install]
#                  [--jobs <count>] [--load <load>] [--single-thread]

# This script builds the AVR tool chain as held in git. It is assumed to be
# run from the toolchain directory (i.e. with binutils, cgen, gcc, newlib and
# gdb as peer directories).

# --install-dir <install_dir>

#     The directory in which the tool chain should be installed. Default
#     /opt/avr.

# --symlink-dir <symlink_dir>

#     If specified, the install directory will be symbolically linked to this
#     directory. Default not specified.

#     For example it may prove useful to install in a directory named with the
#     date and time when the tools were built, and then symbolically link to a
#     directory with a fixed name. By using the symbolic link in the users
#     PATH, the latest version of the tool chain will be used, while older
#     versions of the tool chains remain available under the dated
#     directories.

# --auto-checkout | --no-auto-checkout

#     If specified, a "git checkout" will be done in each component repository
#     to ensure the correct branch is checked out. Default is to checkout.

# --auto-pull | --no-auto-pull

#     If specified, a "git pull" will be done in each component repository
#     after checkout to ensure the latest code is in use. Default is to pull.

# --unisrc | --no-unisrc

#     If --unisrc is specified, rebuild the unified source tree. If
#     --no-unisrc is specified, do not rebuild it. The default is --unisrc.

# --datestamp-install

#     If specified, this will append a date and timestamp to the install
#     directory name. (see the comments under --symlink-dir above for reasons
#     why this might be useful).

# --jobs <count>

#     Specify that parallel make should run at most <count> jobs. The default
#     is <count> equal to one more than the number of processor cores shown by
#     /proc/cpuinfo.

# --load <load>

#     Specify that parallel make should not start a new job if the load
#     average exceed <load>. The default is <load> equal to one more than the
#     number of processor cores shown by /proc/cpuinfo.

# --single-thread

#     Equivalent to --jobs 1 --load 1000. Only run one job at a time, but run
#     whatever the load average.

# Where directories are specified as arguments, they are relative to the
# current directory, unless specified as absolute names.

# ------------------------------------------------------------------------------
# Unset variables, which if inherited as environment variables from the caller
# could cause us grief.
unset symlinkdir
unset parallel
unset datestamp
unset jobs
unset load

# Set defaults for some options
rootdir=`(cd .. && pwd)`
unisrc="unisrc-mainline"
builddir="${rootdir}/bd-mainline"
logdir="${rootdir}/logs-mainline"
installdir="/opt/avr"
autocheckout="--auto-checkout"
autopull="--auto-pull"
do_unisrc="--unisrc"
make_load="`(echo processor; cat /proc/cpuinfo 2>/dev/null) \
           | grep -c processor`"
jobs=${make_load}
load=${make_load}

# Parse options
until
opt=$1
case ${opt} in
    --install-dir)
	shift
	installdir=$1
	;;

    --symlink-dir)
	shift
	symlinkdir=$1
	;;

    --auto-checkout | --no-auto-checkout)
	autocheckout=$1
	;;

    --auto-pull | --no-auto-pull)
	autopull=$1
	;;

    --unisrc | --no-unisrc)
	do_unisrc=$1
	;;

    --datestamp-install)
	datestamp=-`date -u +%F-%H%M`
	;;

    --jobs)
	shift
	jobs=$1
	;;

    --load)
	shift
	load=$1
	;;

    --single-thread)
	jobs=1
	load=1000
	;;

    ?*)
	echo "Unknown argument $1"
	echo
	echo "Usage: ./build-all.sh [--install-dir <install_dir>]"
	echo "                      [--symlink-dir <symlink_dir>]"
	echo "                      [--auto-checkout | --no-auto-checkout]"
        echo "                      [--auto-pull | --no-auto-pull]"
        echo "                      [--unisrc | --no-unisrc]"
	echo "                      [--datestamp-install]"
        echo "                      [--jobs <count>] [--load <load>]"
        echo "                      [--single-thread]"
	exit 1
	;;

    *)
	;;
esac
[ "x${opt}" = "x" ]
do
    shift
done

if [ "x$datestamp" != "x" ]
then
    installdir="${installdir}${datestamp}"
fi

parallel="-j ${jobs} -l ${load}"

# Make sure we stop if something failed.
trap "echo ERROR: Failed due to signal ; date ; exit 1" \
    HUP INT QUIT SYS PIPE TERM

# Exit immediately if a command exits with a non-zero status (but note this is
# not effective if the result of the command is being tested for, so we can
# still have custom error handling).
set -e

# Change to the root directory
cd "${rootdir}"

# Set up a logfile
mkdir -p "${logdir}"
logfile="${logdir}/build-$(date -u +%F-%H%M).log"
rm -f "${logfile}"

# Checkout the correct branch for each tool
echo "Checking out GIT trees" >> "${logfile}"
echo "======================" >> "${logfile}"

echo "Checking out GIT trees ..."
if ! ${rootdir}/toolchain/avr-versions.sh ${rootdir} ${autocheckout} \
         ${autopull} >> "${logfile}" 2>&1
then
    echo "ERROR: Failed to checkout GIT versions of tools"
    echo "- see ${logfile}"
    exit 1
fi

# Make a unified source tree in the build directory. Note that later versions
# override earlier versions with the current symlinking version.
if [ "x${do_unisrc}" = "x--unisrc" ]
then
    echo "Linking unified tree" >> "${logfile}"
    echo "====================" >> "${logfile}"

    echo "Linking unified tree ..."
    component_dirs="gdb binutils gcc"
    rm -rf ${unisrc}

    if ! mkdir -p ${unisrc}
    then
	echo "ERROR: Failed to create ${unisrc}"
	echo "- see ${logfile}"
	exit 1
    fi

    if ! ${rootdir}/toolchain/symlink-all.sh ${rootdir} ${unisrc} \
	"${component_dirs}" >> "${logfile}" 2>&1
    then
	echo "ERROR: Failed to symlink ${unisrc}"
	echo "- see ${logfile}"
	exit 1
    fi
fi

# Build the tool chain
echo "START AVR TOOLCHAIN BUILD: $(date)" >> "${logfile}"
echo "START AVR TOOLCHAIN BUILD: $(date)"

echo "Installing in ${installdir}" >> "${logfile}" 2>&1
echo "Installing in ${installdir}"

# We'll need the tool chain on the path.
export PATH=${installdir}/bin:$PATH

# Configure binutils, GCC and GDB
echo "Configuring tools" >> "${logfile}"
echo "=================" >> "${logfile}"

echo "Configuring tools ..."

# Create and change to the build dir
rm -rf "${builddir}"
mkdir -p "${builddir}"
cd "${builddir}"

# Configure the build
if "${rootdir}/${unisrc}"/configure --target=avr \
        --disable-libssp --disable-libssp --disable-nls \
        --with-pkgversion="AVR toolchain (built $(date +%Y%m%d))" \
        --with-bugurl="http://www.embecosm.com" \
        --enable-languages=c,c++ --prefix=${installdir} \
        --with-python >> "${logfile}" 2>&1
then
    echo "  finished configuring tools"
else
    echo "ERROR: tool configure failed."
    echo "- see ${logfile}"
    exit 1
fi

# Build binutils, GCC and GDB
echo "Building tools" >> "${logfile}"
echo "==============" >> "${logfile}"

echo "Building tools ..."

# Build all except GDB
cd "${builddir}"
if make ${parallel} all-build all-binutils all-gas all-ld all-gcc \
        all-target-libgcc all-target-libstdc++-v3 all-gdb >> "${logfile}" 2>&1
then
    echo "  finished building tools"
else
    echo "ERROR: tools build failed."
    echo "- see ${logfile}"
    exit 1
fi

# Install binutils, GCC and GDB
echo "Installing tools" >> "${logfile}"
echo "================" >> "${logfile}"

echo "Installing tools ..."

# Install all except GDB
cd "${builddir}"
if make install-binutils install-gas install-ld install-gcc \
        install-target-libgcc install-target-libstdc++-v3 install-gdb \
    >> "${logfile}" 2>&1
then
    echo "  finished installing tools"
else
    echo "ERROR: tools install failed."
    echo "- see ${logfile}"
    exit 1
fi

# Change to avr-libc, which builds in place.
cd "${rootdir}/avr-libc/avr-libc"

# Clean the directory. If we are already clean, this may fail, so don't worry.
echo "Cleaning avr-libc" >> "${logfile}"
echo "=================" >> "${logfile}"

echo "Cleaning avr-libc ..."

if make distclean > /dev/null 2>&1
then
    echo "  finished cleaning avr-libc"
else
    echo "  no clean needed for avr-libc"
fi

# Bootstrap the directory. We only need to do this one, but it doesn't matter
# if we do it more than once.
# TODO: Is there an easy way to avoid the duplication?
echo "Bootstrapping avr-libc" >> "${logfile}"
echo "======================" >> "${logfile}"

echo "Bootstrapping avr-libc ..."

if ./bootstrap >> "${logfile}" 2>&1
then
    echo "  finished bootstrapping avr-libc"
else
    echo "ERROR: bootstrap for avr-libc failed"
    echo "- see ${logfile}"
    exit 1
fi

# Configure avr-libc
echo "Configuring avr-libc" >> "${logfile}"
echo "====================" >> "${logfile}"

echo "Configuring avr-libc ..."

if ./configure --host=avr \
        --build=`${rootdir}/avr-libc/avr-libc/config.guess` \
        --prefix=${installdir} >> "${logfile}" 2>&1
then
    echo "  finished configuring avr-libc"
else
    echo "ERROR: avr-libc configure failed."
    echo "- see ${logfile}"
    exit 1
fi

# Build avr-libc
echo "Building avr-libc" >> "${logfile}"
echo "=================" >> "${logfile}"

echo "Building avr-libc ..."
if make >> "${logfile}" 2>&1
then
    echo "  finished building avr-libc"
else
    echo "ERROR: avr-libc build failed."
    echo "- see ${logfile}"
    exit 1
fi

# Install avr-libc
echo "Installing avr-libc" >> "${logfile}"
echo "===================" >> "${logfile}"

echo "Installing avr-libc ..."
if make install >> "${logfile}" 2>&1
then
    echo "  finished installing avr-libc"
else
    echo "ERROR: avr-libc install failed."
    echo "- see ${logfile}"
    exit 1
fi

echo "DONE AVR: $(date)" >> "${logfile}"
echo "DONE AVR: $(date)"
echo  "- see ${logfile}"

# Link to the defined place. Note the introductory comments about the need to
# specify explicitly the install directory.
if [ "x${symlinkdir}" != "x" ]
then
    rm -f ${symlinkdir}
    ln -s ${installdir} ${symlinkdir}
fi

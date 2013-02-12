#!/bin/sh

# Copyright (C) 2012, 2013 Embecosm Limited.

# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

# A script to test the AVR tool chain.

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

#		      SCRIPT TO RUN AVR REGRESSION TESTS
#		      ==================================

# This script runs the GNU regression tests for the avr-elf tool chain using
# the file structure as organized for git.  It is assumed to be run from the
# toolchain directory (i.e. with bd, binutils, cgen, gcc, newlib and gdb as peer
# directories).

# Invocation Syntax

#     run-tests.sh [--jobs <count>] [--load <load>][--single-thread]

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

# This script exits with zero if every test has passed and with non-zero value
# otherwise.

# -----------------------------------------------------------------------------
# Useful functions

# In bash we typically write function blah_blah () { }. However Ubuntu default
# /bin/sh -> dash doesn't recognize the "function" keyword. Its exclusion
# seems to work for both

# Function to run a particular test in a particular directory and then save
# the results.

# Usage:

#    run_check <tool> <resfile> <resfile> ...

# $1      - tool to test (e.g. "binutils" will run "check-binutils"
# $2, ... - results files w/o suffix
run_check () {
    tool=$1
    shift
    echo -n "Testing ${tool}..."
    echo "Regression test ${tool}" >> "${logfile}"
    echo "=======================" >> "${logfile}"

    cd ${builddir}

    # Important note. Must use --target_board=${board}, *not* --target_board
    # ${board} or GNU will think this is not parallelizable (horrible kludgy
    # test in the makefile).
    make ${PARALLEL} "check-${tool}" RUNTESTFLAGS="--target_board=${board}" \
	>> "${logfile}" 2>&1 || true
    echo
    cd - > /dev/null 2>&1

    # Save the results files to the results directory, removing spare line
    # feed characters at the end of lines and marking as not writable or
    # executable.

    for resfile in $*
    do
	resbase=`basename $resfile`

	if [ \( -r ${builddir}/${resfile}.log \) \
	    -a \( -r ${builddir}/${resfile}.sum \) ]
	then
            # Generated files have Windows line endings. dos2unix tool cannot
            # be used because sometimes it recognizes input files as binary
            # and refuses to work. Specifying option "-f" could solve this
            # problem, but RedHats dos2unix is too old to understand this
            # option. "tr -d '\015\" seems to be more universal solution.
	    tr -d '\015' < ${builddir}/${resfile}.log \
		> ${resdir}/${resbase}.log 2>> ${logfile}
	    chmod ugo-wx ${resdir}/${resbase}.log >> ${logfile} 2>&1
	    tr -d '\015' < ${builddir}/${resfile}.sum \
		> ${resdir}/${resbase}.sum 2>> ${logfile}
	    chmod ugo-wx ${resdir}/${resbase}.sum >>${logfile} 2>&1

            # Report the summary to the user
	    echo
	    echo "Summary for ${resbase}"
	    echo
	    sed -n -e '/Summary/,$p' < ${resdir}/${resbase}.sum | \
		grep '^#' || true
	    echo
	fi
    done
}

# ------------------------------------------------------------------------------
# Set default values for some options
rootdir=`(cd .. && pwd)`
builddir="${rootdir}/bd"
make_load="`(echo processor; cat /proc/cpuinfo 2>/dev/null) \
           | grep -c processor`"
jobs=${make_load}
load=${make_load}

# Parse options
until
opt=$1
case ${opt} in
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
	echo "Usage: ./run-tests.sh [--jobs <count>] [--load <load>]"
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

# Parallelism
PARALLEL="-j ${jobs} -l ${load}"

# Set up logfile and results directories if either does not exist
logfile="${rootdir}/logs/elf-check-$(date -u +%F-%H%M).log"
rm -f "${logfile}"
resdir="${rootdir}/results/elf-results-$(date -u +%F-%H%M)"
rm -rf ${resdir}
mkdir -p "${resdir}"

# Run regression and gather results. Gathering results is a separate function
# because of the variation in the location and number of results files for
# each tool.
export DEJAGNU=${rootdir}/toolchain/site.exp
echo "Running ELF regression tests" >> ${logfile}
echo "Running ELF regression tests"

# The target board to use
board=avr-sim

# Run the tests
# libgcc and libgloss tests are currently empty, so nothing to run or save.
run_check binutils            binutils/binutils
run_check gas                 gas/testsuite/gas
run_check ld                  ld/ld
run_check gcc                 gcc/testsuite/gcc/gcc gcc/testsuite/g++/g++
# run_check target-libgcc       avr-elf/libgcc/testsuite/libgcc
# run_check target-libgloss     avr-elf/libgloss/testsuite/libgloss
run_check target-newlib       avr-elf/newlib/testsuite/newlib
run_check target-libstdc++-v3 avr-elf/libstdc++-v3/testsuite/libstdc++
run_check sim                 sim/testsuite/sim
run_check gdb                 gdb/testsuite/gdb

#!/bin/sh

# Copyright (C) 2012, 2013 Synopsys Inc.
# Copyright (C) 2013 Embecosm Limited.

# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

# A script for running AVR regression tests.

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

# This script runs GNU regression tests for the AVR tool chain. It is loosely
# based on the test script for the Synopsys ARC GNU tool chain, and is
# designed to work with the source tree as organized in GitHub.

# The arguments have the following meaning.

# Invocation Syntax

#     run-tests.sh [--target-board <board>] [--multilib-options <options>]
#                  [--jobs <count>] [--load <load>][--single-thread]
#                  [--binutils | --no-binutils]
#                  [--gas | --no-gas]
#                  [--ld | --no-ld]
#                  [--c | --no-c]
#                  [--c++ | --no-c++]
#                  [--libgcc | --no-libgcc]
#                  [--libstdc++ | --no-libstdc++]
#                  [--gdb | --no-gdb]

# --multilib-options <options>

#     Additional options for compiling to allow multilib variants to be
#     tested.

# --target-board <board>

#     The board description for the AVR target. This should either be a
#     standard DejaGnu board, or a board in the dejagnu/baseboards directory
#     of the toolchain repository. Default value avr-sim

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

# --binutils | --no-binutils
# --gas | --no-gas
# --ld | --no-ld
# --c | --no-c
# --c++ | --no-c++
# --libgcc | --no-libgcc
# --libstdc++ | --no-libstdc++
# --gdb | --no-gdb

#     Specify which tests are to be run. By default all are enabled except
#     libgcc, for which no tests currently exist, c++, which has too many
#     failures (due to the lack of libstdc++) and libstdc++, which is not
#     currently supported for AVR.

# This script exits with zero if every test has passed and with non-zero value
# otherwise.

# -----------------------------------------------------------------------------
# Useful function

# Run a particular test, then save the results

# The results files are saved to the results directory, removing spare line
# feed characters at the end of lines and marking as not writable or
# executable.

# If the tool is empty, then we just save the results

# $1 - tool to test (e.g. "binutils" will run "check-binutils", or empty
# $2 - results file name w/o suffix
run_check () {
    tool=$1
    resfile=$2

    if [ "x${tool}" != "x" ]
    then
	echo -n "Testing ${tool}..."
	echo "Regression test ${tool}" >> "${logfile}"
	echo "=======================" >> "${logfile}"

	cd ${bd}
	test_result=0
        # Important note. Must use --target_board=${test_board}, *not*
        # --target_board ${test_board} or GNU will think this is not
        # parallelizable (horrible kludgy test in the makefile).
	make ${PARALLEL} "check-${tool}" \
	    RUNTESTFLAGS="--target_board=${test_board}" \
	    >> "${logfile}" 2>&1 || test_result=1
	echo
	cd - > /dev/null 2>&1
    fi

    # Save the results
    resbase=`basename $resfile`

    if [ \( -r ${bd}/${resfile}.log \) -a \( -r ${bd}/${resfile}.sum \) ]
    then
        # Generated files have Windows line endings. dos2unix tool cannot be
        # used because sometimes it recognizes input files as binary and
        # refuses to work. Specifying option "-f" could solve this problem,
        # but RedHats dos2unix is too old to understand this option. "tr -d
        # '\015\" seems to be more universal solution.
	tr -d '\015' < ${bd}/${resfile}.log > ${resdir}/${resbase}.log \
	    2>> ${logfile}
	chmod ugo-wx ${resdir}/${resbase}.log >> ${logfile} 2>&1
	tr -d '\015' < ${bd}/${resfile}.sum > ${resdir}/${resbase}.sum \
	    2>> ${logfile}
	chmod ugo-wx ${resdir}/${resbase}.sum >>${logfile} 2>&1

        # Report the summary to the user
	echo
	sed -n -e '/Summary/,$p' < ${resdir}/${resbase}.sum | grep '^#' || true
	echo
    fi
}
    
# ------------------------------------------------------------------------------
# Set default values for some options
# Set defaults for some options
rootdir=`(cd .. && pwd)`

# Create a common log directory for all logs in this and sub-scripts
logdir=${rootdir}/logs-mainline
mkdir -p ${logdir}

# Create a common results directory in which sub-directories will be created
# for each set of tests.
resdir=${rootdir}/results-mainline
mkdir -p ${resdir}

test_board=avr-sim
multilib_options=""
make_load="`(echo processor; cat /proc/cpuinfo 2>/dev/null echo processor) \
           | grep -c processor`"
jobs=${make_load}
load=${make_load}
do_binutils="yes"
do_gas="yes"
do_ld="yes"
do_c="yes"
do_c++="no"
do_libgcc="no"
do_libstdcpp="no"
do_gdb="yes"

# Parse options
until
opt=$1
case ${opt} in

    --target-board)
	shift
	test_board=$1
	;;

    --multilib-options)
        shift
        multilib_options="$1"
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

    --binutils)
	do_binutils="yes"
	;;

    --no-binutils)
	do_binutils="no"
	;;

    --gas)
	do_gas="yes"
	;;

    --no-gas)
	do_gas="no"
	;;

    --ld)
	do_ld="yes"
	;;

    --no-ld)
	do_ld="no"
	;;

    --c)
	do_c="yes"
	;;

    --no-c)
	do_c="no"
	;;

    --c++)
	do_c++="yes"
	;;

    --no-c++)
	do_c++="no"
	;;

    --libgcc)
	do_libgcc="yes"
	;;

    --no-libgcc)
	do_libgcc="no"
	;;

    --libstdc++)
	do_libstdcpp="yes"
	;;

    --no-libstdc++)
	do_libstdcpp="no"
	;;

    --gdb)
	do_gdb="yes"
	;;

    --no-gdb)
	do_gdb="no"
	;;

    ?*)
	echo "Usage: ./run-tests.sh [--target-board <board>]"
        echo "                      [--multilib-options <options>]"
        echo "                      [--jobs <count>] [--load <load>]"
        echo "                      [--single-thread]"
        echo "                      [--binutils | --no-binutils]"
        echo "                      [--gas | --no-gas]"
        echo "                      [--ld | --no-ld]"
        echo "                      [--c | --no-c]"
        echo "                      [--c++ | --no-c++]"
        echo "                      [--libgcc | --no-libgcc]"
        echo "                      [--libgloss | --no-libgloss]"
        echo "                      [--newlib | --no-newlibe]"
        echo "                      [--libstdc++ | --no-libstdc++]"
        echo "                      [--sim | --no-sim]"
        echo "                      [--gdb | --no-gdb]"

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

# Run regression and gather results. Gathering results is a separate function
# because of the variation in the location and number of results files for
# each tool.
export DEJAGNU=${rootdir}/toolchain/site.exp
echo DEJAGNU=$DEJAGNU
echo "Running AVR tests"

# We need avr-gcc on the command line to proceed.
if ! which avr-gcc >> /dev/null 2>&1
then
    echo "ERROR: avr-gcc must be available on search PATH to build avrtest"
    exit 1
fi

# Create the log file and results directory
logfile="${logdir}/check-$(date -u +%F-%H%M).log"
rm -f "${logfile}"
resdir="${resdir}/results-$(date -u +%F-%H%M)"
mkdir ${resdir}
readme=${resdir}/README

bd=${rootdir}/bd-mainline

# First build the AVR test tool
echo "Building AVR Test Tool" >> "${logfile}"
echo "======================" >> "${logfile}"

echo "Building AVR Test Tool..."

cd ${rootdir}/winavr/avrtest
if make all-xmega >> logfile 2>&1
then
    echo "  finished building AVR Test Tool"
else
    echo "ERROR: AVR Test Tool build failed"
    echo "- see ${logfile}"
    exit 1
fi

# Export avrtest for the board description files and put it on our path.
export AVRTEST_HOME=${rootdir}/winavr/avrtest
export PATH=${AVRTEST_HOME}:${PATH}

# Create a README with info about the test
echo "Test of AVR tool chain" > ${readme}
echo "======================" >> ${readme}
echo "" >> ${readme}
echo "Start time:         $(date -u +%d\ %b\ %Y\ at\ %H:%M)" >> ${readme}
echo "Tool chain release: mainline"                          >> ${readme}
echo "Test board:         ${test_board}"                     >> ${readme}
echo "Multilib options:   ${multilib_options}"               >> ${readme}

# Run the tests

# binutils
if [ "x${do_binutils}" = "xyes" ]
then
    run_check binutils binutils/binutils
fi
# gas
if [ "x${do_gas}" = "xyes" ]
then
    run_check gas gas/testsuite/gas
fi
# ld
if [ "x${do_ld}" = "xyes" ]
then
    run_check ld ld/ld
fi
# gcc
if [ "x${do_c}" = "xyes" ]
then
    run_check c gcc/testsuite/gcc/gcc
fi
# gcc and g++
if [ "x${do_c++}" = "xyes" ]
then
    run_check c++ gcc/testsuite/g++/g++
fi
# libgcc
if [ "x${do_libgcc}" = "xyes" ]
then
    run_check target-libgcc avr/libgcc/testsuite/libgcc
fi
# libstdc++
if [ "x${do_libstdcpp}" = "xyes" ]
then
    run_check target-libstdc++-v3 avr/libstdc++-v3/testsuite/libstdc++
fi
# gdb
if [ "x${do_gdb}" = "xyes" ]
then
    run_check gdb gdb/testsuite/gdb
fi

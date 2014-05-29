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

# Invocation Syntax:

#     run-tests.sh [--target-board <board>]
#                  [--runtestflags <flags>]
#                  [--multilib-options <options>]
#                  [--jobs <count>] [--load <load>] [--single-thread]
#                  [--start-server]
#                  [--gdbserver <server>]
#                  [--model-lib <lib>]
#                  [--model <model>]
#                  [--mcu <mcu>]
#                  [--cflags-extra <flags>]
#                  [--heap-end <val>]
#                  [--ldflags-extra <flags>]
#                  [--ldscript <scriptfile>]
#                  [--netport <port>]
#                  [--stack-size <val>]
#                  [--text-size <val>]
#                  [--binutils | --no-binutils]
#                  [--gas | --no-gas]
#                  [--ld | --no-ld]
#                  [--c | --no-c]
#                  [--c++ | --no-c++]
#                  [--libgcc | --no-libgcc]
#                  [--libstdc++ | --no-libstdc++]
#                  [--gdb | --no-gdb]
#                  [--comment <text>]
#                  [-h | --help]

# Parameters controlling the DejaGnu test environment:

# --target-board <board>

#     The board description for the AVR target. This should either be a
#     standard DejaGnu board, or a board in the dejagnu/baseboards directory
#     of the toolchain repository. Default value avr-sim

# --runtestflags <flags>

#     Add <flags> to the end of the RUNTESTFLAGS environment variable. This
#     can be used to control other test parameters, or to restrict the set of
#     tests to be run (which usually only makes sense if there is only one
#     tool specified to test).

# --multilib-options <options>

#     Additional options for compiling to allow multilib variants to be
#     tested.

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

#     Specify which tests are to be run. By default all are enabled except
#     libgcc, for which no tests currently exist, c++, which has too many
#     failures (due to the lack of libstdc++) and libstdc++, which is not
#     currently supported for AVR.

# Parameters controlling the server for the target:

# --start-server

#     Start up sufficient GDB servers for the number of threads (default don't
#     do this).

# --gdbserver <server>

#     Name of the command to start a GDB server. It will be passed a library
#     name, a model and a port to use. Default avr-gdbserver. Note that any
#     PATH and LD_LIBRARY_PATH will need to be set.

# --model-lib <lib>

#     Name of the model library to use with the GDB server. Default
#     libATmega128.so.

# --model <model>

#     Name of the model to use. Default ATmega128

# Parameters describing the MCU being tested:

# --mcu <mcu>
# --cflags-extra <flags>
# --heap-end <val>
# --ldflags-extra <flags>
# --ldscript <scriptfile>
# --netport <port>
# --stack-size <val>
# --text-size <val>

#     Specify the various parameters which control the board description for
#     the test. Look at the board description (in dejagnu/baseboards) for
#     details.

#     Where multiple GDBservers are being started, they will use ports
#     successively from netport.

# Parameters describing which tool components to test:

# --binutils | --no-binutils
# --gas | --no-gas
# --ld | --no-ld
# --c | --no-c
# --c++ | --no-c++
# --libgcc | --no-libgcc
# --libstdc++ | --no-libstdc++
# --gdb | --no-gdb

#     By default all except c++ and libstdc++ are tested.

# General parameters:

# --comment <text>

#     Arbitrary line of text to include in the README in the results directory.

# --help
# -h

#     Print a message about usage and exit.

# This script exits with zero if every test requested has been run.

#------------------------------------------------------------------------------
#
#			       Shell functions
#
#------------------------------------------------------------------------------

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
        # Important note. Must use --target_board=${target_board}, *not*
        # --target_board ${target_board} or GNU will think this is not
        # parallelizable (horrible kludgy test in the makefile).
	make ${PARALLEL} "check-${tool}" \
	    RUNTESTFLAGS="--target_board=${target_board} ${runtestflags}" \
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


# Print a header to the log file and console

# @param[in] String to use for header
header () {
    str=$1
    len=`expr length "${str}"`

    # Log file header
    echo ${str} >> ${logfile} 2>&1
    for i in $(seq ${len})
    do
	echo -n "=" >> ${logfile} 2>&1
    done
    echo "" >> ${logfile} 2>&1

    # Console output
    echo "${str} ..."
}


# Print a comment to the log file and console

# @param[in] String to use for header
logit () {
    str=$1
    echo "${str}" >> ${logfile} 2>&1
    echo "${str}"
}


# Put a value into an associative array

# The associative array is represented as a variable with the string value of
# the form "key=value key=value ...".  There can be no space in values, so
# they are substituted with the arbitrary string :SP:

# Based on Irfan Zulfiqar's script on stackoverflow.

# @param[in] 1  The name of the array
# @param[in] 2  The key
# @param[in] 3  The value to associate with the key
map_put () {
    if [ "$#" != 3 ]
    then
	exit 1
    fi

    mapname=$1
    key=$2
    value=`echo $3 | sed -e "s/ /:SP:/g"`

    eval map="\"\$$mapname\""
    map="`echo "${map}" | sed -e "s/--${key}=[^ ]*//g"` --${key}=${value}"
    eval ${mapname}="\"${map}\""
}


# Get a value from an associative array

# Based on Irfan Zulfiqar's script on stackoverflow.  The result will be in
# the global variable "value".

# @param[in] 1  The name of the array
# @param[in] 2  The key
map_get () {
    mapname=$1
    key=$2

    eval map="\"\$$mapname\""
    value=`echo ${map} | sed -e "s/.*--${key}=\([^ ]*\).*/\1/"`
    value="`echo ${value} | sed -e 's/:SP:/ /g'`"
}


#------------------------------------------------------------------------------
#
#		     Argument handling and initialization
#
#------------------------------------------------------------------------------

# Set the top level directory.
d=`dirname "$0"`
topdir=`(cd "$d/.." && pwd)`

# Generic release set up. This defines (and exports RELEASE, LOGDIR and
# RESDIR, creating directories named $LOGDIR and $RESDIR if they don't exist.
. "${topdir}"/toolchain/define-release.sh

# Set defaults for options
target_board=atmel-studio
runtestflags=""
multilib_options=""
make_load="`(echo processor; cat /proc/cpuinfo 2>/dev/null echo processor) \
           | grep -c processor`"
jobs=${make_load}
load=${make_load}
# GDB server parameters
start_server="no"
gdbserver="avr-gdbserver"
model_lib=libATmega128.so
model=ATmega128
# Parameters for testing. Defaults are for a plain atmega128
AVR_MCU="atmega128"
AVR_CFLAGS_EXTRA=""
AVR_HEAP_END="0x800fff"
AVR_LDFLAGS_EXTRA=""
AVR_LDSCRIPT=""
AVR_NETPORT="51000"
AVR_STACK_SIZE="2048"
AVR_TEXT_SIZE="131072"
AVR_PORT_FILE=${topdir}/toolchain/portfile$$.txt
# Which tools to test
do_binutils="yes"
do_gas="yes"
do_ld="yes"
do_c="yes"
do_cpp="no"
do_libgcc="no"
do_libstdcpp="no"
do_gdb="yes"
# General parameters
comment=""


# Parse options
getopt_string=`getopt -n run-tests -o h            \
                      -l target-board:             \
                      -l runtestflags:             \
                      -l multilib-options:         \
                      -l jobs:,load:,single-thread \
                      -l start-server              \
                      -l gdbserver:                \
                      -l modellib:                 \
                      -l model:                    \
                      -l mcu:                      \
                      -l cflags-extra:             \
                      -l heap-end:                 \
                      -l ldflags-extra:            \
                      -l ldscript:                 \
                      -l netport:                  \
                      -l stack-size:               \
                      -l text-size:                \
                      -l binutils,no-binutils      \
                      -l gas,no-gas                \
                      -l ld,no-ld                  \
                      -l c,no-c                    \
                      -l c++,no-c++                \
                      -l libgcc,no-libgcc          \
                      -l libstdc++,no-libstdc++    \
                      -l gdb,no-gdb                \
                      -l comment:                  \
                      -l help                      \
                      -s sh -- "$@"`
eval set -- "$getopt_string"

while true
do
    case $1 in

	--target-board)
	    shift
	    target_board=$1
	    ;;

	--runtestflags)
	    shift
	    runtestflags=$1
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

	--start-server)
	    start_server="yes"
	    ;;

	--gdbserver)
	    shift
	    gdbserver=$1
	    ;;

	--model-lib)
	    shift
	    model_lib=$1
	    ;;

	--model)
	    shift
	    model=$1
	    ;;

	--mcu)
	    shift
	    AVR_MCU="$1"
	    ;;

	--cflags-extra)
	    shift
	    AVR_CFLAGS_EXTRA="$1"
	    ;;

	--heap-end)
	    shift
	    AVR_HEAP_END="$1"
	    ;;

	--ldflags-extra)
	    shift
	    AVR_LDFLAGS_EXTRA="$1"
	    ;;

	--ldscript)
	    shift
	    AVR_LDSCRIPT="$1"
	    ;;

	--netport)
	    shift
	    AVR_NETPORT="$1"
	    ;;

	--stack-size)
	    shift
	    AVR_STACK_SIZE="$1"
	    ;;

	--text-size)
	    shift
	    AVR_TEXT_SIZE="$1"
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
	    do_cpp="yes"
	    ;;

	--no-c++)
	    do_cpp="no"
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

	--comment)
	    shift
	    comment="$1"
	    ;;

	-h|--help)
	    echo "Usage: ./run-tests.sh [--target-board <board>]"
	    echo "                      [--runtestflags <flags>]"
	    echo "                      [--multilib-options <options>]"
	    echo "                      [--jobs <count>] [--load <load>]"
	    echo "                      [--single-thread]"
	    echo "                      [--start-server]"
	    echo "                      [--gdbserver <server>]"
	    echo "                      [--model-lib <lib>]"
	    echo "                      [--model <model>]"
	    echo "                      [--mcu <mcu>]"
	    echo "                      [--cflags-extra <flags>]"
	    echo "                      [--heap-end <val>]"
	    echo "                      [--ldflags-extra <flags>]"
	    echo "                      [--ldscript <scriptfile>]"
	    echo "                      [--netport <port>]"
	    echo "                      [--stack-size <val>]"
	    echo "                      [--text-size <val>]"
	    echo "                      [--binutils | --no-binutils]"
	    echo "                      [--gas | --no-gas]"
	    echo "                      [--ld | --no-ld]"
	    echo "                      [--c | --no-c]"
	    echo "                      [--c++ | --no-c++]"
	    echo "                      [--libgcc | --no-libgcc]"
	    echo "                      [--libstdc++ | --no-libstdc++]"
	    echo "                      [--gdb | --no-gdb]"
	    echo "                      [--comment <text>]"
	    echo "                      [-h | --help]"

	    exit 0
	    ;;

	--)
	    shift
	    break
	    ;;

	*)
	    echo "Internal error!"
	    echo $1
	    exit 1
	    ;;
    esac
    shift
done

# Sanity checks
if ! which avr-gcc >> /dev/null 2>&1
then
    echo "ERROR: avr-gcc must be available on search PATH."
    exit 1
fi

if ! which ${gdbserver} >> /dev/null 2>&1
then
    echo "ERROR: ${gdbserver} must be available on search PATH."
    exit 1
fi

# Parallelism
PARALLEL="-j ${jobs} -l ${load}"

# Export the board parameters
export AVR_MCU
export AVR_CFLAGS_EXTRA
export AVR_HEAP_END
export AVR_LDFLAGS_EXTRA
export AVR_LDSCRIPT
export AVR_NETPORT
export AVR_STACK_SIZE
export AVR_TEXT_SIZE
export AVR_PORT_FILE

# Create the log file and results directory
logfile="${LOGDIR}/check-$(date -u +%F-%H%M).log"
rm -f "${logfile}"
resdir="${RESDIR}/results-$(date -u +%F-%H%M)"
mkdir ${resdir}
readme=${resdir}/README

DEJAGNU=${topdir}/toolchain/site.exp
export DEJAGNU
echo DEJAGNU=$DEJAGNU
header "Running AVR tests"

bd=${topdir}/bd-${RELEASE}

# First build the AVR test tool
header "Building the AVR Test Tool"

cd ${topdir}/winavr/avrtest
if make all-xmega >> logfile 2>&1
then
    echo "  finished building AVR Test Tool"
else
    echo "  ERROR: AVR Test Tool build failed"
    echo "  - see ${logfile}"
    exit 1
fi

# Export avrtest for the board description files and put it on our path.
AVRTEST_HOME=${topdir}/winavr/avrtest
export AVRTEST_HOME
PATH=${AVRTEST_HOME}:${PATH}
export PATH


#------------------------------------------------------------------------------
#
#			   Set up parallel targets
#
#------------------------------------------------------------------------------

if [ "$start_server" = "yes" ]
then
    header "Setting up targets"

    # Save ports in a file, which we first clear.
    rm -f ${AVR_PORT_FILE}

    # Set up the parallism lists and maps. We don't generally log output from
    # these.
    for i in `seq ${jobs}`
    do
	port=`expr ${AVR_NETPORT} + ${i}`
	echo ${port} >> ${AVR_PORT_FILE}
	${gdbserver} ${model_lib} ${model} ${port} > /dev/null 2>&1 & pid=$!
	map_put port2pid $port $pid
	logit "  GDB server on port ${port} (process ${pid})"
    done
fi

#------------------------------------------------------------------------------
#
#				Run the tests
#
#------------------------------------------------------------------------------

# Create a README with info about the test
echo "Test of AVR tool chain" > ${readme}
echo "======================" >> ${readme}
echo "" >> ${readme}
echo "Start time:         $(date -u +%d\ %b\ %Y\ at\ %H:%M)" >> ${readme}
echo "Tool chain release: ${RELEASE}"                        >> ${readme}
echo "Test board:         ${target_board}"                   >> ${readme}
echo "  processor:        ${AVR_MCU}"                        >> ${readme}
echo "  heap end:         ${AVR_HEAP_END}"                   >> ${readme}
echo "  max stack size:   ${AVR_STACK_SIZE}"                 >> ${readme}
echo "  max text size:    ${AVR_TEXT_SIZE}"                  >> ${readme}
echo "  ld script:        ${AVR_LDSCRIPT}"                   >> ${readme}
echo "  extra CFLAGS:     ${AVR_CFLAGS_EXTRA}"               >> ${readme}
echo "  extra LDFLAGS:    ${AVR_LDFLAGS_EXTRA}"              >> ${readme}
echo "Multilib options:   ${multilib_options}"               >> ${readme}
echo "${comment}"                                            >> ${readme}

# Run regression and gather results. Gathering results is a separate function
# because of the variation in the location and number of results files for
# each tool.

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
if [ "x${do_cpp}" = "xyes" ]
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

#------------------------------------------------------------------------------
#
#			  Close the parallel targets
#
#------------------------------------------------------------------------------

header "Closing down targets"

for port in ${server_ports}
do
    # Process ID running this port
    map_get port2pid ${port}
    pid=$value

    # "Nice" close down
    if avr-gdb -ex "target remote :${port}" -ex "monitor exit" -ex "quit" \
	>> ${logfile} 2>&1
    then
	logit "  closed GDB server on port ${port}"
    fi

    # Forced close down (do this even if nice close down apparently worked).
    if ps ${pid} > /dev/null 2>&1
    then
	kill -KILL ${pid} > /dev/null 2>&1
	logit "  forced close of GDB server with process ID ${pid}"
    fi
done

rm -f ${AVR_PORT_FILE}

# Result is always success here.
exit 0

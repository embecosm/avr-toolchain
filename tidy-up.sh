#!/bin/sh

# Copyright (C) 2014 Embecosm Limited

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

#		      SCRIPT TO TIDY UP LOGS AND RESULTS
#		      ==================================
#
# Throw away logs more than one day old and compress results more than one day
# old.

VERSION=mainline
rootdir=`(cd .. && pwd)`
logdir="${rootdir}/logs-${VERSION}"
resdir="${rootdir}/results-${VERSION}"

# Sort out old logs
echo -n "Removing logs..."
cd ${logdir}
find . -maxdepth 1 -mtime +0 -exec rm {} \;
echo

# Sort out old results
echo "Compressing results..."
cd ${resdir}
dirs=`find . -maxdepth 1 -type d -mtime +0 -print`

for d in ${dirs}
do
    if [ -d ${d} ]
    then
	# If the tar file already exists blow it away
	rm -f ${d}.tar.bz2
	# tar up the results
	echo -n "  $d..."
	if tar jcf ${d}.tar.bz2 ${d}
	then
	    echo
	    rm -rf ${d}
	fi
    fi
done

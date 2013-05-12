AVR GNU Tool Chain
==================

This is the main git repository for the Atmel AVR GNU tool chain. It contains
just the scripts required to build the entire tool chain.

There are various branches of this repository which will automatically build
complete tool chains for various releases. This is the version for the
mainline tool chain development branches.

When run, the build script will check out the mainline branches for each of
the relevant tool chain component repositories.

Prequisites
-----------

You will need a Linux like environment (Cygwin and MinGW environments under
Windows should work as well).

You will need the standard GNU tool chain pre-requisites as documented in
[GCC website](http://gcc.gnu.org/install/prerequisites.html)

Finally you will need to check out the repositories for each of the tool chain
components (its not all one big repository). These should be peers of this
toolchain directory. If you have yet to check any repository out, then the
following should be appropriate for creating a new directory, `avr` with all
the components.

    mkdir avr
    cd avr
    git clone git://sourceware.org/git/binutils.git
    git clone git@github.com:embecosm/avr-gcc.git gcc
    git clone git@github.com:vancegroup-mirrors/avr-libc.git
    git clone git://sourceware.org/git/gdb.git
    git clone git@github.com:embecosm/avr-toolchain.git toolchain
    git clone git@github.com:embecosm/winavr.git
    cd toolchain

For convenience, the script
[avr-clone-all.sh](https://github.com/embecosm/avr-toolchain/blob/avr-toolchain-mainline/avr-clone-all.sh)
in this directory will do the cloning for you.

Building the tool chain
-----------------------

The script `build-all.sh` will build and install AVR tool chains and AVR LibC. Use

    ./build-all.sh --help

to see the toptions available.

The script `avr-versions.sh` specifies the branches to use in each component
git repository. It should be edited to change the default branches if
required.

Having checked out the correct branches and built a unified source directory,
`build-all.sh` first builds and installs the tool chain, then builds and
installs the AVR LibC library.

LuaJIT and ljsyscall build for Xen
==================================

This is a modified build of the repo it is forked form to add a build of
LuaJIT and ljsyscall that runs natively under Xen. By default it just runs
the ljsyscall test suite.

This is just a proof of concept. The build system needs cleaning up with
a gcc spec file and wrapper and so on to make the build simpler.

You need Xen headers installed in /usr/include/xen.

Currently only 32 bit builds will work. Adding support for 64 bit builds
requires adding allocation hint support to the mmap implementation.

To build, check the location of your libgcc files and adjust Makefile
(sorry, this needs automating!) then run `./buildxen.sh`. Then run
`xl create -c domain_config`. To run on Amazon you will need to build a
stub as you cannot directly create a AKI image you have to run pvgrub - 
not tested yet will add a script.

LuaJIT is a high performance implementation of Lua see http://luajit.org/

ljsyscall is a system programming interface for LuaJIT see https://github.com/justincormack/ljsyscall

Rump kernel hypercalls for the Xen hypervisor [![Build Status](https://travis-ci.org/justincormack/rumpuser-xen.png?branch=master)](https://travis-ci.org/justincormack/rumpuser-xen)
=============================================

This repository contains code that implements the rump kernel hypercall
interfaces for the Xen hypervisor platform.  It enables running rump
kernels and application code as a single-image guest on top of Xen
without having to boot an entire OS.  The advantage of using rump
kernels is being able use unmodified kernel-quality drivers as part of
a single-image application, with the memory footprint being a fraction
of that of a full OS, yet still achieving the isolation provided by Xen.

For applications a POSIX-y interface is provided.  Some applications,
such as those using file systems or sockets interfaces, will more or
less work out-of-the-box.  Limitations include applications which do
not fit into a single-process no-VM model, such as applications using
`fork()` or `execve()`.  These limitations may sometimes be overcome by
various forms of emulation.

See http://www.NetBSD.org/docs/rump/ for more information on rump kernels.


Using / Testing
---------------

To build, clone this repository and run the following command.  You
need Xen headers for a successful build (e.g. on Ubuntu they're in
the `libxen-dev` package).

	./buildxen.sh

To run, use the standard Xen tools:

	xl create -c domain_config

Check out `domain_config` to change which tests/demos are run.
By default, a httpd will be run.  You will need a Xen network
setup for it to work.


Implementation
--------------

The implementation runs on top of a heavily modified Xen Mini-OS --
Mini-OS provided most of the functionality outside the scope of rump
kernels, such as bootstrapping, cooperative scheduling, etc.  See the
`rumphyper*` files to see the hypercall implementations relevant for
running rump kernels.


File System Images
------------------

Though a rump kernel does not require a root file system image, some
applications and library routines expect to be able to access files.
For example, the `getservent()` call searches `/etc/services`, and
a web server serving static content typically serves it from a file
system hierarchy.  To satisfy these demands, we mount file systems in
the rump kernel file system namespace.  Any file system type, e.g. NFS,
would do, but it's usually simplest mount a prepopulated image.

We supply these prepopulated images in the `img` subdirectory
of this repository.  If your host does not support FFS, you
can still examine and modify the images using the portable
[fs-utils](https://github.com/stacktic/fs-utils) tool suite.

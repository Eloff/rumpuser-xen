#!/bin/sh

# Just a script to run the handful of commands required for a
# bootable domU image.  This is mostly to document the commands
# required, and is not pretending to be fancy.

STDJ='-j4'

# the buildxen.sh is not as forgiving as I am
set -e

if [ "$1" = 'checkout' -o ! -f .buildxen-checkoutdone ]; then
	docheckout=true
fi
if ${docheckout:-false} ; then
	git submodule update --init --recursive
	./buildrump.sh/buildrump.sh -s rumpsrc checkout
	( cd nblibs ; ln -sf ../rumpsrc/common . )

	touch .buildxen-checkoutdone
fi

# build tools.  XXX: build them only if they don't exist already.  If
# we try to build them after installing the extra headers, the tool
# compat code gets really confused  FIXME
if [ ! -f rumptools/rumpmake ]; then
	./buildrump.sh/buildrump.sh -${BUILDXEN_QUIET:-q} ${STDJ} -k \
	    -s rumpsrc -T rumptools -o rumpobj -V RUMP_KERNEL_IS_LIBC=1 tools

	# FIXME to be able to specify this as part of previous cmdline
	echo 'CPPFLAGS+=-DMAXPHYS=32768' >> rumptools/mk.conf
fi

RMAKE=`pwd`/rumptools/rumpmake

# build rump kernel
./buildrump.sh/buildrump.sh -k -s rumpsrc -T rumptools -o rumpobj build install

#
# install full set of headers.
#
# first, "mtree" (TODO: fetch/use nbmtree)
INCSDIRS='adosfs altq arpa crypto dev filecorefs fs i386 isofs miscfs
	msdosfs net net80211 netatalk netbt netinet netinet6 netipsec
	netisdn netkey netmpls netnatm netsmb nfs ntfs ppath prop
	protocols rpc rpcsvc ssp sys ufs uvm x86'
for dir in ${INCSDIRS}; do
	mkdir -p rump/include/$dir
done

# then, install
echo '>> Installing headers.  please wait (may take a while) ...'
(
  # sys/ produces a lot of errors due to missing tools/sources
  # "protect" the user from that spew
  cd rumpsrc/sys
  ${RMAKE} -k includes >/dev/null 2>&1
)

# rpcgen lossage
( cd rumpsrc/include && ${RMAKE} -k includes > /dev/null 2>&1)

# other lossage
( cd nblibs/lib/libc && ${RMAKE} includes >/dev/null 2>&1)
( cd nblibs/lib/libpthread && ${RMAKE} includes >/dev/null 2>&1)

echo '>> done with headers'


# build networking driver
(
  OBJS=`pwd`/rumpobj/rumpxenif
  cd rumpxenif
  ${RMAKE} MAKEOBJDIR=${OBJS} obj
  ${RMAKE} MAKEOBJDIR=${OBJS} MKPIC=no dependall
  ${RMAKE} MAKEOBJDIR=${OBJS} MKPIC=no install
)

makeuserlib ()
{
	lib=$1

	OBJS=`pwd`/rumpobj/lib/$1
	( cd nblibs/lib/$1
		${RMAKE} MAKEOBJDIR=${OBJS} obj
		${RMAKE} MKMAN=no MKLINT=no MKPIC=no MKPROFILE=no MKYP=no \
		    NOGCCERROR=1 MAKEOBJDIR=${OBJS} ${STDJ} dependall
		${RMAKE} MKMAN=no MKLINT=no MKPIC=no MKPROFILE=no MKYP=no \
		    MAKEOBJDIR=${OBJS} install
	)
}

makeuserlib libc
makeuserlib libm

[ ! -f img/test.ffs ] && cp img/test_clean.ffs img/test.ffs

# build LuaJIT
(
  cd luajit-2.0/src
  make  HOST_CC=gcc  TARGET_CFLAGS='-DMAP_32BIT=0 -U__linux__ -D__NetBSD__ -nostdinc -I../../rump/include' TARGET_LDFLAGS='-D__NetBSD__ -nostdinc -I../../rump/include' TARGET_SYS=BSD libluajit.a
)

# build ljsyscall
(
  cd ljsyscall
  ./examples/cbuild.sh
)

# we need dl.c from ljsyscall examples, its probably in wrong repo
cp ljsyscall/examples/dl.c .

# build the domU image
make

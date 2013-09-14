# Common Makefile for mini-os.
#
# Every architecture directory below mini-os/arch has to have a
# Makefile and a arch.mk.
#

MINI-OS_ROOT=$(CURDIR)
export MINI-OS_ROOT

ifeq ($(MINIOS_CONFIG),)
include Config.mk
else
EXTRA_DEPS += $(MINIOS_CONFIG)
include $(MINIOS_CONFIG)
endif

# Configuration defaults
CONFIG_XENBUS ?= y

CONFIG_PCIFRONT ?= n

# Export config items as compiler directives
flags-$(CONFIG_PCIFRONT) += -DCONFIG_PCIFRONT
flags-$(CONFIG_XENBUS) += -DCONFIG_XENBUS

DEF_CFLAGS += $(flags-y)

OBJCOPY=objcopy

# Include common mini-os makerules.
include minios.mk

CFLAGS += -Irump/include -nostdinc
CFLAGS += -Iluajit-2.0/src
CFLAGS += -DVIRTIF_BASE=xenif -I$(MINI-OS_ROOT)

LIBS_FS = -lrumpfs_ffs -lrumpdev_disk -lrumpdev -lrumpvfs
LIBS_FS+= -lrumpkern_tty -lrumpfs_tmpfs -lrumpfs_kernfs -lrumpfs_ptyfs
LIBS_NET = -lrumpnet_config -lrumpdev_bpf -lrumpnet_xenif -lrumpnet_netinet
LIBS_NET+= -lrumpnet_local 
LIBS_NET+= -lrumpnet_net -lrumpnet

# Define some default flags for linking.
LDLIBS_FS = --whole-archive ${LIBS_FS} ${LIBS_NET} -lrump --no-whole-archive
LDLIBS = -Lrump/lib ${LDLIBS_FS} -lc
LDLIBS += ljsyscall/obj/libtest.a -Lluajit-2.0/src -lluajit -L/usr/lib/gcc/i686-redhat-linux/4.4.7 -l gcc_eh -lm -lc

APP_LDLIBS := 
LDARCHLIB := -L$(OBJ_DIR)/xen/$(TARGET_ARCH_DIR) -l$(ARCH_LIB_NAME)
LDFLAGS_FINAL := -T xen/$(TARGET_ARCH_DIR)/minios-$(XEN_TARGET_ARCH).lds

# Prefix for global API names. All other symbols are localised before
# linking with EXTRA_OBJS.
GLOBAL_PREFIX := xenos_
EXTRA_OBJS =

TARGET := rump-kernel

# Subdirectories common to mini-os
SUBDIRS := lib xen xen/console xen/xenbus

src-y += xen/blkfront.c
src-y += xen/events.c
src-y += xen/gntmap.c
src-y += xen/gnttab.c
src-y += xen/hypervisor.c
src-y += xen/kernel.c
src-y += xen/mm.c
src-y += xen/netfront.c
src-$(CONFIG_PCIFRONT) += xen/pcifront.c
src-y += xen/sched.c

src-y += lib/__errno.c
src-y += lib/emul.c
src-y += lib/libc_stubs.c
src-y += lib/memalloc.c

src-y += rumphyper_base.c
src-y += rumphyper_net.c
src-y += rumphyper_synch.c
src-y += rumphyper_stubs.c

#src-y += rumpkern_demo.c
src-y += lua.c ljsyscall/examples/dl.c

src-$(CONFIG_XENBUS) += xen/xenbus/xenbus.c

src-y += xen/console/console.c
src-y += xen/console/xencons_ring.c
src-y += xen/console/xenbus.c

# The common mini-os objects to build.
APP_OBJS :=
OBJS := $(patsubst %.c,$(OBJ_DIR)/%.o,$(src-y))
#OBJS+= httpd/bozohttpd.o httpd/main.o httpd/ssl-bozo.o httpd/content-bozo.o
#OBJS+= httpd/dir-index-bozo.o

.PHONY: default
default: objs $(TARGET)

objs:
	mkdir -p $(OBJ_DIR)/lib $(OBJ_DIR)/xen/$(TARGET_ARCH_DIR)
	mkdir -p $(OBJ_DIR)/xen/console $(OBJ_DIR)/xen/xenbus

# Create special architecture specific links. The function arch_links
# has to be defined in arch.mk (see include above).
ifneq ($(ARCH_LINKS),)
$(ARCH_LINKS):
	$(arch_links)
endif

.PHONY: links
links: $(ARCH_LINKS)
	[ -e include/xen ] || ln -sf $(XEN_HEADERS) include/xen
	[ -e include/mini-os/machine ] || ln -sf $(TARGET_ARCH_FAM) include/mini-os/machine

.PHONY: arch_lib
arch_lib:
	$(MAKE) --directory=xen/$(TARGET_ARCH_DIR) OBJ_DIR=$(OBJ_DIR)/xen/$(TARGET_ARCH_DIR) || exit 1;

$(OBJ_DIR)/$(TARGET)_app.o: $(APP_OBJS) app.lds
	$(LD) -r -d $(LDFLAGS) -\( $^ -\) $(APP_LDLIBS) --undefined main -o $@

ifneq ($(APP_OBJS),)
APP_O=$(OBJ_DIR)/$(TARGET)_app.o 
endif

$(TARGET): links $(OBJS) $(APP_O) arch_lib
	$(LD) -r $(LDFLAGS) $(HEAD_OBJ) $(APP_O) $(OBJS) $(LDARCHLIB) $(LDLIBS) -o $@.o
	$(OBJCOPY) -w -G $(GLOBAL_PREFIX)* -G _start $@.o $@.o
	$(LD) $(LDFLAGS) $(LDFLAGS_FINAL) $@.o $(EXTRA_OBJS) -o $@
	#gzip -f -9 -c $@ >$@.gz

.PHONY: clean arch_clean

arch_clean:
	$(MAKE) --directory=xen/$(TARGET_ARCH_DIR) OBJ_DIR=$(OBJ_DIR)/xen/$(TARGET_ARCH_DIR) clean || exit 1;

clean:	arch_clean
	for dir in $(addprefix $(OBJ_DIR)/,$(SUBDIRS)); do \
		rm -f $$dir/*.o; \
	done
	rm -f $(OBJ_DIR)/*.o *~ $(OBJ_DIR)/core $(OBJ_DIR)/$(TARGET).elf $(OBJ_DIR)/$(TARGET).raw $(TARGET) $(TARGET).o
	rm -f $(OBJ_DIR)/include/xen $(OBJ_DIR)/include/mini-os/machine
	rm -f tags TAGS


define all_sources
     ( find . -follow -name SCCS -prune -o -name '*.[chS]' -print )
endef

.PHONY: cscope
cscope:
	$(all_sources) > cscope.files
	cscope -k -b -q
    
.PHONY: tags
tags:
	$(all_sources) | xargs ctags

.PHONY: TAGS
TAGS:
	$(all_sources) | xargs etags


# Copyright (C) 2022 Intel Corporation
# SPDX-License-Identifier: MIT

#include ../../common/sw/common_include.mk

# Primary test name
TEST = pcie_dm_req_splitter

# Build directory
OBJDIR = obj
CFLAGS += -g -O0 -I./$(OBJDIR)
CPPFLAGS += -I./$(OBJDIR)

LDFLAGS +=-z noexecstack
LDFLAGS +=-z relro -z now

# Files and folders
SRCS = $(TEST).c hash32.c
OBJS = $(addprefix $(OBJDIR)/,$(patsubst %.c,%.o,$(SRCS)))

FPGA_LIBS = -luuid -lopae-c

all: $(TEST)

# AFU info from JSON file, including AFU UUID
AFU_JSON_INFO = $(OBJDIR)/afu_json_info.h
$(AFU_JSON_INFO): ../hw/rtl/$(TEST).json | objdir
	afu_json_mgr json-info --afu-json=$^ --c-hdr=$@
$(OBJS): $(AFU_JSON_INFO)

$(TEST): $(OBJS)
	$(CC) -o $@ $^ $(LDFLAGS) $(FPGA_LIBS) -lrt

$(OBJDIR)/%.o: %.c | objdir
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -rf $(TEST) $(OBJDIR)

objdir:
	@mkdir -p $(OBJDIR)

.PHONY: all clean

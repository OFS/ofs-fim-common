// Copyright 2022 Intel Corporation
// SPDX-License-Identifier: MIT

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <assert.h>
#include <uuid/uuid.h>

#include <opae/fpga.h>

#include "hash32.h"

// State from the AFU's JSON file, extracted using OPAE's afu_json_mgr script
#include "afu_json_info.h"

#define CACHELINE_BYTES 64
#define CL(x) ((x) * CACHELINE_BYTES)

static bool is_ase_sim;
static uint64_t ase_sim_mult;

// When defined, read responses will be turned into write requests.
#define LOOPBACK_AS_WRITE YES

// Number of requests between hash checks. Doing multiple requests forces
// access patterns that might not be seen with only one active read.
// At some size, too many requests are in flight for the loopback
// algorithm and the system deadlocks. This is more a bug in the test
// than the splitters, so we "solve" it by keeping the number of outstanding
// requests reasonable.
#define NUM_MEM_REQS 2

//
// Search for an accelerator matching the requested UUID and connect to it.
//
static fpga_handle connect_to_accel(const char *accel_uuid)
{
    fpga_properties filter = NULL;
    fpga_guid guid;
    fpga_token accel_token;
    uint32_t num_matches;
    fpga_handle accel_handle;
    fpga_result r;

    // Don't print verbose messages in ASE by default
    setenv("ASE_LOG", "0", 0);

    // Set up a filter that will search for an accelerator
    fpgaGetProperties(NULL, &filter);
    fpgaPropertiesSetObjectType(filter, FPGA_ACCELERATOR);

    // Add the desired UUID to the filter
    uuid_parse(accel_uuid, guid);
    fpgaPropertiesSetGUID(filter, guid);

    // Do the search across the available FPGA contexts
    num_matches = 1;
    fpgaEnumerate(&filter, 1, &accel_token, 1, &num_matches);

    // Not needed anymore
    fpgaDestroyProperties(&filter);

    if (num_matches < 1)
    {
        fprintf(stderr, "Accelerator %s not found!\n", accel_uuid);
        return 0;
    }

    // Open accelerator
    r = fpgaOpen(accel_token, &accel_handle, 0);
    assert(FPGA_OK == r);

    // While the token is available, check whether it is for HW
    // or for ASE simulation, recording it so probeForASE() below
    // doesn't have to run through the device list again.
    fpga_properties accel_props;
    uint16_t vendor_id, dev_id;
    fpgaGetProperties(accel_token, &accel_props);
    fpgaPropertiesGetVendorID(accel_props, &vendor_id);
    fpgaPropertiesGetDeviceID(accel_props, &dev_id);
    is_ase_sim = (vendor_id == 0x8086) && (dev_id == 0xa5e);
    ase_sim_mult = is_ase_sim ? 30 : 1;

    // Done with token
    fpgaDestroyToken(&accel_token);

    return accel_handle;
}


//
// Allocate a buffer in I/O memory, shared with the FPGA.
//
static volatile void* alloc_buffer(fpga_handle accel_handle,
                                   ssize_t size,
                                   uint64_t *wsid,
                                   uint64_t *io_addr)
{
    fpga_result r;
    volatile void* buf;

    r = fpgaPrepareBuffer(accel_handle, size, (void*)&buf, wsid, 0);
    if (FPGA_OK != r) return NULL;

    // Get the physical address of the buffer in the accelerator
    r = fpgaGetIOAddress(accel_handle, *wsid, io_addr);
    assert(FPGA_OK == r);

    return buf;
}


uint32_t hash_update(uint32_t cur_hash32, const uint8_t *start_ptr, const uint8_t *end_ptr)
{
    const uint32_t *data_ptr = (const uint32_t*)start_ptr;
    const uint32_t *data_end = (const uint32_t*)end_ptr;

    while (data_ptr < data_end)
    {
        // At the very end, the HW forces 0 into bytes not read. Do the same.
        uint32_t d = *data_ptr;
        if (data_ptr + 1 > data_end)
        {
            uint32_t shift_cnt = 8 * (4 - ((uint64_t)data_end - (uint64_t)data_ptr));
            d <<= shift_cnt;
            d >>= shift_cnt;
        }

        cur_hash32 = hash32(cur_hash32, d);
        data_ptr += 16;
    }

    return cur_hash32;
}


int main(int argc, char *argv[])
{
    fpga_handle accel_handle;
    volatile char *rd_buf, *wr_buf;
    uint64_t rd_wsid, wr_wsid;
    uint64_t rd_buf_pa, wr_buf_pa;
    uint64_t v;
    int error = 0;

    static uint64_t history_rd_start[NUM_MEM_REQS];
    static uint64_t history_wr_start[NUM_MEM_REQS];
    static uint64_t history_len[NUM_MEM_REQS];

    //
    // Hash values are never reset in either HW or SW. Every completion leads
    // to a hash update. The values of HW hashes can be read out at any time
    // via CSRs.
    //
    static uint32_t cur_hash32[16];
    for (int h_idx = 0; h_idx < 16; h_idx += 1)
    {
        cur_hash32[h_idx] = HASH32_DEFAULT_INIT;
    }

    srandom(time(NULL));

    // Find and connect to the accelerator
    accel_handle = connect_to_accel("1acc0321-2286-47fa-a4f5-3b52b635d97b");
    if (0 == accel_handle)
        exit(1);

    // Allocate single page memory buffers
    rd_buf = (volatile char*)alloc_buffer(accel_handle, 512 * getpagesize(),
                                          &rd_wsid, &rd_buf_pa);
    assert(NULL != rd_buf);
    wr_buf = (volatile char*)alloc_buffer(accel_handle, 512 * getpagesize(),
                                          &wr_wsid, &wr_buf_pa);
    assert(NULL != wr_buf);

    // Fill rd_buf with random values
    for (int i = 0; i < 512 * getpagesize() / 4; i += 1)
    {
        *(uint32_t*)&rd_buf[i*4] = random();
    }

    // Tell the accelerator the address of the buffer using cache line
    // addresses.  The accelerator will respond by writing to the buffer.
    for (int i = 0; i < 100000; i += 1)
    {
        printf("%d\n", i);
        memset((void*)wr_buf, 0, 512 * getpagesize());

        // Pick regions to copy
        for (int c = 0; c < NUM_MEM_REQS; c += 1)
        {
            history_rd_start[c] = 1 + (random() & 0x3fff);
            history_len[c] = 8 + (random() & 0x7fff);

            if (c == 0)
            {
                history_wr_start[0] = history_rd_start[0];
            }
            else
            {
                // The write target address keeps incrementing from the initial
                // write address. The start address for the next packet is
                // immediately after the end of the previous one.
                history_wr_start[c] = history_wr_start[c-1] + history_len[c-1];
            }

            // The last byte of the buffer may be used in a spin loop to
            // check for a completed write. Make sure it isn't zero.
            if (rd_buf[history_rd_start[c] + history_len[c] - 1] == 0)
            {
                rd_buf[history_rd_start[c] + history_len[c] - 1] = 1;
            }
        }

        // Swap between using TX-A and TX-B for read requests for
        // each iteration. Setting to 1 uses TX-A, 0 uses TX-B.
        fpgaWriteMMIO64(accel_handle, 0, 24, i & 1);

        for (int c = 0; c < NUM_MEM_REQS; c += 1)
        {
            uint64_t start_addr = rd_buf_pa + history_rd_start[c];
            printf("Start addr: 0x%0lx\n", start_addr);

            printf("Length: 0x%0lx\n", history_len[c]);
            fpgaWriteMMIO64(accel_handle, 0, 0, history_len[c]);

#ifdef LOOPBACK_AS_WRITE
            uint64_t write_addr = wr_buf_pa + history_wr_start[c];
            printf("Write loopback addr: 0x%0lx\n", write_addr);
            if (c == 0)
            {
                // Write target addresses are tracked in the hardware. Only
                // write this register once per interation.
                fpgaWriteMMIO64(accel_handle, 0, 16, write_addr);
            }
#endif

            fpgaWriteMMIO64(accel_handle, 0, 8, start_addr);
        }

        uint32_t usec = 0;
        uint32_t timeout = 1;
        while (usec < 1000000 * ase_sim_mult)
        {
            usleep(1000 * ase_sim_mult);
            usec += 1000 * ase_sim_mult;
#ifdef LOOPBACK_AS_WRITE
            __asm__ volatile ("mfence" : : : "memory");
            if (wr_buf[history_wr_start[NUM_MEM_REQS-1] + history_len[NUM_MEM_REQS-1] - 1])
            {
                timeout = 0;
                break;
            }
#else
            // Number of completions is the expected value?
            fpgaReadMMIO64(accel_handle, 0, 7 * 8, &v);
            if (v == (i + 1) * NUM_MEM_REQS)
            {
                timeout = 0;
                break;
            }
#endif
        }

        if (timeout)
        {
            printf("\nTIMEOUT!\n\n");
        }

        // Compute expected hashes. Replicate the algorithm used on the FPGA
        // in order to check read responses.
        for (int c = 0; c < NUM_MEM_REQS; c += 1)
        {
            for (int h_idx = 0; h_idx < 8; h_idx += 1)
            {
                cur_hash32[h_idx * 2] =
                    hash_update(cur_hash32[h_idx * 2],
                                (const uint8_t*)&rd_buf[history_rd_start[c] + h_idx * 8],
                                (const uint8_t*)&rd_buf[history_rd_start[c] + history_len[c]]);
                cur_hash32[h_idx * 2 + 1] =
                    hash_update(cur_hash32[h_idx * 2 + 1],
                                (const uint8_t*)&rd_buf[history_rd_start[c] + h_idx * 8 + 4],
                                (const uint8_t*)&rd_buf[history_rd_start[c] + history_len[c]]);
            }
        }

        // Compare hashes. Each hash checks 64 bits of the data bus.
        for (int h_idx = 0; h_idx < 8; h_idx += 1)
        {
            fpgaReadMMIO64(accel_handle, 0, (8 + h_idx) * 8, &v);

            uint64_t h = ((uint64_t)cur_hash32[h_idx * 2 + 1] << 32) | cur_hash32[h_idx * 2];
            if (v != h)
            {
                printf("Hash mismatch, idx %d!\n", h_idx);
                printf("  HW 0x%08lx_%08lx  SW 0x%08lx_%08lx\n",
                       v >> 32, v & 0xffffffff,
                       h >> 32, h & 0xffffffff);

                error = 1;
                break;
            }
        }

#ifdef LOOPBACK_AS_WRITE
        int error_cmp = 0;
        for (int c = 0; c < NUM_MEM_REQS; c += 1)
        {
            int r = memcmp((void*)&rd_buf[history_rd_start[c]],
                           (void*)&wr_buf[history_wr_start[c]],
                           history_len[c]);

            if (r)
            {
                printf("Comparison chunk %d FAIL:\n", c);

                uint64_t cnt = 0;
                for (uint64_t i = 0; i < history_len[c]; i += 1)
                {
                    if (rd_buf[history_rd_start[c]+i] != wr_buf[history_wr_start[c]+i])
                    {
                        printf("  0x%lx (0x%lx -> 0x%lx): 0x%hhx 0x%hhx\n", i,
                               rd_buf_pa + history_rd_start[c] + i, wr_buf_pa + history_wr_start[c] + i,
                               rd_buf[history_rd_start[c]+i], wr_buf[history_wr_start[c]+i]);
                        if (cnt++ == 128) break;
                    }
                }
                error_cmp = 1;
                error = 1;
                break;
            }

            if (error_cmp) break;
        }

        if (!error_cmp) printf("Comparison: PASS\n");
#endif

        if (error) break;

        printf("Ok\n\n");
    }

    // Done
    fpgaReleaseBuffer(accel_handle, rd_wsid);
    fpgaClose(accel_handle);

    return 0;
}

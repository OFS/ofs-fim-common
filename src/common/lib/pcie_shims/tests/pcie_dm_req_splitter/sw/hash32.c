// Copyright 2019 Intel Corporation
// SPDX-License-Identifier: MIT

#include "hash32.h"

const uint32_t HASH32_DEFAULT_INIT = 0x14d6;

uint32_t hash32(uint32_t cur_hash, uint32_t data)
{
    // Burst bits into individual buckets
    uint8_t value[32], new_data[32], new_value[32];

    for (int i = 0; i < 32; i++)
    {
        value[i] = cur_hash & 1;
        cur_hash >>= 1;

        new_data[i] = data & 1;
        data >>= 1;
    }

    new_value[31] = new_data[31] ^ value[0];
    new_value[30] = new_data[30] ^ value[31];
    new_value[29] = new_data[29] ^ value[30];
    new_value[28] = new_data[28] ^ value[29];
    new_value[27] = new_data[27] ^ value[28];
    new_value[26] = new_data[26] ^ value[27];
    new_value[25] = new_data[25] ^ value[26];
    new_value[24] = new_data[24] ^ value[25];
    new_value[23] = new_data[23] ^ value[24];
    new_value[22] = new_data[22] ^ value[23];
    new_value[21] = new_data[21] ^ value[22];
    new_value[20] = new_data[20] ^ value[21];
    new_value[19] = new_data[19] ^ value[20];
    new_value[18] = new_data[18] ^ value[19];
    new_value[17] = new_data[17] ^ value[18];
    new_value[16] = new_data[16] ^ value[17];
    new_value[15] = new_data[15] ^ value[16];
    new_value[14] = new_data[14] ^ value[15];
    new_value[13] = new_data[13] ^ value[14];
    new_value[12] = new_data[12] ^ value[13];
    new_value[11] = new_data[11] ^ value[12];
    new_value[10] = new_data[10] ^ value[11];
    new_value[9]  = new_data[9] ^ value[10];
    new_value[8]  = new_data[8] ^ value[9];
    new_value[7]  = new_data[7] ^ value[8];
    new_value[6]  = new_data[6] ^ value[7] ^ value[0];
    new_value[5]  = new_data[5] ^ value[6];
    new_value[4]  = new_data[4] ^ value[5] ^ value[0];
    new_value[3]  = new_data[3] ^ value[4];
    new_value[2]  = new_data[2] ^ value[3] ^ value[0];
    new_value[1]  = new_data[1] ^ value[2] ^ value[0];
    new_value[0]  = new_data[0] ^ value[1] ^ value[0];

    uint32_t new_hash = 0;
    for (int i = 0; i < 32; i++)
    {
        new_hash <<= 1;
        new_hash |= new_value[31-i];
    }

    return new_hash;
}

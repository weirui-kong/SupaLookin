//
//  SPLKEncodeBenchQOIImpl.h
//  SPLKChat
//
//  Created by Weirui Kong on 2026/11/25.
//

// Included by both QOI .c files with SPLK_QOI_ENCODE set, so one body gets two optimization levels.

#include "SPLKEncodeBenchQOI.h"

typedef union {
    struct { uint8_t r, g, b, a; } rgba;
    uint32_t v;
} splk_qoi_rgba_t;

static inline void splk_qoi_write_32(uint8_t *bytes, size_t *p, uint32_t v) {
    bytes[(*p)++] = (uint8_t)(v >> 24);
    bytes[(*p)++] = (uint8_t)(v >> 16);
    bytes[(*p)++] = (uint8_t)(v >> 8);
    bytes[(*p)++] = (uint8_t)v;
}

size_t SPLK_QOI_ENCODE(const uint8_t *bgra, uint32_t width, uint32_t height, uint8_t *bytes) {
    size_t p = 0;
    splk_qoi_write_32(bytes, &p, 0x716f6966);
    splk_qoi_write_32(bytes, &p, width);
    splk_qoi_write_32(bytes, &p, height);
    bytes[p++] = 4;
    bytes[p++] = 0;

    splk_qoi_rgba_t index[64] = {0};
    splk_qoi_rgba_t px_prev = {.rgba = {0, 0, 0, 255}};
    splk_qoi_rgba_t px = px_prev;
    int run = 0;
    size_t px_len = (size_t)width * height * 4;
    size_t px_end = px_len - 4;

    for (size_t i = 0; i < px_len; i += 4) {
        px.rgba.r = bgra[i + 2];
        px.rgba.g = bgra[i + 1];
        px.rgba.b = bgra[i];
        px.rgba.a = bgra[i + 3];

        if (px.v == px_prev.v) {
            run++;
            if (run == 62 || i == px_end) {
                bytes[p++] = (uint8_t)(0xc0 | (run - 1));
                run = 0;
            }
            continue;
        }
        if (run > 0) {
            bytes[p++] = (uint8_t)(0xc0 | (run - 1));
            run = 0;
        }

        int hash = (px.rgba.r * 3 + px.rgba.g * 5 + px.rgba.b * 7 + px.rgba.a * 11) % 64;
        if (index[hash].v == px.v) {
            bytes[p++] = (uint8_t)hash;
        } else {
            index[hash] = px;
            if (px.rgba.a == px_prev.rgba.a) {
                int8_t vr = (int8_t)(px.rgba.r - px_prev.rgba.r);
                int8_t vg = (int8_t)(px.rgba.g - px_prev.rgba.g);
                int8_t vb = (int8_t)(px.rgba.b - px_prev.rgba.b);
                int8_t vg_r = (int8_t)(vr - vg);
                int8_t vg_b = (int8_t)(vb - vg);
                if (vr > -3 && vr < 2 && vg > -3 && vg < 2 && vb > -3 && vb < 2) {
                    bytes[p++] = (uint8_t)(0x40 | (vr + 2) << 4 | (vg + 2) << 2 | (vb + 2));
                } else if (vg_r > -9 && vg_r < 8 && vg > -33 && vg < 32 && vg_b > -9 && vg_b < 8) {
                    bytes[p++] = (uint8_t)(0x80 | (vg + 32));
                    bytes[p++] = (uint8_t)((vg_r + 8) << 4 | (vg_b + 8));
                } else {
                    bytes[p++] = 0xfe;
                    bytes[p++] = px.rgba.r;
                    bytes[p++] = px.rgba.g;
                    bytes[p++] = px.rgba.b;
                }
            } else {
                bytes[p++] = 0xff;
                bytes[p++] = px.rgba.r;
                bytes[p++] = px.rgba.g;
                bytes[p++] = px.rgba.b;
                bytes[p++] = px.rgba.a;
            }
        }
        px_prev = px;
    }

    for (int k = 0; k < 7; k++) {
        bytes[p++] = 0;
    }
    bytes[p++] = 1;
    return p;
}

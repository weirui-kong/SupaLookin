//
//  SPLKQOI.c
//  SPLKImageCodec
//
//  Created by Weirui Kong on 2026/11/25.
//

#include "SPLKQOI.h"

#define SPLK_QOI_OP_INDEX 0x00
#define SPLK_QOI_OP_DIFF 0x40
#define SPLK_QOI_OP_LUMA 0x80
#define SPLK_QOI_OP_RUN 0xc0
#define SPLK_QOI_OP_RGB 0xfe
#define SPLK_QOI_OP_RGBA 0xff
#define SPLK_QOI_MASK_2 0xc0
#define SPLK_QOI_MAGIC 0x716f6966u
#define SPLK_QOI_HEADER_SIZE 14
#define SPLK_QOI_END_SIZE 8

typedef union {
    struct { uint8_t r, g, b, a; } rgba;
    uint32_t v;
} SPLKQOIPixel;

static inline int SPLKQOIHash(SPLKQOIPixel p) {
    return (p.rgba.r * 3 + p.rgba.g * 5 + p.rgba.b * 7 + p.rgba.a * 11) % 64;
}

static inline void SPLKQOIWrite32(uint8_t *bytes, size_t *p, uint32_t v) {
    bytes[(*p)++] = (uint8_t)(v >> 24);
    bytes[(*p)++] = (uint8_t)(v >> 16);
    bytes[(*p)++] = (uint8_t)(v >> 8);
    bytes[(*p)++] = (uint8_t)v;
}

static inline uint32_t SPLKQOIRead32(const uint8_t *bytes) {
    return (uint32_t)bytes[0] << 24 | (uint32_t)bytes[1] << 16 | (uint32_t)bytes[2] << 8 | bytes[3];
}

size_t SPLKQOIMaxEncodedSize(uint32_t width, uint32_t height) {
    return (size_t)width * height * 5 + SPLK_QOI_HEADER_SIZE + SPLK_QOI_END_SIZE;
}

size_t SPLKQOIEncode(const uint8_t *bgra, uint32_t width, uint32_t height, size_t bytesPerRow, uint8_t *bytes) {
    size_t p = 0;
    SPLKQOIWrite32(bytes, &p, SPLK_QOI_MAGIC);
    SPLKQOIWrite32(bytes, &p, width);
    SPLKQOIWrite32(bytes, &p, height);
    bytes[p++] = 4;
    bytes[p++] = 0;

    SPLKQOIPixel index[64] = {0};
    SPLKQOIPixel prev = {.rgba = {0, 0, 0, 255}};
    SPLKQOIPixel px = prev;
    int run = 0;

    for (uint32_t y = 0; y < height; y++) {
        const uint8_t *row = bgra + (size_t)y * bytesPerRow;
        bool lastRow = y == height - 1;
        for (uint32_t x = 0; x < width; x++) {
            const uint8_t *src = row + (size_t)x * 4;
            px.rgba.r = src[2];
            px.rgba.g = src[1];
            px.rgba.b = src[0];
            px.rgba.a = src[3];

            if (px.v == prev.v) {
                run++;
                if (run == 62 || (lastRow && x == width - 1)) {
                    bytes[p++] = (uint8_t)(SPLK_QOI_OP_RUN | (run - 1));
                    run = 0;
                }
                continue;
            }
            if (run > 0) {
                bytes[p++] = (uint8_t)(SPLK_QOI_OP_RUN | (run - 1));
                run = 0;
            }

            int hash = SPLKQOIHash(px);
            if (index[hash].v == px.v) {
                bytes[p++] = (uint8_t)(SPLK_QOI_OP_INDEX | hash);
            } else {
                index[hash] = px;
                if (px.rgba.a == prev.rgba.a) {
                    int8_t vr = (int8_t)(px.rgba.r - prev.rgba.r);
                    int8_t vg = (int8_t)(px.rgba.g - prev.rgba.g);
                    int8_t vb = (int8_t)(px.rgba.b - prev.rgba.b);
                    int8_t vgr = (int8_t)(vr - vg);
                    int8_t vgb = (int8_t)(vb - vg);
                    if (vr > -3 && vr < 2 && vg > -3 && vg < 2 && vb > -3 && vb < 2) {
                        bytes[p++] = (uint8_t)(SPLK_QOI_OP_DIFF | (vr + 2) << 4 | (vg + 2) << 2 | (vb + 2));
                    } else if (vgr > -9 && vgr < 8 && vg > -33 && vg < 32 && vgb > -9 && vgb < 8) {
                        bytes[p++] = (uint8_t)(SPLK_QOI_OP_LUMA | (vg + 32));
                        bytes[p++] = (uint8_t)((vgr + 8) << 4 | (vgb + 8));
                    } else {
                        bytes[p++] = SPLK_QOI_OP_RGB;
                        bytes[p++] = px.rgba.r;
                        bytes[p++] = px.rgba.g;
                        bytes[p++] = px.rgba.b;
                    }
                } else {
                    bytes[p++] = SPLK_QOI_OP_RGBA;
                    bytes[p++] = px.rgba.r;
                    bytes[p++] = px.rgba.g;
                    bytes[p++] = px.rgba.b;
                    bytes[p++] = px.rgba.a;
                }
            }
            prev = px;
        }
    }

    for (int i = 0; i < SPLK_QOI_END_SIZE - 1; i++) {
        bytes[p++] = 0;
    }
    bytes[p++] = 1;
    return p;
}

bool SPLKQOIDecode(const uint8_t *data, size_t length, uint32_t width, uint32_t height, uint8_t *bgra) {
    if (length < SPLK_QOI_HEADER_SIZE + SPLK_QOI_END_SIZE
        || SPLKQOIRead32(data) != SPLK_QOI_MAGIC
        || SPLKQOIRead32(data + 4) != width
        || SPLKQOIRead32(data + 8) != height
        || data[12] != 4) {
        return false;
    }

    SPLKQOIPixel index[64] = {0};
    SPLKQOIPixel px = {.rgba = {0, 0, 0, 255}};
    size_t p = SPLK_QOI_HEADER_SIZE;
    size_t chunksEnd = length - SPLK_QOI_END_SIZE;
    size_t pixelCount = (size_t)width * height;
    int run = 0;

    for (size_t i = 0; i < pixelCount; i++) {
        if (run > 0) {
            run--;
        } else {
            if (p >= chunksEnd) {
                return false;
            }
            uint8_t b1 = data[p++];
            if (b1 == SPLK_QOI_OP_RGB) {
                if (chunksEnd - p < 3) {
                    return false;
                }
                px.rgba.r = data[p++];
                px.rgba.g = data[p++];
                px.rgba.b = data[p++];
            } else if (b1 == SPLK_QOI_OP_RGBA) {
                if (chunksEnd - p < 4) {
                    return false;
                }
                px.rgba.r = data[p++];
                px.rgba.g = data[p++];
                px.rgba.b = data[p++];
                px.rgba.a = data[p++];
            } else if ((b1 & SPLK_QOI_MASK_2) == SPLK_QOI_OP_INDEX) {
                px = index[b1];
            } else if ((b1 & SPLK_QOI_MASK_2) == SPLK_QOI_OP_DIFF) {
                px.rgba.r += ((b1 >> 4) & 0x03) - 2;
                px.rgba.g += ((b1 >> 2) & 0x03) - 2;
                px.rgba.b += (b1 & 0x03) - 2;
            } else if ((b1 & SPLK_QOI_MASK_2) == SPLK_QOI_OP_LUMA) {
                if (p >= chunksEnd) {
                    return false;
                }
                uint8_t b2 = data[p++];
                int vg = (b1 & 0x3f) - 32;
                px.rgba.r += vg - 8 + ((b2 >> 4) & 0x0f);
                px.rgba.g += vg;
                px.rgba.b += vg - 8 + (b2 & 0x0f);
            } else {
                run = b1 & 0x3f;
            }
            index[SPLKQOIHash(px)] = px;
        }
        uint8_t *dst = bgra + i * 4;
        dst[0] = px.rgba.b;
        dst[1] = px.rgba.g;
        dst[2] = px.rgba.r;
        dst[3] = px.rgba.a;
    }
    return true;
}

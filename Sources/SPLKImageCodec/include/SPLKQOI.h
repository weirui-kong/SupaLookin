//
//  SPLKQOI.h
//  SPLKImageCodec
//
//  Created by Weirui Kong on 2026/11/25.
//

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

// QOI (qoiformat.org), 4 channels, over 8-bit premultiplied BGRA: R, G, B and A are bytes 2, 1, 0 and 3 of a pixel.
// See spec/20261125-screenshot-qoi.md.

size_t SPLKQOIMaxEncodedSize(uint32_t width, uint32_t height);

// `out` needs SPLKQOIMaxEncodedSize bytes. Returns the encoded length.
size_t SPLKQOIEncode(const uint8_t *bgra, uint32_t width, uint32_t height, size_t bytesPerRow, uint8_t *out);

// Fills width * height * 4 bytes. Returns false when `data` isn't a complete QOI image of that size.
bool SPLKQOIDecode(const uint8_t *data, size_t length, uint32_t width, uint32_t height, uint8_t *bgra);

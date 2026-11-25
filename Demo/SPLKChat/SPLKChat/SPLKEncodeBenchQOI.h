//
//  SPLKEncodeBenchQOI.h
//  SPLKChat
//
//  Created by Weirui Kong on 2026/11/25.
//

#include <stddef.h>
#include <stdint.h>

// Both encode premultiplied BGRA to QOI (qoiformat.org) and return the encoded length.
// `out` needs width * height * 5 + 22 bytes.
// One is built at -O0, like SPLKServer from source in an app's Debug build; the other at -Os, like the xcframework.
size_t splk_qoi_encode_debug(const uint8_t *bgra, uint32_t width, uint32_t height, uint8_t *out);
size_t splk_qoi_encode_release(const uint8_t *bgra, uint32_t width, uint32_t height, uint8_t *out);

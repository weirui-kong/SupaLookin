# Screenshot encoding bench: iPhone 12 mini, 2026/11/25

Run with SPLK Chat's Screenshot Encoding page (`spec/20261125-screenshot-encoding-bench.md`), launched with `-SPLKChatScreen encodeBench -SPLKChatEncodeBenchAutorun YES`, on the demo's Debug build.

- System codecs (ImageIO, Compression) run the same in any build.
- `QOI, C -Os` matches SPLKServer.xcframework, which `Scripts/build-xcframework.sh` builds with `GCC_OPTIMIZATION_LEVEL=s`.
- `QOI, C -O0` matches SPLKServer built from source by an app's Debug configuration.
- Encode times are medians; sizes are the encoded length. "+Send" assumes 35 MB/s, a rough figure for USB 2.

- Device: iPhone13,1
- System: iOS 27.2
- Build: Debug
- Thermal state at start: nominal
- Thermal state at end: nominal

## Busy UI · 1125×2436 px · 10.5 MB raw

| Codec | Lossless | Size KB | Encode ms | +Send ms @35 MB/s |
|---|---|---|---|---|
| PNG, UIImage.pngData (today) | yes | 1139.7 | 40.0 | 31.8 |
| PNG, filter None | yes | 1139.6 | 39.4 | 31.8 |
| PNG, filter Sub | yes | 900.2 | 51.2 | 25.1 |
| PNG, filter Up | yes | 974.4 | 43.1 | 27.2 |
| raw + LZ4 | yes | 1820.1 | 7.1 | 50.8 |
| raw + LZFSE | yes | 840.5 | 58.1 | 23.5 |
| raw + ZLIB | yes | 799.3 | 99.0 | 22.3 |
| raw + LZBITMAP | yes | 1085.8 | 29.8 | 30.3 |
| raw + LZMESH | yes | 599.3 | 17.4 | 16.7 |
| QOI, C -Os | yes | 884.8 | 9.4 | 24.7 |
| QOI, C -O0 | yes | 884.8 | 16.2 | 24.7 |
| QOI + LZ4, C -Os | yes | 752.3 | 11.0 | 21.0 |
| QOI + LZ4, C -O0 | yes | 752.3 | 17.9 | 21.0 |
| JPEG q0.9, no alpha | no | 202.2 | 6.6 | 5.6 |
| HEIC q0.9 | no | 76.1 | 59.2 | 2.1 |
| AVIF q0.9 | no | 48.9 | 173.1 | 1.4 |

## Dark page · 1125×2436 px · 10.5 MB raw

| Codec | Lossless | Size KB | Encode ms | +Send ms @35 MB/s |
|---|---|---|---|---|
| PNG, UIImage.pngData (today) | yes | 90.8 | 15.9 | 2.5 |
| PNG, filter None | yes | 90.4 | 15.8 | 2.5 |
| PNG, filter Sub | yes | 87.0 | 28.8 | 2.4 |
| PNG, filter Up | yes | 86.4 | 16.1 | 2.4 |
| raw + LZ4 | yes | 95.1 | 0.7 | 2.7 |
| raw + LZFSE | yes | 30.0 | 41.3 | 0.8 |
| raw + ZLIB | yes | 34.8 | 25.7 | 1.0 |
| raw + LZBITMAP | yes | 79.2 | 10.9 | 2.2 |
| raw + LZMESH | yes | 19.8 | 8.4 | 0.6 |
| QOI, C -Os | yes | 65.0 | 4.3 | 1.8 |
| QOI, C -O0 | yes | 65.0 | 8.6 | 1.8 |
| QOI + LZ4, C -Os | yes | 19.0 | 4.3 | 0.5 |
| QOI + LZ4, C -O0 | yes | 19.0 | 8.6 | 0.5 |
| JPEG q0.9, no alpha | no | 75.2 | 6.7 | 2.1 |
| HEIC q0.9 | no | 17.4 | 57.8 | 0.5 |
| AVIF q0.9 | no | 14.5 | 81.0 | 0.4 |

## Translucent card · 1080×660 px · 2.7 MB raw

| Codec | Lossless | Size KB | Encode ms | +Send ms @35 MB/s |
|---|---|---|---|---|
| PNG, UIImage.pngData (today) | yes | 61.6 | 5.9 | 1.7 |
| PNG, filter None | yes | 61.9 | 5.8 | 1.7 |
| PNG, filter Sub | yes | 73.1 | 11.3 | 2.0 |
| PNG, filter Up | yes | 53.9 | 8.1 | 1.5 |
| raw + LZ4 | yes | 109.9 | 0.5 | 3.1 |
| raw + LZFSE | yes | 31.6 | 9.8 | 0.9 |
| raw + ZLIB | yes | 32.5 | 11.3 | 0.9 |
| raw + LZBITMAP | yes | 49.5 | 4.9 | 1.4 |
| raw + LZMESH | yes | 24.2 | 3.2 | 0.7 |
| QOI, C -Os | yes | 116.2 | 1.4 | 3.2 |
| QOI, C -O0 | yes | 116.2 | 2.8 | 3.2 |
| QOI + LZ4, C -Os | yes | 30.5 | 1.4 | 0.9 |
| QOI + LZ4, C -O0 | yes | 30.5 | 2.7 | 0.9 |
| JPEG q0.9, no alpha | no | 49.7 | 1.6 | 1.4 |
| HEIC q0.9 | no | 18.9 | 70.3 | 0.5 |
| AVIF q0.9 | no | 13.1 | 161.2 | 0.4 |

## Chats screen · 1125×2436 px · 10.5 MB raw

| Codec | Lossless | Size KB | Encode ms | +Send ms @35 MB/s |
|---|---|---|---|---|
| PNG, UIImage.pngData (today) | yes | 117.1 | 16.5 | 3.3 |
| PNG, filter None | yes | 117.7 | 17.1 | 3.3 |
| PNG, filter Sub | yes | 126.3 | 30.4 | 3.5 |
| PNG, filter Up | yes | 112.9 | 17.5 | 3.2 |
| raw + LZ4 | yes | 148.7 | 0.8 | 4.2 |
| raw + LZFSE | yes | 67.8 | 45.5 | 1.9 |
| raw + ZLIB | yes | 69.4 | 27.6 | 1.9 |
| raw + LZBITMAP | yes | 125.1 | 19.3 | 3.5 |
| raw + LZMESH | yes | 52.5 | 6.4 | 1.5 |
| QOI, C -Os | yes | 106.1 | 4.2 | 3.0 |
| QOI, C -O0 | yes | 106.1 | 7.7 | 3.0 |
| QOI + LZ4, C -Os | yes | 51.8 | 4.3 | 1.4 |
| QOI + LZ4, C -O0 | yes | 51.8 | 7.9 | 1.4 |
| JPEG q0.9, no alpha | no | 84.0 | 4.7 | 2.3 |
| HEIC q0.9 | no | 27.4 | 106.3 | 0.8 |
| AVIF q0.9 | no | 22.5 | 84.6 | 0.6 |

## Chats, every layer · 180 images · 156.4 MB raw

| Codec | Lossless | Size KB | Encode ms | All cores ms |
|---|---|---|---|---|
| PNG, UIImage.pngData (today) | yes | 1846.2 | 260.0 | 91.1 |
| PNG, filter None | yes | 1810.6 | 267.0 | 90.8 |
| PNG, filter Sub | yes | 2088.5 | 468.8 | 155.5 |
| PNG, filter Up | yes | 1961.1 | 276.1 | 149.8 |
| raw + LZ4 | yes | 2334.4 | 27.3 | 8.3 |
| raw + LZFSE | yes | 991.6 | 1039.0 | 280.5 |
| raw + ZLIB | yes | 1058.2 | 421.5 | 159.4 |
| raw + LZBITMAP | yes | 1902.6 | 293.8 | 92.0 |
| raw + LZMESH | yes | 759.9 | 67.4 | 24.7 |
| QOI, C -Os | yes | 2113.3 | 63.6 | 22.0 |
| QOI, C -O0 | yes | 2113.3 | 123.4 | 48.2 |
| QOI + LZ4, C -Os | yes | 969.7 | 67.6 | 24.0 |
| QOI + LZ4, C -O0 | yes | 969.7 | 135.1 | 50.0 |
| JPEG q0.9, no alpha | no | 1386.3 | 82.9 | 31.2 |
| HEIC q0.9 | no | 1264.6 | 12254.0 | 3354.0 |
| AVIF q0.9 | no | 935.1 | 4962.0 | 2158.1 |


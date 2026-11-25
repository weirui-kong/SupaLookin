# Screenshot encoding bench

## Summary

SPLKServer encodes every screenshot it sends as PNG. Before picking a faster format, the candidates need numbers from real devices, not just a Mac. SPLK Chat gets a bench page that encodes the same screenshots with each candidate and shows how big and how slow each one is. It measures encoding only: the Mac has power to spare for decoding.

The page is a demo tool. Nothing in SPLKServer or Supa Lookin changes.

## Where

- Discover › Benchmarks › Screenshot Encoding, accessibility identifier `discover.encodeBench`.
- Launching with `-SPLKChatScreen encodeBench` opens it directly.
- **Run** in the navigation bar starts a run; **Share** hands the results over as Markdown, to AirDrop or paste on the Mac.
- Adding `-SPLKChatEncodeBenchAutorun YES` starts a run as soon as the page appears, for a device driven from a Mac.
- Every finished run writes the same Markdown to `Documents/encode-bench.md`, where `devicectl device copy from` can fetch it.

## Samples

Every sample is an 8-bit premultiplied BGRA bitmap at the screen's scale, the format SPLKServer's `UIGraphicsBeginImageContextWithOptions` screenshots have.

- **Busy UI**: a full-screen drawing of a list with a gradient header, text, cards and photo-like thumbnails.
- **Dark page**: a full screen that's almost all black, with a title and a tab bar.
- **Translucent card**: a 360×220 pt card with alpha and a soft shadow, like a solo screenshot of a layer.
- **Chats screen**: a live Chats list, embedded behind the results, drawn with `drawViewHierarchyInRect:afterScreenUpdates:` like a group screenshot.
- **Chats, every layer**: a group screenshot of every layer in that Chats list, drawn the way SPLKServer draws them, up to 300 layers. This is the many-small-images load of a hierarchy fetch.

## Codecs

- PNG through `UIImage.pngData()`, what SPLKServer does today.
- PNG through ImageIO with the filter set to None, Sub and Up.
- Raw pixels through the Compression framework: LZ4, LZFSE, ZLIB, LZBITMAP, and LZMESH on iOS 27 and later.
- QOI, alone and followed by LZ4. The encoder is C, built twice: at `-O0`, as an app's Debug configuration compiles SPLKServer from source, and at `-Os`, as `Scripts/build-xcframework.sh` compiles the xcframework.
- Lossy, for reference: JPEG, HEIC and AVIF at quality 0.9, each only where ImageIO can write it. JPEG drops alpha.

## Measuring

- Runs off the main thread, one codec at a time.
- The page stays still while a run is going, so redraws don't take time from the encoders: the title reads "Running…", and the results appear all at once when every codec is done.
- One warm-up encode, then the median of up to 7 runs (3 for the every-layer sample), stopping early once a codec has taken 3 seconds.
- Per codec: encoded size, encode time, and the time to send that size at 35 MB/s, a rough figure for USB 2. The every-layer sample also shows the time with the images spread over all cores.
- The page lists the device model, iOS version, build configuration and thermal state at the start and end of a run, since a hot device slows down.

Results worth keeping go under `Docs/Benchmarks/`, one file per device and date.

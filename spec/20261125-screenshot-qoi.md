# QOI + LZ4 layer screenshots

## Summary

SPLKServer encodes every layer screenshot as PNG, and PNG is most of the time a details sync spends on the device. On an iPhone 12 mini, a hierarchy's 180 group screenshots take 260 ms to encode as PNG and 68 ms as QOI followed by LZ4, at about half the size (`Docs/Benchmarks/20261125-screenshot-encoding-iphone12mini.md`). Layer screenshots now travel as QOI + LZ4 whenever both ends support it, and as PNG otherwise.

## What changes format

Only layer screenshots: the group and solo screenshots in `NodeDetail`, from `FetchDetails`, `FetchModificationPatch` and `ModifyAttribute`.

Everything else stays PNG: the app screenshot and icon in `AppInfo`, and `GetImageViewImage`, whose data Supa Lookin writes to a `.png` file as it comes.

## The format

`EncodedImage.Format` gets `QOI_LZ4 = 4`, and `EncodedImage` gets the pixel size, which a reader needs before it can decompress:

```
uint32 pixel_width = 4;
uint32 pixel_height = 5;
```

`data` is a QOI image (qoiformat.org), 4 channels, compressed with the Compression framework's `COMPRESSION_LZ4`. The QOI pixels are the screenshot's 8-bit premultiplied BGRA bytes, read as R = byte 2, G = byte 1, B = byte 0, A = byte 3, so the reader gets back exactly the bytes the screenshot had. The color space is sRGB. `scale` is the screen scale, as with PNG; the Mac sizes the image in points, its pixel size over `scale`, which is what the PNG's resolution gives it.

The encoder and decoder are C, in a new C target, `SPLKImageCodec`, that `SPLKModelBridge` depends on. C keeps them fast in a Debug source build, where the server is compiled at `-O0`. `SPLKModelBridge` does the LZ4 step.

## Protocol

This is a changed meaning under `20261125-protocol-compatibility.md`: an older Mac can't read `QOI_LZ4`.

- **Capability** `screenshot.qoi`, listed by both ends.
- **Request**: `FetchDetails`, `FetchModificationPatch` and `ModifyAttribute` get `EncodedImage.Format screenshot_format`, the format the Mac asks for (`FetchDetails = 2`, `FetchModificationPatch = 2`, `ModifyAttribute = 6`).
- **SPLKServer** encodes a layer screenshot as `QOI_LZ4` only when `screenshot.qoi` is enabled and the request asks for `QOI_LZ4`. Anything else, an unset field included, gets PNG. If encoding fails, that screenshot goes as PNG.
- **Supa Lookin** asks for `QOI_LZ4` only when `screenshot.qoi` is enabled and the preference below is QOI + LZ4. It decodes each image by its own `format`, whatever it asked for.
- **Without it on either end**, every screenshot is PNG, as today: an older Mac never asks, and an older SPLKServer never lists the capability.

## The preference

The preview settings popover gets a row below "Show maskView and mask layer":
- **Label**: "Screenshot format", with a pop-up menu of "QOI + LZ4" and "PNG".
- **Default**: QOI + LZ4.
- **Stored** in `SPLKPreferenceManager` as `screenshotFormat`, under the `UserDefaults` key `screenshotFormat`.
- **Takes effect** with the next request that fetches screenshots. Screenshots already on the Mac stay as they are.
- Only the live window's popover shows the row. A `.lookin` document has no device to ask.

## Falling back to PNG

When the preference is QOI + LZ4 and the connected app's SPLKServer doesn't list `screenshot.qoi`, the first request that fetches screenshots shows a warning toast at the window's bottom left, once per device session:
- "This device only supports PNG screenshots."
- "Syncing may be slower. Update SPLKServer in the app to use QOI + LZ4."

A reconnect starts a new session, which can show it again.

## Verification

- **`SPLKModelBridgeTests`**:
  - QOI + LZ4 round-trips a premultiplied BGRA screenshot with alpha byte for byte, including rows with padding.
  - A detail encoded with `QOI_LZ4` decodes to an image of the same pixel size as its PNG.
  - The format decision: `QOI_LZ4` only with the capability enabled and the request asking for it; PNG for an older client.
  - Data that doesn't decode, or whose size disagrees with `pixel_width` and `pixel_height`, gives no image rather than a crash.
- **On a device**: SPLK Chat on the iPhone 12 mini syncs with QOI + LZ4 and with PNG, and the preview looks the same.

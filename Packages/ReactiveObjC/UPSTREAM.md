# ReactiveObjC

Vendored from [ReactiveCocoa/ReactiveObjC](https://github.com/ReactiveCocoa/ReactiveObjC) at tag `3.1.0`.

The sources are exactly what CocoaPods produced for macOS from that tag's podspec:

- its `prepare_command` applied: the `extobjc` files `EXT*` / `metamacros` renamed with a `RAC` prefix, and their imports rewritten to match
- its `osx.exclude_files` removed: the UIKit and MapKit categories

Laid out for SPM:

- `Sources/ReactiveObjC/include/ReactiveObjC/` — public headers
- `Sources/ReactiveObjC/PrivateHeaders/ReactiveObjC/` — the podspec's `private_header_files` (`*Private.h`, `*EXTRuntimeExtensions.h`, `RACEmpty*.h`), plus the internal headers that `ReactiveObjC.h` doesn't import, which would otherwise trip `-Wincomplete-umbrella`
- `Sources/ReactiveObjC/` — every `.m`, flattened

SPM can't compile DTrace provider files. `RACCompoundDisposableProvider.d` and `RACSignalProvider.d` are replaced by the headers they generate, `dtrace -h -s <file>.d -o <file>.h`.

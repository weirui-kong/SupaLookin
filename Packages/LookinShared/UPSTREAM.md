# LookinShared

Vendored from [QMUI/LookinServer](https://github.com/QMUI/LookinServer) at commit `985e8afe77aa2f3fab599da4f9882f6e43eed919`.

- `Sources/LookinShared/include/` — every `.h` under upstream `Src/Main/Shared/` and `Src/Base/`
- `Sources/LookinShared/` — every `.m` under the same directories

The upstream subdirectories (`Category/`, `Peertalk/`) are flattened, since the sources reference each other by quoted header name only. File contents are unchanged.




Windows only.

This crate uses the `static-link` feature to switch the Windows link mode in `build.rs`:

- Without `static-link`, the build uses `FTD3XX_X64_DYNAMIC_LIB_DIR` and expects the import library `FTD3XXWU.lib` in that directory.
- With `static-link`, the build uses `FTD3XX_X64_STATIC_LIB_DIR` and links `FTD3XXWU.lib` statically from that directory.

In dynamic mode, `FTD3XXWU.dll` must also be available at runtime via `PATH` or another directory searched by Windows.

Example (PowerShell):

```powershell
$env:FTD3XX_X64_DYNAMIC_LIB_DIR = "C:\path\to\ftdi\library"
cargo build

$env:FTD3XX_X64_STATIC_LIB_DIR = "C:\path\to\ftdi\library"
cargo build --features static-link
```


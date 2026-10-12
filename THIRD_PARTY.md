# Third-party components

## 7-Zip 26.04

- Author: Igor Pavlov, copyright 1999–2026.
- Official release: https://github.com/ip7z/7zip/releases/tag/26.04
- Official macOS archive: https://github.com/ip7z/7zip/releases/download/26.04/7z2604-mac.tar.xz
- Corresponding source: https://github.com/ip7z/7zip/releases/download/26.04/7z2604-src.tar.xz
- Local corresponding source archive: `Vendor/7zip/7z2604-src.tar.xz`.
- `Resources/7zz` is the arm64 slice extracted with `lipo -thin arm64` from the official universal executable. No compression-engine source modifications were made. The build signs the copy embedded in the application.
- License notices: `Resources/7zip-License.txt` and `Resources/LGPL-2.1.txt`, both included in the app bundle. Licenses include LGPL 2.1 or later, BSD notices, and the unRAR restriction. RAR creation is not implemented.

SHA-256 before application signing:

```
bee04358cbcbc7106273cee0e8d72916db2696c48067a3538c34d8cd6fd16578  7z2604-mac.tar.xz
9691944c0fe0d01bb49373a704fb983fd33bc98b1738695179dfbf99ac1734f6  7z2604-src.tar.xz
701cd6753c57fa4301f944179dafa40d7d9cdcb9eee21a521447745a13d29c03  Resources/7zz
```

When distributing binaries, distribute the corresponding source and required notices alongside the release. This project has not published a release.

## libarchive test fixtures

Only test data, not included in the app. Source: https://github.com/libarchive/libarchive/tree/master/libarchive/test
Retrieved 2026-10-12 and uudecoded without content modifications. License notices are in `Tests/Fixtures/libarchive-COPYING.txt`.

| Upstream file | Git blob SHA of encoded original |
| --- | --- |
| test_read_format_rar.rar.uu | f197a2983302f5829de2719bdddcf43b8c59b201 |
| test_read_format_rar5_stored.rar.uu | afd565ff97d461dad905185f83860ecb2f1bccf8 |
| test_read_format_rar4_encrypted.rar.uu | 584183b4a46f6ae5eee33e1946aa705682a5c80c |
| test_read_format_rar5_encrypted.rar.uu | 0a52fa26bb3c92e09b63f87274fedd81e4f171a9 |

Encrypted fixture passwords are public test values described in upstream `test_read_format_rar_encryption.c`; they are not user credentials.

## Project-owned stream fixtures

`Tests/Fixtures/stream.payload.zst` and `stream.tar.zst` were generated locally from the literal UTF-8 text in `testZstandardPlainAndTAR` using the installed Zstandard CLI. The TAR contains `nested/hello.txt` with mtime 0. Tests consume these fixed fixtures and do not require a Zstandard installation.

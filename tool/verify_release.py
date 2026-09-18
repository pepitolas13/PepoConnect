"""Validate release packages and APK native ABIs before uploading them.

Uses only the Python standard library; no Android SDK is needed in the publish job.
Android derives an APK's native ABI support from its lib/<abi>/*.so entries.
"""

import argparse
import sys
from pathlib import Path
from zipfile import BadZipFile, ZipFile


REQUIRED_LIBRARIES = ("libapp.so", "libflutter.so", "libpepo_native.so")
ANDROID_PACKAGES = {
    "PepoConnect-android-arm64-v8a.apk": {"arm64-v8a"},
    "PepoConnect-android-armeabi-v7a.apk": {"armeabi-v7a"},
    "PepoConnect-android-x86_64.apk": {"x86_64"},
    # The universal download intentionally supports both ARM device families.
    "PepoConnect-android-universal.apk": {"arm64-v8a", "armeabi-v7a"},
}
RELEASE_PACKAGES = (
    "PepoConnect-win-x64.exe",
    "PepoConnect-win-x64-portable.zip",
    *(f"PepoConnect-linux-{arch}.{extension}"
      for arch in ("x64", "arm64") for extension in ("tar.gz", "AppImage", "flatpak")),
    *ANDROID_PACKAGES,
    "PepoConnect-ios-unsigned.ipa",
)


def verify_apk(path, expected_abis):
    path = Path(path)
    expected_abis = set(expected_abis)
    with ZipFile(path) as apk:
        native = {}
        for entry in apk.infolist():
            parts = entry.filename.split("/")
            if len(parts) == 3 and parts[0] == "lib" and parts[2].endswith(".so"):
                native.setdefault(parts[1], {})[parts[2]] = entry
        actual_abis = set(native)
        errors = []
        if actual_abis != expected_abis:
            errors.append(
                f"ABI mismatch: expected {', '.join(sorted(expected_abis))}; "
                f"found {', '.join(sorted(actual_abis)) or '(none)'}"
            )
        for abi, libraries in sorted(native.items()):
            missing = [name for name in REQUIRED_LIBRARIES if name not in libraries]
            if missing:
                errors.append(f"{abi} missing {', '.join(missing)}")
            empty = [name for name in REQUIRED_LIBRARIES
                     if name in libraries and libraries[name].file_size == 0]
            if empty:
                errors.append(f"{abi} empty {', '.join(empty)}")
        if errors:
            raise ValueError(f"{path.name}: {'; '.join(errors)}")


def verify_release(directory, android_only=False):
    directory = Path(directory)
    packages = ANDROID_PACKAGES if android_only else RELEASE_PACKAGES
    for name in packages:
        path = directory / name
        if not path.is_file() or path.stat().st_size == 0:
            raise ValueError(f"Missing or empty release package: {name}")
    for name, abis in ANDROID_PACKAGES.items():
        verify_apk(directory / name, abis)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", nargs="?", type=Path, default=Path("dist"))
    parser.add_argument("--android-only", action="store_true", help="Check the four Android APKs only")
    parser.add_argument("--apk", type=Path, help="Check one APK with --abis instead of a release directory")
    parser.add_argument("--abis", help="Comma-separated native ABIs expected in --apk")
    args = parser.parse_args()
    if bool(args.apk) != bool(args.abis):
        parser.error("--apk and --abis must be used together")
    try:
        if args.apk:
            verify_apk(args.apk, args.abis.split(","))
            print(f"Verified {args.apk.name}: {args.abis}")
        else:
            verify_release(args.directory, android_only=args.android_only)
            count = len(ANDROID_PACKAGES) if args.android_only else len(RELEASE_PACKAGES)
            print(f"Verified {count} release packages and all Android native ABIs")
    except (OSError, BadZipFile, ValueError) as error:
        print(f"Release verification failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

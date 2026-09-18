import tempfile
import unittest
from pathlib import Path
from zipfile import ZipFile

from verify_release import verify_apk, verify_release


LIBRARIES = ("libapp.so", "libflutter.so", "libpepo_native.so")
APK_ABIS = {
    "arm64-v8a": ("arm64-v8a",),
    "armeabi-v7a": ("armeabi-v7a",),
    "x86_64": ("x86_64",),
    "universal": ("arm64-v8a", "armeabi-v7a"),
}


class VerifyReleaseTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def apk(self, name="test.apk", abis=("arm64-v8a",), extra=None):
        path = self.root / name
        with ZipFile(path, "w") as apk:
            for abi in abis:
                for library in LIBRARIES:
                    apk.writestr(f"lib/{abi}/{library}", b"native library")
            for entry, content in (extra or {}).items():
                apk.writestr(entry, content)
        return path

    def test_accepts_complete_requested_abis(self):
        verify_apk(self.apk(abis=("arm64-v8a", "armeabi-v7a")), {"arm64-v8a", "armeabi-v7a"})

    def test_rejects_architecture_advertised_only_by_plugin_libraries(self):
        path = self.apk(extra={"lib/x86_64/libplugin.so": b"plugin"})
        with self.assertRaisesRegex(ValueError, "x86_64.*libapp.so.*libflutter.so.*libpepo_native.so"):
            verify_apk(path, {"arm64-v8a", "x86_64"})

    def test_rejects_complete_but_unrequested_architecture(self):
        with self.assertRaisesRegex(ValueError, "ABI.*expected.*arm64-v8a.*found.*x86_64"):
            verify_apk(self.apk(abis=("arm64-v8a", "x86_64")), {"arm64-v8a"})

    def test_rejects_empty_required_library(self):
        path = self.root / "empty.apk"
        with ZipFile(path, "w") as apk:
            for library in LIBRARIES:
                apk.writestr(f"lib/arm64-v8a/{library}", b"" if library == "libapp.so" else b"native")
        with self.assertRaisesRegex(ValueError, "empty.*libapp.so"):
            verify_apk(path, {"arm64-v8a"})

    def test_rejects_apk_without_native_code(self):
        with self.assertRaisesRegex(ValueError, "ABI"):
            verify_apk(self.apk(abis=()), {"arm64-v8a"})

    def android_packages(self):
        for name, abis in APK_ABIS.items():
            self.apk(f"PepoConnect-android-{name}.apk", abis)

    def test_android_only_requires_and_checks_all_four_apks(self):
        self.android_packages()
        verify_release(self.root, android_only=True)
        (self.root / "PepoConnect-android-x86_64.apk").unlink()
        with self.assertRaisesRegex(ValueError, "Missing.*x86_64"):
            verify_release(self.root, android_only=True)

    def test_full_release_requires_all_thirteen_packages(self):
        self.android_packages()
        with self.assertRaisesRegex(ValueError, "Missing.*PepoConnect-win-x64.exe"):
            verify_release(self.root)
        for name in [
            "PepoConnect-win-x64.exe", "PepoConnect-win-x64-portable.zip",
            "PepoConnect-ios-unsigned.ipa",
            *[f"PepoConnect-linux-{arch}.{ext}"
              for arch in ("x64", "arm64") for ext in ("tar.gz", "AppImage", "flatpak")],
        ]:
            (self.root / name).write_bytes(b"release package")
        verify_release(self.root)


if __name__ == "__main__":
    unittest.main()

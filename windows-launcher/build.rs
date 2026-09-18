//! Build script for the PepoConnect Windows launcher.
//!
//! 1. Takes the Flutter release bundle from `PEPO_BUNDLE_DIR` (default:
//!    `../build/windows/x64/runner/Release`) and packs it into
//!    `$OUT_DIR/bundle.tar.zst` (zstd level 19).
//! 2. Hashes the archive with BLAKE3 and exports `PEPO_BUNDLE_ID` as
//!    `<pubspec version>-<16 hex chars>` so the launcher can tell whether the
//!    extracted copy in `%LOCALAPPDATA%` is up to date.
//! 3. Stamps the icon and the VERSIONINFO resource (winresource).

use std::env;
use std::fs::{self, File};
use std::io::{self, BufWriter, Read};
use std::path::{Path, PathBuf};
use std::process;

const DEFAULT_BUNDLE_DIR: &str = "../build/windows/x64/runner/Release";
const APP_EXE: &str = "pepoconnect.exe";
const ZSTD_LEVEL: i32 = 19;

fn main() {
    println!("cargo:rerun-if-env-changed=PEPO_BUNDLE_DIR");
    println!("cargo:rerun-if-changed=build.rs");

    let manifest_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").expect("CARGO_MANIFEST_DIR"));
    let out_dir = PathBuf::from(env::var("OUT_DIR").expect("OUT_DIR"));

    let pubspec = manifest_dir.join("../pubspec.yaml");
    println!("cargo:rerun-if-changed={}", pubspec.display());
    let (version, version_parts) = read_pubspec_version(&pubspec);

    let bundle_dir = match env::var_os("PEPO_BUNDLE_DIR") {
        Some(dir) if !dir.is_empty() => PathBuf::from(dir),
        _ => manifest_dir.join(DEFAULT_BUNDLE_DIR),
    };
    // Cargo scans the whole directory tree when the path is a directory.
    println!("cargo:rerun-if-changed={}", bundle_dir.display());

    if !bundle_dir.join(APP_EXE).is_file() {
        eprintln!();
        eprintln!("error: PepoConnect bundle not found: {}", bundle_dir.display());
        eprintln!("       ({APP_EXE} is missing)");
        eprintln!("       run `flutter build windows --release` first or set PEPO_BUNDLE_DIR");
        eprintln!("       to a folder that contains the release bundle.");
        eprintln!();
        process::exit(1);
    }

    let archive = out_dir.join("bundle.tar.zst");
    if let Err(e) = pack_bundle(&bundle_dir, &archive) {
        eprintln!("error: could not pack {}: {e}", bundle_dir.display());
        process::exit(1);
    }

    let hash = match hash_file(&archive) {
        Ok(h) => h,
        Err(e) => {
            eprintln!("error: could not hash {}: {e}", archive.display());
            process::exit(1);
        }
    };
    let bundle_id = format!("{version}-{}", &hash[..16]);
    println!("cargo:rustc-env=PEPO_BUNDLE_ID={bundle_id}");
    println!(
        "cargo:warning=PepoConnect bundle {} packed ({} bytes, id {bundle_id})",
        bundle_dir.display(),
        fs::metadata(&archive).map(|m| m.len()).unwrap_or(0)
    );

    stamp_resources(&manifest_dir, &version_parts);
}

/// Reads `version: X.Y.Z+N` from pubspec.yaml. Returns the raw version string
/// and its numeric parts (major, minor, patch, build).
fn read_pubspec_version(pubspec: &Path) -> (String, [u16; 4]) {
    let text = fs::read_to_string(pubspec).unwrap_or_default();
    let raw = text
        .lines()
        .map(str::trim)
        .find_map(|l| l.strip_prefix("version:"))
        .map(|v| v.trim().trim_matches(|c| c == '"' || c == '\'').to_string());

    let raw = match raw {
        Some(v) if !v.is_empty() => v,
        _ => {
            println!(
                "cargo:warning=version line not found in {}, using 0.0.0+0",
                pubspec.display()
            );
            "0.0.0+0".to_string()
        }
    };

    let (semver, build) = raw.split_once('+').unwrap_or((raw.as_str(), "0"));
    // Ignore any pre-release suffix (e.g. 1.2.3-beta) for the numeric version.
    let semver = semver.split('-').next().unwrap_or("0.0.0");
    let mut parts = [0u16; 4];
    for (i, piece) in semver.split('.').take(3).enumerate() {
        parts[i] = piece.parse().unwrap_or(0);
    }
    parts[3] = build.split(|c: char| !c.is_ascii_digit()).next().unwrap_or("0").parse().unwrap_or(0);
    (raw, parts)
}

fn pack_bundle(bundle_dir: &Path, archive: &Path) -> io::Result<()> {
    let file = BufWriter::new(File::create(archive)?);
    let mut encoder = zstd::stream::write::Encoder::new(file, ZSTD_LEVEL)?;
    // Not strictly required, but makes the launcher able to size buffers.
    encoder.include_contentsize(true)?;
    {
        let mut builder = tar::Builder::new(&mut encoder);
        builder.follow_symlinks(true);
        builder.append_dir_all(".", bundle_dir)?;
        builder.finish()?;
    }
    let mut file = encoder.finish()?;
    io::Write::flush(&mut file)?;
    Ok(())
}

fn hash_file(path: &Path) -> io::Result<String> {
    let mut hasher = blake3::Hasher::new();
    let mut file = File::open(path)?;
    let mut buf = vec![0u8; 1 << 20];
    loop {
        let n = file.read(&mut buf)?;
        if n == 0 {
            break;
        }
        hasher.update(&buf[..n]);
    }
    Ok(hasher.finalize().to_hex().to_string())
}

fn stamp_resources(manifest_dir: &Path, v: &[u16; 4]) {
    if env::var("CARGO_CFG_TARGET_OS").as_deref() != Ok("windows") {
        return;
    }
    let icon = manifest_dir.join("../windows/runner/resources/app_icon.ico");
    println!("cargo:rerun-if-changed={}", icon.display());

    let version_string = format!("{}.{}.{}.{}", v[0], v[1], v[2], v[3]);
    let version_u64 =
        ((v[0] as u64) << 48) | ((v[1] as u64) << 32) | ((v[2] as u64) << 16) | (v[3] as u64);

    let mut res = winresource::WindowsResource::new();
    if icon.is_file() {
        res.set_icon(&icon.to_string_lossy());
    } else {
        println!("cargo:warning=icon not found at {}, building without icon", icon.display());
    }
    res.set("ProductName", "PepoConnect");
    res.set("FileDescription", "PepoConnect");
    res.set("CompanyName", "PepoTech");
    res.set("InternalName", "PepoConnect");
    res.set("OriginalFilename", "PepoConnect.exe");
    res.set("LegalCopyright", "Copyright (C) 2026 PepoTech. All rights reserved.");
    res.set("FileVersion", &version_string);
    res.set("ProductVersion", &version_string);
    res.set_version_info(winresource::VersionInfo::FILEVERSION, version_u64);
    res.set_version_info(winresource::VersionInfo::PRODUCTVERSION, version_u64);
    res.set_language(0x0409);
    if let Err(e) = res.compile() {
        eprintln!("error: could not compile Windows resources (icon/VERSIONINFO): {e}");
        process::exit(1);
    }
}

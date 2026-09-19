#![windows_subsystem = "windows"]

//! PepoConnect single-file launcher for Windows.
//!
//! The Flutter release bundle is embedded at build time (see `build.rs`) as a
//! `tar.zst` archive. On start the launcher:
//!
//! 1. Picks the install root: the folder of the exe when a `portable.txt`
//!    marker sits next to it, otherwise `%LOCALAPPDATA%\PepoConnect`.
//! 2. Compares `app\.bundle-id` with the id baked into this exe. When they
//!    differ (or the app is missing) it extracts the bundle into a unique
//!    `app.staging-<pid>-<n>`, then swaps `app` -> retained recovery backup and
//!    `app.staging-<pid>` -> `app`. The `app` path therefore never changes
//!    between versions (firewall rules, shortcuts, etc. stay valid).
//! 3. Runs `app\pepoconnect.exe` with the original arguments and returns
//!    immediately.
//!
//! Every error is reported with a MessageBox (in Spanish) and exit code 1.

use std::env;
use std::ffi::OsStr;
use std::fs::{self, OpenOptions};
use std::io;
use std::os::windows::ffi::OsStrExt;
use std::path::{Path, PathBuf};
use std::process::{self, Command};

use windows_sys::Win32::UI::Shell::{SHChangeNotify, SHCNE_ASSOCCHANGED, SHCNF_IDLIST};
use windows_sys::Win32::UI::WindowsAndMessaging::{
    MessageBoxW, MB_ICONERROR, MB_ICONWARNING, MB_OK, MB_SETFOREGROUND,
};

mod preserve;
mod content_swap;

static BUNDLE: &[u8] = include_bytes!(concat!(env!("OUT_DIR"), "/bundle.tar.zst"));
const BUNDLE_ID: &str = env!("PEPO_BUNDLE_ID");

const TITLE: &str = "PepoConnect";
const APP_DIR: &str = "app";
const APP_EXE: &str = "pepoconnect.exe";
const ID_FILE: &str = ".bundle-id";
const PORTABLE_MARKER: &str = "portable.txt";

/// Windows error codes that mean "somebody is still using that folder".
const ERROR_ACCESS_DENIED: i32 = 5;
const ERROR_SHARING_VIOLATION: i32 = 32;
const ERROR_LOCK_VIOLATION: i32 = 33;

enum Failure {
    /// The previous version is still running, so its folder can't be replaced.
    AlreadyRunning,
    /// Anything else. The text is shown to the user as-is.
    Error(String),
}

fn fail(context: &str, e: io::Error) -> Failure {
    Failure::Error(format!("{context}.\n\nDetalle: {e}"))
}

fn main() {
    match run() {
        Ok(()) => {}
        Err(Failure::AlreadyRunning) => {
            message_box(
                "PepoConnect ya está abierto. Ciérralo y vuelve a abrir el nuevo.",
                MB_ICONWARNING,
            );
            process::exit(1);
        }
        Err(Failure::Error(text)) => {
            message_box(&text, MB_ICONERROR);
            process::exit(1);
        }
    }
}

fn run() -> Result<(), Failure> {
    let exe = env::current_exe()
        .map_err(|e| fail("No se ha podido determinar la ruta del lanzador", e))?;
    let exe_dir = exe
        .parent()
        .map(Path::to_path_buf)
        .ok_or_else(|| Failure::Error("No se ha podido determinar la carpeta del lanzador.".into()))?;

    let portable = exe_dir.join(PORTABLE_MARKER).is_file();
    let root = if portable {
        exe_dir
    } else {
        local_app_data()?.join(TITLE)
    };
    fs::create_dir_all(&root).map_err(|e| {
        fail(&format!("No se ha podido crear la carpeta {}", root.display()), e)
    })?;

    let app_dir = root.join(APP_DIR);
    // Only one launcher may recover/install/start a given installation at once.
    let _install_lock = installation_lock(&root)
        .map_err(|e| fail("No se ha podido esperar a la otra actualización", e))?;
    content_swap::recover(&root, &app_dir)
        .map_err(|e| fail("No se ha podido recuperar la actualización", e))?;
    preserve::recover_interrupted_install(&root, &app_dir)
        .map_err(|e| fail("No se ha podido recuperar la instalación anterior", e))?;

    if !is_current(&app_dir) {
        install(&root, &app_dir)?;
        refresh_shell_icons();
    }

    // Pinned taskbar shortcuts can open the extracted runner directly, losing
    // the environment variable. Its updater must still replace this launcher.
    fs::write(app_dir.join(".launcher-path"), exe.to_string_lossy().as_bytes())
        .map_err(|e| fail("No se ha podido guardar la ruta del lanzador", e))?;

    let app_exe = app_dir.join(APP_EXE);
    let mut cmd = Command::new(&app_exe);
    cmd.args(env::args_os().skip(1))
        .current_dir(&app_dir)
        .env("PEPOCONNECT_LAUNCHER", &exe);
    if portable {
        let data = root.join("data");
        let _ = fs::create_dir_all(&data);
        cmd.env("PEPOCONNECT_DATA_DIR", &data);
    }
    // Fire and forget: the launcher must not keep a process around.
    cmd.spawn().map_err(|e| {
        fail(&format!("No se ha podido iniciar {}", app_exe.display()), e)
    })?;
    Ok(())
}

fn local_app_data() -> Result<PathBuf, Failure> {
    match env::var_os("LOCALAPPDATA") {
        Some(dir) if !dir.is_empty() => Ok(PathBuf::from(dir)),
        _ => Err(Failure::Error(
            "No se encuentra la variable de entorno LOCALAPPDATA.\n\n\
             Crea un fichero portable.txt junto a PepoConnect.exe para usar el modo portable."
                .into(),
        )),
    }
}

/// True when `app\` holds exactly the bundle embedded in this exe.
fn is_current(app_dir: &Path) -> bool {
    let id_matches = fs::read_to_string(app_dir.join(ID_FILE))
        .map(|s| s.trim() == BUNDLE_ID)
        .unwrap_or(false);
    id_matches && app_dir.join(APP_EXE).is_file()
}

fn install(root: &Path, app_dir: &Path) -> Result<(), Failure> {
    // Cheap early check: the running exe is locked against writes.
    if app_dir.exists() && exe_locked(app_dir) {
        return Err(Failure::AlreadyRunning);
    }

    let staging = unused_dir(root, &format!("app.staging-{}", process::id()));

    let result = extract(&staging).and_then(|()| swap(root, app_dir, &staging));
    if result.is_err() {
        let _ = fs::remove_dir_all(&staging);
    }
    result
}

fn extract(staging: &Path) -> Result<(), Failure> {
    fs::create_dir_all(staging).map_err(|e| {
        fail(&format!("No se ha podido crear la carpeta temporal {}", staging.display()), e)
    })?;

    let decoder = zstd::stream::read::Decoder::with_buffer(BUNDLE)
        .map_err(|e| fail("No se ha podido abrir el paquete embebido", e))?;
    let mut archive = tar::Archive::new(decoder);
    archive.set_preserve_permissions(false);
    archive.set_preserve_mtime(true);
    archive.set_overwrite(true);
    archive.unpack(staging).map_err(|e| {
        fail(
            &format!(
                "No se ha podido extraer PepoConnect en {}.\n\nComprueba que hay espacio libre en el disco",
                staging.display()
            ),
            e,
        )
    })?;

    if !staging.join(APP_EXE).is_file() {
        return Err(Failure::Error(format!(
            "El paquete embebido no contiene {APP_EXE}. Este lanzador está dañado; descárgalo de nuevo."
        )));
    }
    fs::write(staging.join(ID_FILE), BUNDLE_ID)
        .map_err(|e| fail("No se ha podido escribir el identificador de versión", e))?;
    Ok(())
}

fn swap(root: &Path, app_dir: &Path, staging: &Path) -> Result<(), Failure> {
    if app_dir.exists() {
        preserve::preserve_unknown_files(app_dir, staging)
            .map_err(|e| fail("No se han podido conservar los archivos de la instalación anterior", e))?;
        let old = old_dir(root);
        if let Err(e) = fs::rename(app_dir, &old) {
            // Old updaters retain app/ as their working directory even after
            // Flutter exits. Its contents can still be replaced transactionally.
            if in_use(&e) && !exe_locked(app_dir) {
                return content_swap::install(root, app_dir, staging)
                    .map_err(|e| fail("No se ha podido actualizar la instalación", e));
            }
            return Err(if in_use(&e) || exe_locked(app_dir) {
                Failure::AlreadyRunning
            } else {
                fail(
                    &format!("No se ha podido retirar la versión anterior ({})", app_dir.display()),
                    e,
                )
            });
        }
        if let Err(e) = fs::rename(staging, app_dir) {
            // Put the previous version back so the user still has a working app.
            let _ = fs::rename(&old, app_dir);
            return Err(fail(
                &format!("No se ha podido instalar la nueva versión en {}", app_dir.display()),
                e,
            ));
        }
        // Keep the previous tree until recovery is no longer needed. A rename
        // completing does not prove that the new Flutter application can start.
    } else if let Err(e) = fs::rename(staging, app_dir) {
        return Err(fail(
            &format!("No se ha podido instalar PepoConnect en {}", app_dir.display()),
            e,
        ));
    }
    Ok(())
}

/// Makes Explorer drop its icon cache after an update. `app\pepoconnect.exe`
/// keeps the same path across versions and the shell caches icons by path
/// without looking at the file again, so the taskbar, the Start menu entry and
/// any shortcut would keep showing the icon of the previous version.
fn refresh_shell_icons() {
    // SAFETY: SHCNF_IDLIST with null items is the documented "flush" form; no
    // memory is passed to or retained by the shell.
    // windows-sys declares the event id as i32 but the constant as u32.
    unsafe {
        SHChangeNotify(
            SHCNE_ASSOCCHANGED as i32,
            SHCNF_IDLIST,
            std::ptr::null(),
            std::ptr::null(),
        );
    }
}

/// Never delete an older recovery copy to make room for a new one.
fn old_dir(root: &Path) -> PathBuf {
    unused_dir(root, "app.old")
}

fn unused_dir(root: &Path, prefix: &str) -> PathBuf {
    let first = root.join(prefix);
    if fs::symlink_metadata(&first).is_err() { return first; }
    for suffix in 1_u64.. {
        let candidate = root.join(format!("{prefix}-{}-{suffix}", process::id()));
        if fs::symlink_metadata(&candidate).is_err() { return candidate; }
    }
    unreachable!("directory suffix exhausted")
}

fn in_use(e: &io::Error) -> bool {
    matches!(
        e.raw_os_error(),
        Some(ERROR_ACCESS_DENIED) | Some(ERROR_SHARING_VIOLATION) | Some(ERROR_LOCK_VIOLATION)
    ) || e.kind() == io::ErrorKind::PermissionDenied
}

/// A running executable cannot be opened for writing (sharing violation).
fn exe_locked(app_dir: &Path) -> bool {
    let exe = app_dir.join(APP_EXE);
    if !exe.is_file() {
        return false;
    }
    match OpenOptions::new().write(true).open(&exe) {
        Ok(_) => false,
        Err(e) => matches!(
            e.raw_os_error(),
            Some(ERROR_SHARING_VIOLATION) | Some(ERROR_LOCK_VIOLATION)
        ),
    }
}

fn message_box(text: &str, icon: u32) {
    let text = wide(text);
    let title = wide(TITLE);
    // SAFETY: both buffers are NUL-terminated UTF-16 and outlive the call.
    unsafe {
        MessageBoxW(
            std::ptr::null_mut(),
            text.as_ptr(),
            title.as_ptr(),
            MB_OK | icon | MB_SETFOREGROUND,
        );
    }
}

fn wide(s: &str) -> Vec<u16> {
    OsStr::new(s).encode_wide().chain(std::iter::once(0)).collect()
}

fn installation_lock(root: &Path) -> io::Result<fs::File> {
    use std::os::windows::fs::OpenOptionsExt;
    let deadline = std::time::Instant::now() + std::time::Duration::from_secs(60);
    loop {
        match OpenOptions::new().read(true).write(true).create(true).truncate(false)
            .share_mode(0).open(root.join(".install-lock")) {
            Ok(lock) => return Ok(lock),
            Err(e) if in_use(&e) && std::time::Instant::now() < deadline => {
                std::thread::sleep(std::time::Duration::from_millis(100));
            }
            Err(e) => return Err(e),
        }
    }
}

#[cfg(test)]
mod update_tests {
    use super::*;

    #[test]
    fn upgrades_when_legacy_helper_holds_app_as_working_directory() {
        use std::os::windows::fs::OpenOptionsExt;
        let root = env::temp_dir().join(format!("pepo-launcher-cwd-{}", process::id()));
        fs::create_dir_all(root.join("app")).unwrap();
        fs::create_dir_all(root.join("staged")).unwrap();
        fs::write(root.join("app/pepoconnect.exe"), "old").unwrap();
        fs::write(root.join("app/personal.txt"), "keep").unwrap();
        fs::write(root.join("staged/pepoconnect.exe"), "new").unwrap();
        // The same non-delete-sharing directory handle as a Windows cwd,
        // without changing other concurrently running tests' working directory.
        let lock = OpenOptions::new().read(true).share_mode(3)
            .custom_flags(0x02000000).open(root.join("app")).unwrap();
        let result = swap(&root, &root.join("app"), &root.join("staged"));
        drop(lock);
        let success = result.is_ok();
        let installed = fs::read_to_string(root.join("app/pepoconnect.exe")).unwrap();
        let personal = fs::read_to_string(root.join("app/personal.txt")).unwrap();
        fs::remove_dir_all(root).unwrap();
        assert!(success, "a helper's working directory is not a running application");
        assert_eq!(installed, "new");
        assert_eq!(personal, "keep");
    }
}

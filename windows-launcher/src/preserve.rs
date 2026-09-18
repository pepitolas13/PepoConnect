use std::fs;
use std::io;
use std::path::Path;

/// A crash between the two directory renames leaves the old application in a
/// backup. Restore it before extracting again, retaining every other recovery
/// directory. Staging can belong to another live launcher and is never touched.
pub fn recover_interrupted_install(root: &Path, application: &Path) -> io::Result<()> {
    if fs::symlink_metadata(application).is_ok() {
        return Ok(());
    }
    let mut candidates = Vec::new();
    for entry in fs::read_dir(root)? {
        let entry = entry?;
        let name = entry.file_name();
        let name = name.to_string_lossy();
        let backup = name == "app.old"
            || name.strip_prefix("app.old-").is_some_and(|suffix| {
                !suffix.is_empty() && suffix.chars().all(|c| c.is_ascii_digit() || c == '-')
            });
        if !backup {
            continue;
        }
        let metadata = fs::symlink_metadata(entry.path())?;
        if !metadata.is_dir() || is_link(&metadata) {
            continue;
        }
        let exe = entry.path().join("pepoconnect.exe");
        let id = entry.path().join(".bundle-id");
        let regular =
            |path: &Path| fs::symlink_metadata(path).is_ok_and(|m| m.is_file() && !is_link(&m));
        if regular(&exe)
            && regular(&id)
            && fs::read_to_string(&id).is_ok_and(|s| !s.trim().is_empty())
        {
            candidates.push((metadata.modified().ok(), entry.path()));
        }
    }
    // Restore the most recent complete backup; never discard another candidate.
    candidates.sort_by(|a, b| b.0.cmp(&a.0));
    if let Some((_, backup)) = candidates.first() {
        fs::rename(backup, application)?;
    }
    Ok(())
}

/// Carries unowned regular files forward without changing the previous install.
/// New package files win. Links and incompatible path types abort before swap.
pub fn preserve_unknown_files(previous: &Path, staging: &Path) -> io::Result<()> {
    for entry in fs::read_dir(previous)? {
        let entry = entry?;
        let old = entry.path();
        let new = staging.join(entry.file_name());
        let old_meta = fs::symlink_metadata(&old)?;
        if is_link(&old_meta) {
            return Err(unsafe_path(&old));
        }
        let new_meta = match fs::symlink_metadata(&new) {
            Ok(value) => Some(value),
            Err(error) if error.kind() == io::ErrorKind::NotFound => None,
            Err(error) => return Err(error),
        };
        if new_meta.as_ref().is_some_and(is_link) {
            return Err(unsafe_path(&new));
        }
        if old_meta.is_dir() {
            if new_meta.as_ref().is_some_and(|meta| !meta.is_dir()) {
                return Err(unsafe_path(&new));
            }
            fs::create_dir_all(&new)?;
            preserve_unknown_files(&old, &new)?;
        } else if old_meta.is_file() {
            match new_meta {
                Some(meta) if meta.is_file() => {}
                Some(_) => return Err(unsafe_path(&new)),
                None => {
                    fs::copy(&old, &new)?;
                }
            }
        } else {
            return Err(unsafe_path(&old));
        }
    }
    Ok(())
}

fn unsafe_path(path: &Path) -> io::Error {
    io::Error::new(
        io::ErrorKind::InvalidInput,
        format!("Cannot safely preserve {}", path.display()),
    )
}

fn is_link(metadata: &fs::Metadata) -> bool {
    #[cfg(windows)]
    {
        use std::os::windows::fs::MetadataExt;
        // Includes junctions and other reparse points, not just symbolic links.
        metadata.file_attributes() & 0x400 != 0
    }
    #[cfg(not(windows))]
    {
        metadata.file_type().is_symlink()
    }
}

#[cfg(test)]
mod tests {
    use super::{preserve_unknown_files, recover_interrupted_install};
    use std::fs;
    use std::path::PathBuf;
    use std::time::{SystemTime, UNIX_EPOCH};

    struct Fixture(PathBuf);
    impl Fixture {
        fn new() -> Self {
            let nonce = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_nanos();
            let root = std::env::temp_dir()
                .join(format!("pepo-preserve-test-{}-{nonce}", std::process::id()));
            fs::create_dir_all(root.join("old/data")).unwrap();
            fs::create_dir_all(root.join("new/data")).unwrap();
            Self(root)
        }
    }
    impl Drop for Fixture {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    #[test]
    fn preserves_unknown_files_but_new_bundle_files_win() {
        let f = Fixture::new();
        fs::write(f.0.join("old/data/personal.txt"), "keep").unwrap();
        fs::write(f.0.join("old/pepoconnect.exe"), "old executable").unwrap();
        fs::write(f.0.join("old/.bundle-id"), "old-id").unwrap();
        fs::write(f.0.join("new/pepoconnect.exe"), "new executable").unwrap();
        fs::write(f.0.join("new/.bundle-id"), "new-id").unwrap();
        preserve_unknown_files(&f.0.join("old"), &f.0.join("new")).unwrap();
        assert_eq!(
            fs::read_to_string(f.0.join("new/data/personal.txt")).unwrap(),
            "keep"
        );
        assert_eq!(
            fs::read_to_string(f.0.join("new/pepoconnect.exe")).unwrap(),
            "new executable"
        );
        assert_eq!(
            fs::read_to_string(f.0.join("new/.bundle-id")).unwrap(),
            "new-id"
        );
        assert_eq!(
            fs::read_to_string(f.0.join("old/data/personal.txt")).unwrap(),
            "keep"
        );
    }

    #[test]
    fn path_type_collisions_abort_without_modifying_previous_installation() {
        for old_is_directory in [true, false] {
            let f = Fixture::new();
            if old_is_directory {
                fs::create_dir(f.0.join("old/collision")).unwrap();
                fs::write(f.0.join("old/collision/personal.txt"), "keep").unwrap();
                fs::write(f.0.join("new/collision"), "new file").unwrap();
            } else {
                fs::write(f.0.join("old/collision"), "keep").unwrap();
                fs::create_dir(f.0.join("new/collision")).unwrap();
            }
            assert!(preserve_unknown_files(&f.0.join("old"), &f.0.join("new")).is_err());
            assert!(f.0.join("old/collision").exists());
        }
    }

    #[test]
    fn interrupted_swap_recovers_old_app_and_never_deletes_staging() {
        let f = Fixture::new();
        let backup = f.0.join("app.old-42-1");
        fs::create_dir_all(backup.join("data")).unwrap();
        fs::write(backup.join("pepoconnect.exe"), "old app").unwrap();
        fs::write(backup.join(".bundle-id"), "old-id").unwrap();
        fs::write(backup.join("data/personal.txt"), "only copy").unwrap();
        let staging = f.0.join("app.staging-43-1");
        fs::create_dir_all(&staging).unwrap();
        fs::write(staging.join("pepoconnect.exe"), "new app").unwrap();
        fs::write(staging.join(".bundle-id"), "new-id").unwrap();
        recover_interrupted_install(&f.0, &f.0.join("app")).unwrap();
        assert_eq!(
            fs::read_to_string(f.0.join("app/data/personal.txt")).unwrap(),
            "only copy"
        );
        assert_eq!(
            fs::read_to_string(f.0.join("app/.bundle-id")).unwrap(),
            "old-id"
        );
        assert!(staging.join("pepoconnect.exe").exists());
    }

    #[test]
    fn current_installation_keeps_other_backups_and_active_staging_untouched() {
        let f = Fixture::new();
        fs::create_dir(f.0.join("app")).unwrap();
        for name in ["app.old", "app.staging-123"] {
            fs::create_dir(f.0.join(name)).unwrap();
            fs::write(f.0.join(name).join("personal.txt"), "keep").unwrap();
        }
        recover_interrupted_install(&f.0, &f.0.join("app")).unwrap();
        for name in ["app.old", "app.staging-123"] {
            assert_eq!(
                fs::read_to_string(f.0.join(name).join("personal.txt")).unwrap(),
                "keep"
            );
        }
    }

    #[cfg(windows)]
    #[test]
    fn refuses_junctions_without_following_them() {
        let f = Fixture::new();
        let outside = f.0.join("external");
        fs::create_dir(&outside).unwrap();
        fs::write(outside.join("personal.txt"), "outside").unwrap();
        let junction = f.0.join("old/link");
        let status = std::process::Command::new("cmd.exe")
            .args(["/C", "mklink", "/J"])
            .arg(junction.to_string_lossy().replace('/', "\\"))
            .arg(outside.to_string_lossy().replace('/', "\\"))
            .output()
            .unwrap();
        assert!(
            status.status.success(),
            "junction setup failed: {}",
            String::from_utf8_lossy(&status.stderr)
        );
        assert!(preserve_unknown_files(&f.0.join("old"), &f.0.join("new")).is_err());
        assert!(!f.0.join("new/link").exists());
        assert_eq!(
            fs::read_to_string(outside.join("personal.txt")).unwrap(),
            "outside"
        );
        fs::remove_dir(junction).unwrap();
    }
}

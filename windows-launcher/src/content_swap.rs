//! Compatibility with 0.4.x helpers that keep app/ as their current directory.
//! Keep that directory in place, journal each top-level entry, and retain the
//! previous contents. Recovery is repeatable even if interrupted mid-rollback.

use std::fs::{self, File};
use std::io::{self, Write};
use std::path::{Path, PathBuf};

const JOURNAL: &str = ".app-update";

pub fn install(root: &Path, app: &Path, staging: &Path) -> io::Result<()> {
    recover(root, app)?;
    let journal = root.join(JOURNAL);
    fs::create_dir(&journal)?;
    let result = (|| {
        fs::create_dir(journal.join("previous"))?;
        fs::create_dir(journal.join("planned"))?;
        let mut names = Vec::new();
        for entry in fs::read_dir(staging)? {
            let name = entry?.file_name();
            File::create(journal.join("planned").join(&name))?.sync_all()?;
            names.push(name);
        }
        // The bundle id must not advertise a version before its files exist.
        names.sort_by(|a, b| (a == ".bundle-id", a).cmp(&(b == ".bundle-id", b)));
        fs::rename(staging, journal.join("incoming"))?;
        marker(&journal.join("ready"))?;
        for name in names {
            let target = app.join(&name);
            if fs::symlink_metadata(&target).is_ok() {
                fs::rename(&target, journal.join("previous").join(&name))?;
            }
            fs::rename(journal.join("incoming").join(&name), target)?;
        }
        marker(&journal.join("committed"))
    })();
    match result {
        Ok(()) => {
            // Retention/cleanup must never roll back a committed installation.
            let _ = retain(&journal, root);
            Ok(())
        }
        Err(error) => {
            recover(root, app).map_err(|recovery| {
                io::Error::other(format!("Install: {error}; recovery: {recovery}"))
            })?;
            Err(error)
        }
    }
}

pub fn recover(root: &Path, app: &Path) -> io::Result<()> {
    let journal = root.join(JOURNAL);
    if !journal.exists() {
        return Ok(());
    }
    if journal.join("ready").is_file() && !journal.join("committed").is_file() {
        for entry in fs::read_dir(journal.join("planned"))? {
            let name = entry?.file_name();
            let incoming = journal.join("incoming").join(&name);
            let previous = journal.join("previous").join(&name);
            let installed = app.join(&name);
            // Returning the new entry to incoming also records rollback progress:
            // after restoring previous, the next recovery leaves it untouched.
            if !incoming.exists() && installed.exists() {
                fs::rename(&installed, &incoming)?;
            }
            if previous.exists() {
                fs::rename(previous, installed)?;
            }
        }
    }
    retain(&journal, root)
}

fn marker(path: &Path) -> io::Result<()> {
    let mut file = File::create(path)?;
    file.write_all(b"1")?;
    file.sync_all()
}

fn retain(journal: &Path, root: &Path) -> io::Result<()> {
    for number in 0_u64.. {
        let retained: PathBuf = root.join(format!("app.recovery-{}-{number}", std::process::id()));
        if fs::symlink_metadata(&retained).is_err() {
            return fs::rename(journal, retained);
        }
    }
    unreachable!()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicU64, Ordering};
    use std::time::{SystemTime, UNIX_EPOCH};

    static NEXT_FIXTURE: AtomicU64 = AtomicU64::new(0);

    struct Fixture(PathBuf);
    impl Fixture {
        fn new() -> Self {
            let nonce = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_nanos();
            let unique = NEXT_FIXTURE.fetch_add(1, Ordering::Relaxed);
            let root = std::env::temp_dir().join(format!(
                "pepo-content-swap-{}-{nonce}-{unique}",
                std::process::id()
            ));
            fs::create_dir_all(root.join("app/data")).unwrap();
            fs::create_dir_all(root.join("staged/data")).unwrap();
            for (dir, value) in [("app", "old"), ("staged", "new")] {
                fs::write(root.join(dir).join("pepoconnect.exe"), value).unwrap();
                fs::write(root.join(dir).join(".bundle-id"), value).unwrap();
                fs::write(root.join(dir).join("data/assets"), value).unwrap();
            }
            Self(root)
        }
    }
    impl Drop for Fixture {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    #[test]
    fn installs_and_retains_previous_contents() {
        let f = Fixture::new();
        install(&f.0, &f.0.join("app"), &f.0.join("staged")).unwrap();
        assert_eq!(
            fs::read_to_string(f.0.join("app/.bundle-id")).unwrap(),
            "new"
        );
        let backup = fs::read_dir(&f.0)
            .unwrap()
            .filter_map(Result::ok)
            .find(|entry| {
                entry
                    .file_name()
                    .to_string_lossy()
                    .starts_with("app.recovery-")
            })
            .unwrap();
        assert_eq!(
            fs::read_to_string(backup.path().join("previous/pepoconnect.exe")).unwrap(),
            "old"
        );
    }

    #[test]
    fn recovers_every_interruption_boundary_and_is_repeatable() {
        // Before old is moved, after old is moved, after new is moved,
        // during rollback, and after rollback (before retiring the journal).
        for boundary in 0..5 {
            let f = Fixture::new();
            let j = f.0.join(JOURNAL);
            fs::create_dir_all(j.join("planned")).unwrap();
            fs::create_dir(j.join("previous")).unwrap();
            fs::rename(f.0.join("staged"), j.join("incoming")).unwrap();
            fs::write(j.join("planned/pepoconnect.exe"), "").unwrap();
            marker(&j.join("ready")).unwrap();
            let current = f.0.join("app/pepoconnect.exe");
            let previous = j.join("previous/pepoconnect.exe");
            let incoming = j.join("incoming/pepoconnect.exe");
            if boundary >= 1 {
                fs::rename(&current, &previous).unwrap();
            }
            if boundary >= 2 {
                fs::rename(&incoming, &current).unwrap();
            }
            if boundary >= 3 {
                fs::rename(&current, &incoming).unwrap();
            }
            if boundary >= 4 {
                fs::rename(&previous, &current).unwrap();
            }
            recover(&f.0, &f.0.join("app")).unwrap();
            recover(&f.0, &f.0.join("app")).unwrap();
            assert_eq!(
                fs::read_to_string(current).unwrap(),
                "old",
                "boundary {boundary}"
            );
        }
    }

    #[test]
    fn committed_install_is_not_rolled_back_after_interruption() {
        let f = Fixture::new();
        fs::create_dir(f.0.join(JOURNAL)).unwrap();
        marker(&f.0.join(JOURNAL).join("ready")).unwrap();
        marker(&f.0.join(JOURNAL).join("committed")).unwrap();
        recover(&f.0, &f.0.join("app")).unwrap();
        assert!(!f.0.join(JOURNAL).exists());
        assert!(f.0.join("app/pepoconnect.exe").is_file());
    }

    #[test]
    fn recovery_removes_only_new_entries_without_an_original() {
        let f = Fixture::new();
        let j = f.0.join(JOURNAL);
        fs::create_dir_all(j.join("planned")).unwrap();
        fs::create_dir(j.join("incoming")).unwrap();
        fs::create_dir(j.join("previous")).unwrap();
        fs::write(j.join("planned/new.dll"), "").unwrap();
        fs::write(f.0.join("app/new.dll"), "new dependency").unwrap();
        marker(&j.join("ready")).unwrap();
        recover(&f.0, &f.0.join("app")).unwrap();
        assert!(!f.0.join("app/new.dll").exists());
        assert_eq!(
            fs::read_to_string(f.0.join("app/pepoconnect.exe")).unwrap(),
            "old"
        );
    }

    #[cfg(windows)]
    #[test]
    fn locked_dependency_restores_all_replaced_entries() {
        use std::os::windows::fs::OpenOptionsExt;
        let f = Fixture::new();
        fs::write(f.0.join("app/zz-locked.dll"), "old").unwrap();
        fs::write(f.0.join("staged/zz-locked.dll"), "new").unwrap();
        let _lock = fs::OpenOptions::new()
            .read(true)
            .share_mode(0)
            .open(f.0.join("app/zz-locked.dll"))
            .unwrap();
        assert!(install(&f.0, &f.0.join("app"), &f.0.join("staged")).is_err());
        for name in ["pepoconnect.exe", ".bundle-id", "data/assets"] {
            assert_eq!(
                fs::read_to_string(f.0.join("app").join(name)).unwrap(),
                "old"
            );
        }
    }
}

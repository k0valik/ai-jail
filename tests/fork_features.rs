//! Black-box regression tests for behavior unique to the `mine` fork.
//!
//! Keep these separate from upstream's inline unit-test blocks so upstream
//! test edits do not create avoidable merge conflicts.

use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};
use std::process::{Command, Output};
use std::sync::atomic::{AtomicU64, Ordering};

static NEXT_TEMP: AtomicU64 = AtomicU64::new(0);

struct Fixture {
    root: PathBuf,
    home: PathBuf,
    project: PathBuf,
    bin: PathBuf,
}

impl Fixture {
    fn new() -> Self {
        let root = std::env::temp_dir().join(format!(
            "ai-jail-fork-features-{}-{}",
            std::process::id(),
            NEXT_TEMP.fetch_add(1, Ordering::Relaxed)
        ));
        let home = root.join("home");
        let project = root.join("project");
        let bin = root.join("bin");
        fs::create_dir_all(&home).unwrap();
        fs::create_dir_all(&project).unwrap();
        fs::create_dir_all(&bin).unwrap();
        for command in ["opencode", "fork-agent"] {
            let path = bin.join(command);
            fs::write(&path, "#!/bin/sh\nexit 0\n").unwrap();
            fs::set_permissions(&path, fs::Permissions::from_mode(0o755))
                .unwrap();
        }
        Self {
            root,
            home,
            project,
            bin,
        }
    }

    fn dry_run(&self, command_args: &[&str]) -> Output {
        self.dry_run_with_preferred_path(command_args, None)
    }

    fn dry_run_with_preferred_path(
        &self,
        command_args: &[&str],
        preferred_path: Option<&Path>,
    ) -> Output {
        let old_path = std::env::var_os("PATH").unwrap_or_default();
        let mut paths = preferred_path
            .map(Path::to_path_buf)
            .into_iter()
            .collect::<Vec<_>>();
        paths.push(self.bin.clone());
        paths.extend(std::env::split_paths(&old_path));
        let path = std::env::join_paths(paths).unwrap();

        Command::new(env!("CARGO_BIN_EXE_ai-jail"))
            .args([
                "--dry-run",
                "--clean",
                "--no-mise",
                "--no-toolchains",
                "--no-status-bar",
                "--network",
            ])
            .args(command_args)
            .current_dir(&self.project)
            .env("HOME", &self.home)
            .env("PATH", path)
            .output()
            .unwrap()
    }
}

impl Drop for Fixture {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.root);
    }
}

fn stdout(output: &Output) -> String {
    String::from_utf8_lossy(&output.stdout).into_owned()
}

fn assert_success(output: &Output) {
    assert!(
        output.status.success(),
        "ai-jail dry-run failed:\n{}",
        String::from_utf8_lossy(&output.stderr)
    );
}

#[test]
fn persistent_tmp_cli_adds_a_jail_store_bind_for_the_requested_leaf() {
    let fixture = Fixture::new();
    let output =
        fixture.dry_run(&["--persistent-tmp", "/tmp/jiti", "fork-agent"]);
    assert_success(&output);

    let command = stdout(&output);
    let store = fixture.home.join(".local/share/ai-jail/persistent-tmp");
    assert!(command.contains(&store.display().to_string()));
    assert!(command.contains("/tmp/jiti"));
}

#[test]
fn persistent_tmp_refuses_symlinked_store_parent() {
    let fixture = Fixture::new();
    let outside = fixture.root.join("outside");
    fs::create_dir_all(&outside).unwrap();
    std::os::unix::fs::symlink(&outside, fixture.home.join(".local")).unwrap();

    let output =
        fixture.dry_run(&["--persistent-tmp", "/tmp/jiti", "fork-agent"]);
    assert!(!output.status.success());
    assert!(
        String::from_utf8_lossy(&output.stderr)
            .contains("overlay storage component is not a directory")
    );
    assert!(!outside.join("share/ai-jail/persistent-tmp").exists());
}

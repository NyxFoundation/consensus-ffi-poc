// Build glue between Lake (Lean) and Cargo (Rust).
//
// 1. Trigger `lake build ConsensusLean4:static` so the Lean side is up-to-date.
// 2. Recursively scan `.lake/build/ir/` for `*.c.o.export` objects across the
//    package's own IR root and every dependency's IR root.
// 3. Wrap them with `--start-group / --end-group` so the linker resolves
//    cross-package references regardless of declaration order.
// 4. Resolve the toolchain via `elan which lean` and dynamically link
//    `leanshared` / `Init_shared` plus `stdc++` and `gmp` from there, with
//    `-rpath` baked in so the binary runs without `LD_LIBRARY_PATH`.

use std::path::{Path, PathBuf};
use std::process::Command;

fn main() {
    println!("cargo:rerun-if-changed=build.rs");
    println!("cargo:rerun-if-changed=../ConsensusLean4");
    println!("cargo:rerun-if-changed=../ConsensusLean4.lean");
    println!("cargo:rerun-if-changed=../lakefile.lean");
    println!("cargo:rerun-if-changed=../lean-toolchain");
    println!("cargo:rerun-if-changed=../lake-manifest.json");

    let repo_root = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .expect("manifest dir must have a parent")
        .to_path_buf();

    run_lake_build(&repo_root);

    let exports = collect_export_objects(&repo_root);
    if exports.is_empty() {
        panic!(
            "no .c.o.export objects found under {}/.lake/build — did `lake build :static` run?",
            repo_root.display()
        );
    }

    println!("cargo:rustc-link-arg=-Wl,--start-group");
    for path in &exports {
        println!("cargo:rustc-link-arg={}", path.display());
    }
    println!("cargo:rustc-link-arg=-Wl,--end-group");

    let lean_lib = lean_lib_dir();
    println!("cargo:rustc-link-search=native={}", lean_lib.display());
    println!("cargo:rustc-link-lib=dylib=leanshared");
    println!("cargo:rustc-link-lib=dylib=Init_shared");
    println!("cargo:rustc-link-lib=dylib=stdc++");
    println!("cargo:rustc-link-lib=dylib=gmp");
    println!("cargo:rustc-link-arg=-Wl,-rpath,{}", lean_lib.display());
}

fn run_lake_build(repo_root: &Path) {
    let status = Command::new("lake")
        .args(["build", "ConsensusLean4:static"])
        .current_dir(repo_root)
        .status()
        .expect("failed to spawn `lake build` — is elan installed?");
    if !status.success() {
        panic!("lake build ConsensusLean4:static failed (exit {status})");
    }
}

// IR directories that ship `.c.o.export` files we need to link. The repo's own
// IR plus every transitive dependency that has been built. Mathlib's meta-build
// helpers (Cache / LongestPole / Shake) ship objects we must NOT link in.
const IR_ROOT_HINTS: &[&[&str]] = &[
    &[".lake", "build", "ir"],
    &[".lake", "packages", "aeneas", ".lake", "build", "ir"],
    &[".lake", "packages", "mathlib", ".lake", "build", "ir"],
    &[".lake", "packages", "batteries", ".lake", "build", "ir"],
    &[".lake", "packages", "aesop", ".lake", "build", "ir"],
    &[".lake", "packages", "Qq", ".lake", "build", "ir"],
    &[".lake", "packages", "Cli", ".lake", "build", "ir"],
    &[".lake", "packages", "importGraph", ".lake", "build", "ir"],
    &[".lake", "packages", "LeanSearchClient", ".lake", "build", "ir"],
    &[".lake", "packages", "plausible", ".lake", "build", "ir"],
    &[".lake", "packages", "proofwidgets", ".lake", "build", "ir"],
];

const SKIP_DIR_NAMES: &[&str] = &["Cache", "LongestPole", "Shake"];

fn collect_export_objects(repo_root: &Path) -> Vec<PathBuf> {
    let mut out = Vec::new();
    for components in IR_ROOT_HINTS {
        let mut root = repo_root.to_path_buf();
        for c in *components {
            root.push(c);
        }
        if root.is_dir() {
            walk_collect(&root, &mut out);
        }
    }
    out.sort();
    out
}

fn walk_collect(dir: &Path, out: &mut Vec<PathBuf>) {
    let entries = match std::fs::read_dir(dir) {
        Ok(e) => e,
        Err(_) => return,
    };
    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_dir() {
            let skip = path
                .file_name()
                .and_then(|n| n.to_str())
                .map(|n| SKIP_DIR_NAMES.contains(&n))
                .unwrap_or(false);
            if !skip {
                walk_collect(&path, out);
            }
        } else if path
            .file_name()
            .and_then(|n| n.to_str())
            .map(|n| n.ends_with(".c.o.export"))
            .unwrap_or(false)
        {
            out.push(path);
        }
    }
}

fn lean_lib_dir() -> PathBuf {
    if let Ok(env) = std::env::var("LEAN_LIB_DIR") {
        return PathBuf::from(env);
    }
    let lean_path = Command::new("elan")
        .args(["which", "lean"])
        .output()
        .expect("failed to invoke `elan which lean` — is elan on PATH?");
    if !lean_path.status.success() {
        panic!(
            "`elan which lean` failed: {}",
            String::from_utf8_lossy(&lean_path.stderr)
        );
    }
    let lean_bin = String::from_utf8(lean_path.stdout)
        .expect("elan output is not UTF-8")
        .trim()
        .to_owned();
    let resolved = std::fs::canonicalize(&lean_bin).unwrap_or_else(|_| PathBuf::from(&lean_bin));
    let toolchain = resolved
        .parent()
        .and_then(Path::parent)
        .expect("lean binary must live under <toolchain>/bin")
        .to_path_buf();
    toolchain.join("lib").join("lean")
}

# 🖼️ Build Darktable — Debian/Ubuntu Build & Packaging Script

[![License](https://img.shields.io/badge/license-GPL%203.0+-brightgreen)](https://www.darktable.org/license/)

This script automates the compilation of `darktable` from the `master` branch and generates a **fully functional, lintian-compliant `.deb` package**, including an optional debug symbols package (`darktable-dbgsym`).

Designed for reproducibility and compliance, it handles common packaging issues: permissions, ownership, man pages, copyright, and more — all without requiring `sudo` at the end.

---

## ✨ Features

- ✅ Compiles `darktable` from `master` using **CMake + Ninja**
- ✅ Generates a clean, installable `.deb` package
- ✅ Includes debug symbols in a separate `darktable-dbgsym` package
- ✅ Fixes file ownership and permissions using `fakeroot`
- ✅ Compresses man pages (`.1` → `.1.gz`)
- ✅ Uses DEP-5 format for the `copyright` file
- ✅ No `sudo` required at the end (builds in `/tmp`)
- ✅ Outputs the `.deb` in the current directory
- ✅ Verbose logging for debugging
- ✅ Compatible with non-POSIX filesystems (e.g. external drives)

---

## ⚙️ Prerequisites

Install the required tools:

```bash
sudo apt install git cmake ninja-build dpkg-dev fakeroot
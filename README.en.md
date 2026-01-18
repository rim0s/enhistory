[English](README.en.md) / [中文](README.md)

# Enhistory — Linux shell history enhancer

This project aims to improve Linux shell history behavior, addressing incomplete or missing history entries caused by SSH disconnects or abrupt terminal closures, and preparing for later transcription of history into databases. The repository contains multiple version directories (V1..V5_RC3); each implements and deploys features at different maturity levels.

Main features
- Enhanced persistence: try to ensure commands are reliably written to persistent history.
- Multiple versions: incremental evolution from V1 to V5 — V3 is a stable base, V4 adds inspection and restructuring, V5 introduces a DB transcription interface.
- Optional database: V5 supports transcribing history into a database (`sqlite`, `postgresql`, `mysql`) or using `none` to keep only text caching.

Important notes
- Parts of the code in this repository were generated with AI assistance; the original `readme.txt` also recommends an external, more fully-featured alternative project (Atuin).
- System-level shutdowns or reboots may cause the last few commands executed immediately before shutdown to not be written instantly — this is an OS behavior limitation and is not fully corrected here.

Repository layout and key files
- `history_enhancer.sh`: main script in the root (example/main logic file).
- `install_enhancer.sh`: installer script that copies necessary files to `/etc/profile.d/` and sets permissions.
- `clean_enhancer.sh`: cleanup script for temporary/cache files.
- `V3_release/`, `V4/`, `V5_RC1/`, `V5_RC2/`, `V5_RC3/`: versioned implementations with corresponding install/uninstall scripts and documentation.
- `LICENSE`: project license (please read to confirm usage and distribution terms).

V5-specific files
- `db_transcriber_interface.sh` (in V5_RC*): interface and configuration for database transcription.
- `uninstall_enhancer.sh` (in V5_RC*): uninstaller with options like `--keepdata` and `--clean-all`.

Installation (examples)
Run installer with sudo privileges; test in a non-production environment first.

Default install (copies scripts to `/etc/profile.d/` and activates on next login):

```bash
./install_enhancer.sh
```

V5 examples with database options and keep-data flag:

```bash
./install_enhancer.sh --database-type none --keepdata
./install_enhancer.sh --database-type sqlite --keepdata
./install_enhancer.sh --database-type postgresql --keepdata
./install_enhancer.sh --db-config ./my_db.conf --keepdata
```

Installer actions (typical)
- Copy main script to `/etc/profile.d/history_enhancer_main.sh`.
- Create an entry/config file at `/etc/profile.d/history_enhancer.sh` and set permissions.
- For V5: if DB is chosen, install `db_transcriber_interface.sh` and source it on shell login.

Uninstall examples

```bash
./uninstall_enhancer.sh            # uninstall, keep data by default
./uninstall_enhancer.sh --keepdata # explicitly keep data
./uninstall_enhancer.sh --clean-all# remove all including persistent data
```

Runtime locations
- After installation, main runtime files live under `/etc/profile.d/`:
  - `/etc/profile.d/history_enhancer.sh` — entry/config
  - `/etc/profile.d/history_enhancer_main.sh` — main logic
  - `/etc/profile.d/db_transcriber_interface.sh` — V5 DB interface (if enabled)

Usage & troubleshooting
- The installer sources the entry file on shell startup; verify with `env`/`ps`/`grep` that the scripts are loaded.
- If history is not being written, check permissions of scripts under `/etc/profile.d/` and whether configured cache directories are writable.
- If DB transcription fails, check the DB config file (V5 `--db-config`) and database access rights.

Version notes (short)
- V3: core recording implemented and tested — a stable base.
- V4: expanded inspection features and refactored organization and deployment docs.
- V5: prepared for DB transcription; goal is to use text records as cache and write to DB during idle times.

Known limitations
- Cannot perfectly fix missing/incorrect timestamps or missing last commands caused by OS shutdown/reboot behavior — this is an OS-level limitation.

Acknowledgements & disclaimer
- Some code was AI-assisted; the original `readme.txt` highlights alternative projects (e.g., Atuin). Review scripts for security and permissions before production use.

Contributing / How to improve
- To improve:
  - Edit scripts under the versioned directories and submit PRs.
  - When adding DB support, provide an example `my_db.conf` and initialization scripts, and update `V5_RC*` `readme.txt` with usage examples.

---
See version-specific README files (for example `V5_RC3/readme.txt`) for additional details.

License: see `LICENSE`.

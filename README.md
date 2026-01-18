[English](README.en.md) / [中文](README.md)

# Enhistory — Linux shell history 增强器
本项目旨在增强 Linux shell 的历史记录（history）功能，解决在 SSH 断开、终端异常关闭等情况下命令丢失或记录不完整的问题，并为后续将历史记录转写到数据库做准备。项目包含多个版本分支（V1..V5_RC3），各版本提供不同程度的功能和部署脚本。

**主要特性**
- **增强记录**: 尽量确保命令以可靠方式写入持久记录。
- **多版本**: 从 V1 到 V5，功能逐步演进，V3 为稳定基础，V4 改进了查看与组织，V5 引入数据库转录接口。
- **可选数据库**: V5 系列支持将历史记录转写到数据库（`sqlite`、`postgresql`、`mysql`）或选择 `none` 仅使用文本缓存。

**重要说明**
- 本仓库中部分代码由 AI 生成；作者在 `readme.txt` 中说明了推荐的外部项目（Atuin）作为更完整的替代方案。
- 系统级别的关机/重启可能导致在关机瞬间的最后若干条命令无法即时记录，这是操作系统机制导致的限制，项目不作时间修正性猜测性修复。

**目录与主要文件**
- `history_enhancer.sh`: 根目录下的主要脚本（用于 V? 版本或示例）。
- `install_enhancer.sh`: 根目录安装脚本，负责将需要的脚本复制到 `/etc/profile.d/` 并设置权限。
- `clean_enhancer.sh`: 清理脚本，用于移除临时或缓存文件。
- `V3_release/`, `V4/`, `V5_RC1/`, `V5_RC2/`, `V5_RC3/`: 各版本实现与相应的安装/卸载脚本、说明文件。
- `LICENSE`: 许可文件（请查看以确认使用与分发条款）。

V5 系列中特别的文件：
- `db_transcriber_interface.sh`（位于 V5_RC*/）: 提供数据库转录接口的配置与挂载点。
- `uninstall_enhancer.sh`（位于 V5_RC*）: 卸载脚本，支持 `--keepdata` 与 `--clean-all` 等选项。

**安装（示例）**
请在具有 sudo 权限的环境下运行安装脚本。推荐先在非生产环境中测试。

- 使用默认安装（一般会将脚本复制到 `/etc/profile.d/` 并立即生效）：

```bash
./install_enhancer.sh
```

- V5 系列可选择数据库类型并保留现有数据：

```bash
./install_enhancer.sh --database-type none --keepdata
./install_enhancer.sh --database-type sqlite --keepdata
./install_enhancer.sh --database-type postgresql --keepdata
./install_enhancer.sh --db-config ./my_db.conf --keepdata
```

安装脚本的行为（常见）:
- **复制主脚本** 到 `/etc/profile.d/history_enhancer_main.sh`。
- **安装配置/入口文件** 到 `/etc/profile.d/history_enhancer.sh`（或相应位置），并设置合适的权限。
- 对于 V5：若选择数据库，会同时安装 `db_transcriber_interface.sh` 到 `/etc/profile.d/` 并在 shell 登录时 source 该文件以启用转录接口。

**卸载（示例）**

```bash
./uninstall_enhancer.sh            # 移除已安装脚本，保留数据（默认）
./uninstall_enhancer.sh --keepdata # 明确保留数据
./uninstall_enhancer.sh --clean-all# 彻底清理包括持久数据
```

**配置与运行时文件位置**
- 系统安装后主要文件位于 `/etc/profile.d/`，常见路径：
  - `/etc/profile.d/history_enhancer.sh` —— 配置/入口
  - `/etc/profile.d/history_enhancer_main.sh` —— 主逻辑脚本
  - `/etc/profile.d/db_transcriber_interface.sh` —— V5 的数据库接口（若启用）

**使用与排查**
- 登录 shell 后，脚本会在启动时被 source；你可以通过 `env`/`ps`/`grep` 检查是否已加载对应脚本。
- 若发现记录未写入，请检查 `/etc/profile.d/` 下的脚本权限与内容，并查看脚本内定义的缓存目录是否可写。
- 若选择数据库转录失败，请检查数据库连接配置（在 V5 系列的 `--db-config` 指定的文件）与数据库访问权限。

**版本说明（简要）**
- V3: 实现主要记录功能，已测试稳定，可作为基础版本。
- V4: 扩展了查看功能，重构脚本组织与部署文档。
- V5: 为数据库转录做准备，提供 `db_transcriber_interface.sh` 并支持多种数据库类型；目标是将文本记录作为缓存并在空闲时写入数据库。

**已知限制**
- 无法完美解决系统在关机/重启瞬间造成的最后命令时间戳与记录丢失问题——该限制由操作系统/终端行为决定。

**致谢与免责声明**
- 仓库中的部分实现为 AI 协助生成；作者已在 `readme.txt` 中指出更成熟的替代方案（如 Atuin）。在将本项目用于生产前，请务必审查脚本安全性、权限与数据库访问策略。

**如何贡献 / 修改**
- 若要改进：
  - 在分支上修改对应版本目录下的脚本并提交 PR。
  - 若添加数据库支持，请提供示例 `my_db.conf` 与初始化脚本，并在 `V5_RC*` 的 `readme.txt` 中补充使用示例。

---
项目根目录已包含多个版本的实现，请查看对应目录下的说明文件（例如 `V5_RC3/readme.txt`）。

License: 请参阅 `LICENSE` 文件。

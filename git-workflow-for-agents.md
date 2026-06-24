# Git 操作流程（AI 代理专用）

用户说「上传 Git」「提交」「推送」时，按此流程执行。

---

## 快速命令（标准流程）

```bash
git status                    # 1. 查看变更
git add -A                    # 2. 暂存所有
git commit -m "提交说明"       # 3. 提交（从 AI更新日志.md 取最新标题）
git push                      # 4. 推送 GitHub
git status                    # 5. 验证：应显示 up to date
```

---

## 详细流程

### 1. 查看状态

```bash
git status
```

确认有哪些已修改（`modified:`）和新增文件（`Untracked files:`）。

### 2. 排除不应提交的文件

检查 `git status` 输出中是否包含以下内容，如有则**不要提交**，先修复 `.gitignore`：

| 文件/目录 | 原因 |
|-----------|------|
| `.env.github` | 密钥文件，永远不能提交 |
| `.godot/` | Godot 缓存 |
| `.godot-codex-user/` | AI 工具缓存 |
| `*.log` | 日志文件 |
| `tmp_*` | 临时文件 |
| 任何包含密码/令牌的文件 | 永远不能提交 |

如果上述文件出现在 `Untracked files` 中，先更新 `.gitignore` 再继续。

### 3. 取提交信息

提交信息从 `AI更新日志.md` 获取——使用**最新一条记录的标题**（`## 日期 标题` 格式，去掉日期部分）。

例如日志中最新条目是：
```
## 2026-06-25 外汇应用交互与规范整理
```
则提交信息为：
```
外汇应用交互与规范整理
```

### 4. 暂存并提交

```bash
git add -A
git commit -m "取到的标题"
```

### 5. 推送

```bash
git push
```

### 6. 验证

```bash
git status
```

输出应为：
```
Your branch is up to date with 'origin/main'.
nothing to commit, working tree clean
```

---

## 已知问题 & 解决方案

### 问题1：GitHub 连不上（网络环境）

**现象：** `git push` 报 `Failed to connect to github.com port 443` 或超时。

**原因：** 用户在中国大陆，GitHub 被干扰。

**解决：** 让用户开启 **QuickBee（迅蜂）VPN**，再重试。

### 问题2：中文用户名导致 SSH 路径乱码

**现象：** `git push` 报 `Host key verification failed`，但 `ssh -T git@github.com` 正常。

**原因：** Windows 用户名是中文（`倪阳烔`），Git 内部 MinGW 层对路径编码错误，找不到 `known_hosts`。

**解决：** 已在全局配置中设置 SSH 命令完整路径，不要改动：
```bash
git config --global core.sshCommand "C:/Windows/System32/OpenSSH/ssh.exe"
```

### 问题3：旧 GitHub 凭据冲突

**现象：** `git push` 报 403 错误，提到 `huomao666`。

**原因：** 电脑上存了旧账号的登录信息。

**解决：** 清除旧的 Windows 凭据：
```powershell
cmdkey /list | Select-String "github"
# 找到旧的目标名，然后：
cmdkey /delete:目标名
```

---

## 环境配置摘要（已配好，不用改）

| 项目 | 值 |
|------|-----|
| 远程仓库 | `git@github.com:huomao777-ui/-FX-.git` (SSH) |
| 全局用户名 | `huomao777-ui` |
| SSH 密钥 | `id_ed25519`（已添加到 GitHub） |
| SSH 命令 | `C:/Windows/System32/OpenSSH/ssh.exe` |
| GitHub 令牌 | 存于 Windows 凭据管理器（HTTPS 备用） |
| 凭据助手 | Git Credential Manager (Windows) |

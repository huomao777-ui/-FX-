# Git 操作流程（AI 代理专用）

用户说「上传 Git」或「提交」时，按此流程执行。

---

## 流程

### 1. 查看状态

```bash
git status
```

确认有哪些已修改（`modified:`）和新增文件（`Untracked files:`）。

### 2. 排除不应提交的文件

检查暂存清单中是否包含以下内容，如果有则**不要提交**：

| 文件/目录 | 原因 |
|-----------|------|
| `.env.github` | 密钥文件，已加入 `.gitignore`，不应出现 |
| `.godot/` | Godot 缓存，已加入 `.gitignore`，不应出现 |
| 任何包含密码/令牌的文件 | 永远不要提交 |

如果上述文件出现在 `git status` 的 `Untracked files` 中，说明 `.gitignore` 规则不完整，先修复 `.gitignore` 再继续。

### 3. 暂存并提交

```bash
git add -A
```

如果用户指定了提交信息，就用：
```bash
git commit -m "用户给的信息"
```

如果用户没给，用中文概括本次变更内容，例如：
```bash
git commit -m "外汇沙盒实验场景 & 配置更新"
```

提交信息应**简洁、中文、概括变更内容**。

### 4. 推送到 GitHub

```bash
git push
```

### 5. 验证

```bash
git status
```

输出应为：
```
Your branch is up to date with 'origin/main'.
nothing to commit, working tree clean
```

---

## 凭据说明

GitHub 令牌已通过 `git credential-manager store` 存入 Windows 凭据管理器，用户名为 `huomao777-ui`。`git push` 时自动使用，无需交互。

如果 `git push` 出现 403 错误，检查是否有旧的 GitHub 凭据（如 `huomao666`）干扰：
```powershell
cmdkey /list | Select-String "github"
```
如有旧的先删除，或用 `git credential-manager erase` 清除。

---

## 网络说明

GitHub 在国内可能连接不稳定。如果 `git push` 超时或连接失败，让用户先开启 VPN（迅蜂），再重试。

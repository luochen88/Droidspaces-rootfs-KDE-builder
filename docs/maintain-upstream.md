# 维护分支与同步上游

本仓库是 `Goldzxcbug/Droidspaces-rootfs-KDE-builder` 的 fork，用来维护洛尘自己的 Droidspaces KDE RootFS 构建配置。

## 推荐分支模型

| 分支 | 用途 | 说明 |
|---|---|---|
| `main` | 洛尘定制版 | GitHub Actions 从这里构建和发布 RootFS |
| `sync/upstream-*` | 自动同步分支 | 由 `.github/workflows/sync-upstream.yml` 创建，合并上游更新用 |
| `feature/*` | 临时开发 | 大改动先在这里测试，再合并到 `main` |

不要把个人定制提交到一个所谓“纯净上游分支”里。上游同步交给 workflow 自动创建 PR，确认无误后再合并。

## 自动同步上游

仓库内置 workflow：**同步 KDE 上游**。

默认行为：

- 每天北京时间 04:30 检查一次上游；
- 上游默认是 `Goldzxcbug/Droidspaces-rootfs-KDE-builder:main`；
- 检测到新提交时，创建一个 `sync/upstream-main-*` 分支；
- 自动打开 Pull Request；
- 不会直接覆盖 `main`。

这样可以先看 diff 和 CI 结果，再决定是否合并。

## 手动触发同步

进入 GitHub：

```text
Actions -> 同步 KDE 上游 -> Run workflow
```

参数建议：

| 参数 | 推荐值 |
|---|---|
| `upstream_repo` | `Goldzxcbug/Droidspaces-rootfs-KDE-builder` |
| `upstream_branch` | `main` |
| `target_branch` | `main` |
| `mode` | `pr` |

`mode=pr` 是安全模式，只创建 PR。

如果确认要直接合入，也可以手动选择：

```text
mode=direct
```

但一般不推荐，除非你明确知道上游没有破坏性改动。

## 本地同步命令

如果要在本地手动处理：

```bash
git remote add upstream-kde https://github.com/Goldzxcbug/Droidspaces-rootfs-KDE-builder.git 2>/dev/null || true
git fetch upstream-kde

git switch main
git merge upstream-kde/main
git push origin main
```

如有冲突，解决后：

```bash
git add .
git commit
git push origin main
```

## 开发个人改动

个人修改建议开 feature 分支：

```bash
git switch -c feature/luochen-zsh
# 修改 Dockerfile / scripts / workflow
git add .
git commit -m "feat: add luochen zsh config"
git push -u origin feature/luochen-zsh
```

测试没问题后再合并进 `main`。

## 构建注意事项

- RootFS 构建 workflow 是手动触发，不会因为同步上游自动跑满所有构建。
- `sync-upstream.yml` 只做 Git 同步，不构建镜像。
- 如果上游更新了 workflow 或 Dockerfile，合并 PR 前建议先看 diff。
- 大文件包目录 `anland-build/` 可能经常变化，合并上游时重点检查这里。

# 标签发版

在本地 `main` 更新到与远端相同的提交后，首次发版建议用 `v0.1.0`。

```sh
git tag v0.1.0
git push origin v0.1.0
```

上面的标签命令假设 `origin` 已指向目标 GitHub 仓库，且本机 Git 有权限推送标签。若沿用 API-only 流程，可通过 GitHub Git References API 为已推送的提交创建 `refs/tags/v0.1.0`。创建前先核对 `main` 的提交 SHA，并确认该版本标签尚未使用。

推送 `v*` 标签触发 `Godot Release`。CI 用项目验证过的 Godot `4.5.1-stable` 编辑器和对应模板导出 Linux x86-64、Windows x86-64 和单线程 Web 包，并把三个 ZIP 上传到标签对应的 [GitHub Releases](https://github.com/adoin/escort-under-heaven/releases)。Linux 和 Windows 解压后启动对应的可执行文件。Web 解压后用静态 HTTP 服务托管并访问 `index.html`，例如在解压目录运行 `python3 -m http.server 8000`。

## 缓存与构建继承

- `Cache Godot export templates and imports` 通过 `actions/cache` 保存导出模板和 `.godot/imported`。完整键含 runner 系统、Godot 版本、导出预设哈希及导出输入指纹，回退键匹配相同版本和预设。
- `Restore previous successful build` 下载本 workflow 最近一次成功运行的 `godot-build-base`。不同标签的 Actions 缓存有各自的 ref 范围，因此用 artifact 跨标签传递模板、导入缓存及 ZIP。Godot 版本和导出预设相同时才继承。
- 导出输入完全相同时校验并复用三个 ZIP，跳过编辑器安装、导入和导出。输入改变时 Godot 复用已有导入产物，并为三个平台重新封装。缓存未命中且旧 artifact 缺失、已过期或不兼容时，CI 自动补齐模板并构建。
- 在 Actions 展开缓存与继承步骤，查看 `Cache restored from key`、旧产物恢复或复用日志，并对比 `Install pinned Godot and missing templates` 与 `Import changes and export Linux Windows Web` 的耗时或跳过状态。

## 保留与验证

- `Upload build base for 7 days` 将 Actions artifact 保存 7 天。已发布的 Release 附件与 Actions artifact 独立保存。
- `Retain 3 successful and 3 failed release runs` 在构建和发布结束后，用 `GITHUB_TOKEN` 分页读取本 workflow 的运行记录，计入当前运行的构建、发布结果，按创建时间各保留最近 3 个成功和 3 个失败。旧的已完成运行连同日志及 artifacts 一起删除。清理失败会提供日志，后续运行会再次尝试。
- 标签发版排队依次执行。在仓库 **Actions → Godot Release** 查看记录。等待队列清空且清理成功后，成功和失败记录各应至多 3 条。取消的运行由下一次执行清理的运行删除。

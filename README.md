# 镖行天下 / Escort Under Heaven

一款用 Godot 开发的像素风武侠 RPG，借鉴《Stoneshard》的格子回合战斗和远征循环，让玩家接榜闯荡江湖、带伤撤回客栈并用赏银与武学成长整备下一趟。

《镖行天下 / Escort Under Heaven》的主角开局由镖局收留，靠接镖走镖立足，沿途参与各门派故事，可走向三种结局，执掌锦衣卫或东厂、成为明朝首富，或成为武林盟主。

## 启动

使用 Godot 4.5.1 打开 `project.godot`，按 `F6` 运行已打开的 `scenes/game.tscn`，或按 `F5` 运行项目。在工程目录也可使用本地安装的 Linux 引擎。

```sh
~/workspace/tools/godot/godot --path . --editor
~/workspace/tools/godot/godot --path .
~/workspace/tools/godot/godot --headless --path . --import
~/workspace/tools/godot/godot --headless --path . --script tests/playtest.gd
```

界面使用系统中文字体，例如 Noto Sans CJK SC、微软雅黑或苹方。动作完成后更新 `user://session.save`。归雁客栈投宿写入 `user://inn.save`，死亡时回退到该检查点。新角色使用同一个本地存档位，选择天赋前会显示覆盖提醒。

## 操作

| 按键 | 动作 |
| --- | --- |
| `WASD` / 方向键 | 四向走一格。点地格可预览，再点确认。进入交战后逐格确认。 |
| `E` / 点击附近的标记两次 | 交互、进出区域、搜物证或打开服务。 |
| `F` / `1` / `Shift+1` | 普攻 / 外功 / 内功注劲外功。可先用鼠标选择敌人。 |
| `2` / `3` / `4` / `5` | 面向敌人格挡 / 调息 / 选择跃步落点 / 金创药止血。跃步可点击落点，或按方向跃两格。 |
| `Q` / `C` / `.` 或 `Space` | 换兵 / 轻步 / 等待。 |
| `I` / `K` / `J` / `G` / `Esc` | 行囊和装备 / 武学和属性 / 榜单和见闻 / 江湖进度 / 取消或暂停。 |

## P0 范围

- 长风镖局收留与三选一天赋，演练止血，在青水县接失镖榜。林道有北官道、南林径两条走法。黑松寨有账册与可选藏货间。带账册回归雁客栈交榜、整备，可搁置门派线索并接下一榜。
- 同一计拍规则覆盖移动、敌方行动、刀剑招式、格挡、调息与跃步。寨头重斩分蓄势和释放，带威胁格提示。流血、腿伤、饥渴、属性点、武学点及固定格数行囊均已接入。
- 支持本地买卖、耐久修理、赏银、投宿检查点及行动续玩。四阶段、三结局判定和任职互斥均有入口。判定所需的后期事件、跨区商路、属性心法、进阶轻功与其余外功由后续阶段扩展。
- 画面使用 768×480 像素网格、最近邻纹理过滤和程序生成占位。尺寸和替换路径见 [美术占位说明](docs/art-placeholder.md)。验证步骤与实测结果见 [试玩检查表](docs/playtest-checklist.md)。

## 设计文档

| 文档 | 内容 |
| --- | --- |
| [《Stoneshard》玩法拆解](docs/stoneshard-deconstruction.md) | 十个系统的玩法规则、乐趣、失败体验和设计借鉴 |
| [武侠改编与 MVP 设计](docs/wuxia-adaptation.md) | 十个系统的武侠映射、移动端取舍、MVP 优先级与 Godot 模块建议 |
| [主线、结局与武功](docs/mainline-endings-and-martial-arts.md) | 镖局开局、门派故事、三种结局与内功、外功、轻功设计 |

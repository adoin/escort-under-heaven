# pixelfx 像素特效参考与 Godot 接入

## 是什么

pixelfx 是一个无依赖的 JavaScript 像素特效库，提供 244 个由小段代码生成的特效与动画，分布在 21 个分类中。每个特效位于 `src/fx/<category>/<name>.js`。可以在浏览器画廊或 Patch 中试玩、换色和镜像，也可以直接用于浏览器游戏，或导出精灵表供其他引擎使用。

项目还提供 Claude Code skill，遵循“起草 → 渲染 → 观察 → 改进”的制作流程。角色相关效果包含蓄力、释放、命中停顿和收招；其中 12 个 moves 将多个效果串成完整攻击动作。

## 特效分类

以下分类和数量来自 README：

| 分类 | 数量 | 内容举例 |
|---|---:|---|
| moves | 12 | 射箭、突进斩、地面重击、投掷火球、剑连击 |
| fire | 12 | 营火、蜡烛、火焰吐息、火环、火龙卷 |
| explosions | 12 | 爆炸桶、大爆炸、烟花 |
| water | 12 | 气泡、喷泉、间歇泉、涟漪 |
| ice | 10 | 冰霜新星、冰晶、冰枪 |
| lightning | 11 | 球状闪电、连锁闪电、雷击 |
| sci-fi | 12 | EMP、能量核心、力场、全息影像 |
| melee | 12 | 爪击、匕首连击、双斩、重锤 |
| impacts | 11 | 钝击、暴击、落地、受击闪光 |
| projectiles | 13 | 箭、弹道、炮弹、追踪导弹 |
| spawn & death | 10 | 消散、孵化、重生光束 |
| arcane | 12 | 奥术光束、魔法飞弹、闪现、法阵 |
| holy | 10 | 祝福、神圣护盾、治疗、光环 |
| shadow | 12 | 黑洞、诅咒、暗影爆炸 |
| status | 13 | 流血、燃烧、魅惑、冰冻 |
| nature | 13 | 酸液、巨石、地刺、毒云 |
| weather | 12 | 极光、暴风雪、落叶、萤火虫 |
| ui | 12 | 成就、连击计数、倒计时、暴击数字 |
| pickups | 11 | 开箱、旋转金币、宝石、生命拾取 |
| transitions | 10 | 百叶窗、烧蚀、菱形擦除、光圈 |
| critters | 12 | 蝙蝠、鸟、蝴蝶、鱼群、飞行骷髅 |

magic 是 README 对魔法效果的概括，具体分类包括 arcane、holy、shadow 等，并没有单独名为 magic 的目录。CATALOG 开头进一步列出了 moves、fire 和 explosions 的动作说明、尺寸、循环属性与时长，可用于选型。

## 接入 Godot 4.5.1

pixelfx 是 JS 库，没有现成的 pixelfx 专用 Godot 插件；不要把它当作可直接装入 Godot 的原生特效组件。

优先采用离线导出精灵表的方式：在开发环境运行 README 提供的命令，例如：

```bash
node tools/render.mjs ice/frost-nova --sheet
```

该命令输出透明 PNG 帧网格及 Aseprite 风格 JSON，包含帧矩形、时长，以及 `meta.pixelfx` 中的 fps、loop、columns 和 pivot。将 PNG 导入 Godot，按网格或帧矩形创建 `SpriteFrames`，通过 `AnimatedSprite2D` 播放，并根据元数据设置帧时长、循环及枢轴偏移。README 提到通用 Aseprite 导入器可以读取这种格式，但这不等于 pixelfx 提供了 Godot 插件；第三方导入器对 Godot 4.5.1 的支持需另行核验，也可以手工配置。

另一条路线是借鉴其方法论，用 GDScript、Godot 动画或着色器重新实现：先做小样，渲染检查，再迭代轮廓、调色板与动作节奏。完整攻击可参考 moves 的蓄力、释放、命中停顿、收招结构，并将视觉时序与游戏伤害判定分别配置。JS 源码不能直接作为 GDScript 执行。

## 后续实现注意点

- **性能与体积：** 按需导出效果，控制帧数、分辨率、纹理尺寸及同时播放数量；先在目标浏览器和低性能设备上测量显存、加载时间与帧率。较大的 moves 和爆炸效果尤其需要预算，避免一次打包全部 244 个效果。
- **像素显示：** 在 Godot 中使用最近邻纹理过滤，核对透明边缘、缩放、锚点及前后遮挡；导出结果的光效合成是否符合游戏画面，需要实际观察。
- **动画信息：** 保留每帧时长、循环标记和 pivot；一次性攻击与循环环境效果采用不同播放和回收逻辑。
- **Web 单线程：** 将 Node 渲染工具放在开发期离线运行，运行时仅播放已导出的纹理，避免引入 JS 实时像素模拟的主线程成本。Godot Web 导出应关闭线程支持，并检查自定义实现及其他依赖是否要求线程或 `SharedArrayBuffer`。本次仅阅读指定文档片段，未实际执行 Godot 导入或 Web 构建测试。

## 来源

- 项目：https://github.com/patch-gg/pixelfx
- README：https://github.com/patch-gg/pixelfx/blob/main/README.md
- 分类目录：https://github.com/patch-gg/pixelfx/blob/main/docs/CATALOG.md
- 浏览器画廊：https://patch-gg.github.io/pixelfx/

兼容性结论：采用离线导出 PNG 精灵表并在 Godot 原生播放的方式，原则上兼容 Godot 4.5.1 / Web 单线程，因为运行时不依赖 pixelfx 的 JS 库、Node 或多线程；实际兼容性仍需导入与 Web 导出验证。

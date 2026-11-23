# 美术占位与替换

工程使用 768×480 逻辑视口进行整数放大，纹理使用最近邻采样。地图每格 20×20 像素。当前格子、人物、地图标记由 `ui/board_view.gd` 绘制，基础颜色来自 `assets/placeholder/palette.json`。

## 替换接口

在 `assets/placeholder/` 放入下列同名 PNG。重新导入并运行后，地图视图会自动读取相应纹理。可逐项替换。

| 文件名 | 用途 | 尺寸及约定 |
| --- | --- | --- |
| `floor.png` | 铺地 | 20×20，单格无缝，当前接口共用于三区 |
| `wall.png`、`door.png`、`brush.png`、`low.png` | 墙、通行门洞、草丛、低障 | 各 20×20，铺满底层，无需透明边缘 |
| `player.png`、`sentry.png`、`raider.png`、`chief.png`、`trainer.png` | 游侠、巡哨、刀匪、寨头、演练镖师 | 各 20×20，RGBA 透明背景，脚底建议在本格第 16 行，顶部和边缘留出朝向、警觉及血条空间 |
| `site.png` | 所有地图交互点的共用标框 | 20×20，RGBA，中心透明或低对比 |

统一使用小写英文标识。同一个标识始终表示同一种格子或单位。正式制作分区图块、四向帧和不同地点图标时，可扩展 `ui/board_view.gd` 的纹理选择，继续从 `data/world.json` 的符号和单位类型读取规则。朝向提示、蓄势红格、血条和路径预览单独绘制。

`ui/game.gd` 的 `_make_theme()` 与 `_box()` 是面板、字体及按钮的主题替换入口，`_play_tone()` 是程序合成反馈音的替换入口。标题使用文本。装备与物品当前使用文字条目，后续图标建议按 `data/campaign.json` 的稳定 ID 命名，例如 `medicine.png`，使用 16×16 RGBA。

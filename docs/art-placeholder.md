# 美术占位与替换

工程使用 768×480 逻辑视口进行整数放大，纹理使用最近邻采样。地图每格 20×20 像素。当前格子、人物、地图标记由 `ui/board_view.gd` 绘制，基础颜色来自 `assets/placeholder/palette.json`。仓库内的 `tools/generate_placeholder_art.py` 会离线生成一套可替换的像素占位图（需 Python Pillow），不改变地图数据、移动规则或战斗数值。

## 替换接口

在 `assets/placeholder/` 放入下列同名 PNG。重新导入并运行后，地图视图会自动读取相应纹理。可逐项替换。

| 文件名 | 用途 | 尺寸及约定 |
| --- | --- | --- |
| `floor.png` | 通用铺地兼容图；缺少具体区域贴图时使用 | 20×20，单格无缝，铺满底层 |
| `floor_town.png`、`floor_forest.png`、`floor_camp.png` | 县城草地、林地、山寨地面 | 20×20，单格无缝，铺满底层 |
| `road_town.png`、`road_forest.png`、`road_camp.png` | 县城土路、林道、山寨行路 | 20×20，单格无缝，铺满底层 |
| `wall_town.png`、`wall_forest.png`、`wall_camp.png`、`wall.png` | 县城建筑、林木、寨墙及通用墙 | 20×20，铺满底层，无需透明边缘 |
| `door.png`、`brush.png`、`low.png` | 通行门洞、草丛、低障 | 各 20×20，铺满底层，无需透明边缘 |
| `player.png`、`sentry.png`、`raider.png`、`chief.png`、`trainer.png` | 游侠、巡哨、刀匪、寨头、演练镖师 | 各 20×20，RGBA 透明背景，脚底建议在本格第 16 行，顶部和边缘留出朝向、警觉及血条空间 |
| `site.png` | 地图交互点的通用标框 | 20×20，RGBA，中心透明或低对比 |
| `site_hall.png`、`site_board.png`、`site_shop.png`、`site_inn.png`、`site_travel.png`、`site_evidence.png`、`site_cache.png` | 镖局、榜亭、商铺、客栈、出入口、账册、藏货间 | 各 20×20，RGBA 透明背景；用图形区分地点，不再绘制字母 |

统一使用小写英文标识。同一个标识始终表示同一种格子或单位。`board_view.gd` 依据区域和地图符号选择县城草地/土路、林地/林道、山寨地面/行路以及对应墙体；地点图标依据 `data/world.json` 的 `action` 选择。正式制作分区图块、四向帧和不同地点图标时，可继续扩展纹理选择，仍从 `data/world.json` 的符号和单位类型读取规则。朝向提示、蓄势红格、血条和路径预览单独绘制。

`ui/game.gd` 的 `_make_theme()` 与 `_box()` 是面板、字体及按钮的主题替换入口，`_play_tone()` 是程序合成反馈音的替换入口。标题使用文本。装备与物品当前使用文字条目，后续图标建议按 `data/campaign.json` 的稳定 ID 命名，例如 `medicine.png`，使用 16×16 RGBA。

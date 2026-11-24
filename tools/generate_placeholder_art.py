"""Generate small nearest-neighbour placeholder art for the map.

The files deliberately stay tiny (20x20) so they can be replaced one-for-one
by production art using the interface documented in docs/art-placeholder.md.
"""

from pathlib import Path
from PIL import Image, ImageDraw


OUT = Path(__file__).resolve().parents[1] / "assets" / "placeholder"
OUT.mkdir(parents=True, exist_ok=True)


def tile(name, base, details):
    image = Image.new("RGBA", (20, 20), base)
    draw = ImageDraw.Draw(image)
    for rect, color in details:
        draw.rectangle(rect, fill=color)
    image.save(OUT / f"{name}.png")


def sprite(name, draw_fn):
    image = Image.new("RGBA", (20, 20), (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(image))
    image.save(OUT / f"{name}.png")


def terrain():
    tile("floor", "#6a8e58", [
        ((2, 3, 3, 4), "#84a766"), ((14, 5, 16, 6), "#527747"),
        ((7, 14, 8, 15), "#527747"), ((17, 16, 18, 17), "#9aaf6b"),
        ((4, 11, 5, 11), "#9aaf6b"), ((11, 2, 12, 2), "#527747"),
    ])
    tile("floor_town", "#6a8e58", [
        ((2, 3, 3, 4), "#84a766"), ((14, 5, 16, 6), "#527747"),
        ((7, 14, 8, 15), "#527747"), ((17, 16, 18, 17), "#9aaf6b"),
        ((4, 11, 5, 11), "#9aaf6b"), ((11, 2, 12, 2), "#527747"),
    ])
    tile("road_town", "#ad875b", [
        ((0, 1, 19, 2), "#bf9968"), ((0, 17, 19, 18), "#8d684a"),
        ((3, 6, 5, 7), "#c9a875"), ((13, 12, 15, 13), "#8d684a"),
        ((8, 15, 9, 16), "#d2ad79"), ((17, 4, 18, 5), "#8d684a"),
    ])
    tile("floor_forest", "#315843", [
        ((1, 2, 3, 3), "#46714c"), ((7, 5, 9, 6), "#254936"),
        ((15, 2, 16, 3), "#57805a"), ((12, 14, 13, 15), "#244734"),
        ((4, 16, 5, 17), "#548058"), ((17, 11, 18, 12), "#244734"),
    ])
    tile("road_forest", "#92734e", [
        ((0, 2, 19, 3), "#aa885a"), ((0, 17, 19, 18), "#71553e"),
        ((4, 7, 5, 8), "#bd9963"), ((14, 12, 16, 13), "#72553d"),
        ((8, 15, 10, 15), "#bd9963"), ((17, 5, 18, 6), "#72553d"),
    ])
    tile("floor_camp", "#51453a", [
        ((2, 4, 3, 5), "#685444"), ((13, 3, 15, 4), "#40372f"),
        ((6, 13, 7, 14), "#6f5845"), ((16, 16, 17, 17), "#40372f"),
        ((9, 7, 10, 7), "#84654a"), ((1, 15, 2, 15), "#735845"),
    ])
    tile("road_camp", "#896446", [
        ((0, 1, 19, 2), "#9d7851"), ((0, 17, 19, 18), "#694a38"),
        ((3, 6, 5, 7), "#aa8558"), ((13, 12, 15, 13), "#694a38"),
        ((8, 15, 9, 16), "#b28b59"), ((17, 4, 18, 5), "#694a38"),
    ])
    tile("wall_town", "#4d514b", [
        ((0, 1, 19, 3), "#69665b"), ((1, 4, 18, 5), "#8b795e"),
        ((0, 6, 19, 7), "#403f3c"), ((3, 3, 4, 5), "#403f3c"),
        ((13, 3, 14, 5), "#403f3c"), ((6, 9, 7, 10), "#77705f"),
    ])
    tile("wall_forest", "#263f32", [
        ((2, 0, 8, 5), "#355d3f"), ((0, 2, 4, 7), "#416b47"),
        ((11, 1, 18, 6), "#3d6844"), ((14, 6, 17, 8), "#264a36"),
        ((8, 8, 10, 19), "#624a37"), ((9, 10, 11, 19), "#805d3e"),
        ((3, 13, 5, 17), "#31543c"),
    ])
    tile("wall_camp", "#3d3029", [
        ((0, 1, 19, 4), "#6f4933"), ((0, 5, 19, 7), "#8c5b3b"),
        ((2, 7, 4, 19), "#68452f"), ((8, 7, 10, 19), "#8a5937"),
        ((14, 7, 16, 19), "#68452f"), ((18, 7, 19, 19), "#8a5937"),
        ((1, 4, 3, 5), "#c0844d"), ((12, 4, 14, 5), "#c0844d"),
    ])
    tile("wall", "#3a403d", [((0, 1, 19, 3), "#59605a"), ((0, 6, 19, 7), "#262d2c")])
    tile("door", "#755039", [
        ((1, 2, 18, 4), "#a36a43"), ((2, 5, 3, 17), "#b57a49"),
        ((16, 5, 17, 17), "#5b3c30"), ((4, 16, 15, 18), "#422f29"),
        ((10, 9, 11, 10), "#e0b56e"),
    ])
    tile("brush", "#2f563f", [
        ((1, 7, 3, 17), "#639354"), ((4, 4, 5, 16), "#487a49"),
        ((8, 2, 9, 17), "#76a457"), ((12, 5, 13, 18), "#4a7d48"),
        ((16, 3, 17, 17), "#78a758"), ((0, 16, 19, 18), "#274936"),
    ])
    tile("low", "#665546", [
        ((2, 10, 5, 15), "#87735a"), ((5, 7, 12, 16), "#8f7a5e"),
        ((11, 9, 17, 16), "#76624e"), ((4, 6, 8, 9), "#b09a73"),
        ((13, 7, 15, 10), "#a38b67"), ((1, 15, 18, 17), "#493d36"),
    ])


def actors():
    def player(d):
        d.rectangle((6, 4, 12, 8), fill="#f1c38d")
        d.rectangle((5, 8, 13, 14), fill="#328078")
        d.rectangle((4, 10, 6, 13), fill="#9de0c1")
        d.rectangle((13, 8, 15, 13), fill="#24505a")
        d.rectangle((7, 14, 9, 17), fill="#c0885b")
        d.rectangle((11, 14, 13, 17), fill="#c0885b")
        d.rectangle((3, 16, 14, 18), fill="#17272b")
        d.rectangle((14, 6, 15, 15), fill="#d9e6c6")
        d.point((10, 6), fill="#17272b")
    def sentry(d):
        d.rectangle((6, 3, 13, 6), fill="#a94b4d")
        d.rectangle((5, 6, 14, 13), fill="#cb6259")
        d.rectangle((7, 4, 11, 8), fill="#efc18a")
        d.rectangle((6, 13, 9, 17), fill="#44333a")
        d.rectangle((11, 13, 14, 17), fill="#44333a")
        d.rectangle((3, 16, 15, 18), fill="#1e2428")
        d.rectangle((15, 4, 16, 16), fill="#dfbb76")
        d.rectangle((14, 3, 17, 4), fill="#dfbb76")
    def raider(d):
        d.rectangle((6, 3, 13, 6), fill="#49332d")
        d.rectangle((7, 5, 12, 9), fill="#d39a67")
        d.rectangle((5, 8, 14, 14), fill="#af5f45")
        d.rectangle((4, 11, 6, 14), fill="#713d38")
        d.rectangle((7, 14, 9, 17), fill="#403234")
        d.rectangle((11, 14, 13, 17), fill="#403234")
        d.rectangle((3, 16, 14, 18), fill="#1e2428")
        d.rectangle((14, 8, 16, 14), fill="#d6d0a0")
    def chief(d):
        d.rectangle((5, 1, 14, 4), fill="#d6aa55")
        d.rectangle((7, 4, 12, 8), fill="#efbe83")
        d.rectangle((4, 8, 15, 15), fill="#8f4c66")
        d.rectangle((2, 10, 5, 14), fill="#c06c60")
        d.rectangle((6, 15, 9, 18), fill="#473346")
        d.rectangle((11, 15, 14, 18), fill="#473346")
        d.rectangle((2, 17, 16, 19), fill="#1e2428")
        d.rectangle((14, 6, 17, 8), fill="#d6aa55")
    def trainer(d):
        d.rectangle((6, 3, 13, 7), fill="#e9c184")
        d.rectangle((5, 7, 14, 14), fill="#d1a34e")
        d.rectangle((7, 14, 9, 17), fill="#624d3d")
        d.rectangle((11, 14, 13, 17), fill="#624d3d")
        d.rectangle((3, 16, 15, 18), fill="#1e2428")
        d.rectangle((14, 9, 17, 10), fill="#e9d9a1")
    for name, fn in [("player", player), ("sentry", sentry), ("raider", raider), ("chief", chief), ("trainer", trainer)]:
        sprite(name, fn)


def sites():
    def frame(d):
        d.rectangle((2, 3, 17, 17), outline="#f0cc72")
        d.rectangle((3, 4, 16, 16), outline="#8a5c44")
        d.rectangle((1, 16, 18, 18), fill="#1c2827")
    def hall(d):
        frame(d); d.rectangle((5, 7, 14, 16), fill="#3b6f72"); d.polygon([(4, 7), (10, 3), (16, 7)], fill="#d08a54"); d.rectangle((8, 11, 11, 16), fill="#e0b05e")
    def board(d):
        frame(d); d.rectangle((4, 5, 15, 11), fill="#e8d39b"); d.rectangle((9, 11, 10, 17), fill="#9b6944"); d.rectangle((6, 7, 13, 8), fill="#754d3d")
    def shop(d):
        frame(d); d.rectangle((4, 9, 15, 16), fill="#6b4b4d"); d.rectangle((3, 6, 16, 10), fill="#d4a050"); d.rectangle((5, 6, 7, 10), fill="#4f7d78"); d.rectangle((11, 6, 13, 10), fill="#4f7d78")
    def inn(d):
        frame(d); d.rectangle((4, 8, 15, 16), fill="#715348"); d.polygon([(3, 8), (10, 4), (16, 8)], fill="#b56e55"); d.rectangle((8, 11, 11, 16), fill="#e4bb6d"); d.rectangle((14, 5, 16, 7), fill="#ffd979")
    def travel(d):
        frame(d); d.rectangle((5, 5, 7, 16), fill="#9d704a"); d.rectangle((13, 5, 15, 16), fill="#9d704a"); d.polygon([(7, 8), (13, 8), (13, 5), (17, 10), (13, 15), (13, 12), (7, 12)], fill="#e8c76e")
    def evidence(d):
        frame(d); d.rectangle((5, 6, 15, 14), fill="#e6d09b"); d.rectangle((6, 8, 14, 9), fill="#9a6b4a"); d.rectangle((6, 11, 12, 12), fill="#9a6b4a"); d.rectangle((14, 5, 16, 7), fill="#d77b61")
    def cache(d):
        frame(d); d.rectangle((4, 9, 16, 16), fill="#8d5c3d"); d.rectangle((4, 7, 16, 11), fill="#b67845"); d.rectangle((9, 9, 11, 12), fill="#e5ca6f"); d.rectangle((6, 6, 8, 8), fill="#d49b53")
    for name, fn in [("site_hall", hall), ("site_board", board), ("site_shop", shop), ("site_inn", inn), ("site_travel", travel), ("site_evidence", evidence), ("site_cache", cache)]:
        sprite(name, fn)
    sprite("site", frame)


if __name__ == "__main__":
    terrain()
    actors()
    sites()
    print(f"generated {len(list(OUT.glob('*.png')))} placeholder textures in {OUT}")

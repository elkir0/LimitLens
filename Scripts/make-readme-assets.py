#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "assets"
OUT.mkdir(parents=True, exist_ok=True)

FONT = "/System/Library/Fonts/SFNS.ttf"
FONT_BOLD = "/System/Library/Fonts/SFNSRounded.ttf"


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    path = FONT_BOLD if bold else FONT
    return ImageFont.truetype(path, size=size)


def rounded(draw: ImageDraw.ImageDraw, box, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def shadowed_panel(base: Image.Image, box, radius=28, fill=(17, 66, 104, 232)):
    x0, y0, x1, y1 = box
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle((x0, y0, x1, y1), radius=radius, fill=(0, 0, 0, 120))
    layer = layer.filter(ImageFilter.GaussianBlur(24))
    base.alpha_composite(layer, (0, 10))
    panel = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(panel)
    d.rounded_rectangle((x0, y0, x1, y1), radius=radius, fill=fill, outline=(144, 204, 246, 190), width=2)
    base.alpha_composite(panel)


def gradient(size, top=(40, 137, 191), bottom=(3, 60, 101)):
    w, h = size
    img = Image.new("RGBA", size)
    px = img.load()
    for y in range(h):
        t = y / max(h - 1, 1)
        r = int(top[0] * (1 - t) + bottom[0] * t)
        g = int(top[1] * (1 - t) + bottom[1] * t)
        b = int(top[2] * (1 - t) + bottom[2] * t)
        for x in range(w):
            px[x, y] = (r, g, b, 255)
    return img


def text(draw, xy, value, size, fill=(245, 250, 255, 255), bold=False):
    draw.text(xy, value, font=font(size, bold), fill=fill)


def progress(draw, xy, size, percent, color):
    x, y = xy
    w, h = size
    rounded(draw, (x, y, x + w, y + h), h // 2, (6, 30, 50, 80))
    rounded(draw, (x, y, x + int(w * percent), y + h), h // 2, color)


def pill(draw, box, title, value):
    rounded(draw, box, 12, (0, 0, 0, 42))
    x0, y0, _, _ = box
    text(draw, (x0 + 12, y0 + 8), title.upper(), 14, (184, 209, 229, 255), True)
    text(draw, (x0 + 12, y0 + 31), value, 20, bold=True)


def provider_card(draw, box, name, summary, color, limits, metrics):
    x0, y0, x1, y1 = box
    rounded(draw, box, 16, (64, 126, 170, 255), (124, 181, 220, 255), 2)
    draw.ellipse((x0 + 24, y0 + 28, x0 + 39, y0 + 43), fill=color)
    text(draw, (x0 + 54, y0 + 21), name, 30, bold=True)
    tw = draw.textlength(summary, font=font(22, True))
    text(draw, (x1 - 28 - tw, y0 + 25), summary, 22, color, True)

    row_y = y0 + 80
    for label, value, detail, pct in limits:
        rounded(draw, (x0 + 24, row_y, x1 - 24, row_y + 82), 12, (37, 93, 135, 255))
        text(draw, (x0 + 42, row_y + 12), label, 19, bold=True)
        text(draw, (x1 - 122, row_y + 12), value, 19, color, True)
        progress(draw, (x0 + 42, row_y + 44), (x1 - x0 - 84, 10), pct, color)
        text(draw, (x0 + 42, row_y + 59), detail, 15, (185, 212, 232, 255))
        row_y += 94

    if metrics:
        metric_w = (x1 - x0 - 64) // len(metrics)
        mx = x0 + 24
        metric_y = max(row_y + 4, y1 - 76)
        for title, value in metrics:
            pill(draw, (mx, metric_y, mx + metric_w - 8, metric_y + 58), title, value)
            mx += metric_w


def app_demo():
    img = gradient((1600, 1100))
    draw = ImageDraw.Draw(img)

    rounded(draw, (0, 0, 1600, 88), 0, (50, 155, 214, 255))
    icons = ["●", "○", "◖", "⌘", "◆", "△", "▣", "⌕"]
    x = 210
    for icon in icons:
        text(draw, (x, 26), icon, 34, (235, 248, 255, 235), True)
        x += 95

    shadowed_panel(img, (470, 118, 1320, 970), radius=36)
    draw = ImageDraw.Draw(img)
    text(draw, (520, 164), "LimitLens", 52, bold=True)
    text(draw, (520, 220), "Suivi local des quotas pour outils IA de code", 26, (190, 215, 235, 255), True)

    provider_card(
        draw,
        (520, 290, 1270, 650),
        "Claude Code",
        "94% restant",
        (75, 213, 126, 255),
        [
            ("Session courante", "94% restant", "Fenêtre 5h · réinit. 12:50", 0.94),
            ("Semaine courante", "55% restant", "Fenêtre 1 sem. · réinit. ven. 22/05 22:00", 0.55),
        ],
        [("Abonnement", "Max"), ("Source", "OAuth")],
    )
    provider_card(
        draw,
        (520, 680, 1270, 930),
        "Codex",
        "68% restant",
        (249, 188, 72, 255),
        [
            ("Session courante", "68% restant", "Limite locale · réinit. 13:15", 0.68),
        ],
        [("Extra", "Disponible"), ("Source", "local")],
    )
    text(draw, (560, 1020), "Captures de démonstration · données fictives", 18, (187, 214, 234, 210))
    img.save(OUT / "limitlens-app-demo.png")


def widget_card(draw, box, title, big, color, rows, footer="Mis à jour à 09:42"):
    x0, y0, x1, y1 = box
    rounded(draw, box, 34, (238, 247, 255, 242), (255, 255, 255, 190), 2)
    text(draw, (x0 + 26, y0 + 22), title, 26, (28, 58, 82, 255), True)
    text(draw, (x0 + 26, y0 + 72), big, 58, color, True)
    yy = y0 + 142
    for label, pct in rows:
        text(draw, (x0 + 26, yy), label, 19, (50, 75, 96, 255), True)
        progress(draw, (x0 + 26, yy + 30), (x1 - x0 - 52, 10), pct, color)
        yy += 52
    text(draw, (x0 + 26, y1 - 42), footer, 17, (91, 118, 138, 255), False)


def widgets_demo():
    img = gradient((1600, 1000), top=(34, 129, 190), bottom=(5, 52, 86))
    draw = ImageDraw.Draw(img)
    text(draw, (90, 82), "Widgets LimitLens", 62, bold=True)
    text(draw, (92, 152), "Formats Claude, OpenAI et vue d’ensemble · données fictives", 26, (198, 223, 240, 255), True)

    widget_card(draw, (110, 260, 390, 540), "OpenAI", "68%", (249, 188, 72, 255), [("Session", 0.68)])
    widget_card(draw, (430, 260, 880, 540), "Claude Code", "94% restant", (52, 188, 96, 255), [("Session courante", 0.94), ("Semaine courante", 0.55)])
    widget_card(
        draw,
        (920, 260, 1490, 820),
        "LimitLens",
        "68%",
        (249, 188, 72, 255),
        [("OpenAI · 68% restant", 0.68), ("Claude · 94% restant", 0.94), ("Semaine Claude · 55% restant", 0.55)],
    )
    text(draw, (112, 910), "Captures de démonstration · aucune donnée réelle incluse", 20, (198, 223, 240, 220), True)
    img.save(OUT / "limitlens-widgets-demo.png")


if __name__ == "__main__":
    app_demo()
    widgets_demo()
    print(OUT / "limitlens-app-demo.png")
    print(OUT / "limitlens-widgets-demo.png")

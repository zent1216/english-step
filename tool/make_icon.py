"""앱 아이콘 생성: 책(펼친 책) + 영어(A) + 입 모양(입술) + 영상 재생(말풍선 속 재생 버튼).

python3 tool/make_icon.py  →  안드로이드 런처 아이콘(일반 + 적응형)과 웹 아이콘을 다시 만든다.
"""
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = 1024  # 작업 해상도(1024 = 아이콘 한 변)
SS = 3    # 계단 현상 줄이기용 배율

BLUE = (62, 91, 242)
VIOLET = (124, 77, 232)
CORAL = (242, 100, 62)
CORAL_DARK = (200, 70, 40)
INK = (36, 52, 140)
WHITE = (255, 255, 255)
PAGE_SHADE = (226, 231, 255)


def bezier(p0, p1, p2, p3, steps=40):
    """3차 베지어 곡선 위의 점들."""
    pts = []
    for i in range(steps + 1):
        t = i / steps
        a, b, c, d = (1 - t) ** 3, 3 * (1 - t) ** 2 * t, 3 * (1 - t) * t ** 2, t ** 3
        pts.append((a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0], a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]))
    return pts


def gradient(size):
    w = h = size
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        for x in range(w):
            t = (x + y) / (2 * (w - 1))
            px[x, y] = tuple(int(BLUE[i] + (VIOLET[i] - BLUE[i]) * t) for i in range(3))
    return img


def background(size):
    g = gradient(64).resize((size, size), Image.BICUBIC)
    return g.convert("RGBA")


def foreground(size, scale=1.0):
    """투명 배경 위 그림. scale<1이면 가운데로 줄여 적응형 아이콘 안전 영역에 맞춘다."""
    n = size * SS
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def P(x, y):  # 1024 기준 좌표 → 실제 좌표(가운데 기준 축소)
        c = 512
        return (int((c + (x - c) * scale) * n / S), int((c + (y - c) * scale) * n / S))

    def R(v):
        return int(v * scale * n / S)

    # ---- 펼친 책 ----
    shadow = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.polygon([P(186, 640), P(512, 690), P(838, 640), P(838, 838), P(512, 888), P(186, 838)],
               fill=(20, 20, 80, 90))
    shadow = shadow.filter(ImageFilter.GaussianBlur(R(18)))
    img.alpha_composite(shadow)
    # 왼쪽 페이지: 바깥쪽이 위로 휘고 가운데(제본)로 내려가는 곡선
    def page(sign):
        def X(x):  # sign=-1 왼쪽, +1 오른쪽 (1024 기준 x를 가운데 대칭)
            return 512 + sign * (512 - x)
        top = bezier((X(512), 650), (X(430), 585), (X(300), 570), (X(176), 600))
        bottom = bezier((X(176), 828), (X(300), 800), (X(430), 812), (X(512), 872))
        return [P(x, y) for (x, y) in top + bottom]
    def thickness(sign):
        def X(x):
            return 512 + sign * (512 - x)
        upper = bezier((X(176), 828), (X(300), 800), (X(430), 812), (X(512), 872))
        lower = bezier((X(512), 892), (X(430), 834), (X(300), 822), (X(176), 850))
        return [P(x, y) for (x, y) in upper + lower]
    for sg in (-1, 1):
        d.polygon(thickness(sg), fill=PAGE_SHADE)
        d.polygon(page(sg), fill=WHITE)
    # 가운데 접힌 선
    d.line([P(512, 650), P(512, 872)], fill=PAGE_SHADE, width=R(8))

    # ---- 왼쪽 페이지: 영어 "A" ----
    font_path = os.path.join(ROOT, "assets/fonts/Pretendard-Bold.otf")
    f = ImageFont.truetype(font_path, R(200))
    tx, ty = P(338, 712)
    d.text((tx, ty), "A", font=f, fill=INK, anchor="mm")

    # ---- 오른쪽 페이지: 입 모양(입술) ----
    def lip(x, y):  # 입술 중심(686,722) 기준 상대 좌표(단위: 1024 기준 px)
        return P(686 + x, 722 + y)
    W = 100  # 입 반폭
    upper = (bezier((-W, 0), (-W * 0.75, -26), (-W * 0.55, -62), (-W * 0.28, -60)) +
             bezier((-W * 0.28, -60), (-W * 0.12, -58), (-W * 0.05, -44), (0, -42)) +
             bezier((0, -42), (W * 0.05, -44), (W * 0.12, -58), (W * 0.28, -60)) +
             bezier((W * 0.28, -60), (W * 0.55, -62), (W * 0.75, -26), (W, 0)))
    mouth_line = bezier((W, 0), (W * 0.45, 10), (-W * 0.45, 10), (-W, 0))
    lower = bezier((-W, 0), (-W * 0.7, 70), (W * 0.7, 70), (W, 0))
    d.polygon([lip(x, y) for (x, y) in lower], fill=CORAL)
    d.polygon([lip(x, y) for (x, y) in upper + mouth_line], fill=CORAL_DARK)
    # 아랫입술 하이라이트
    d.ellipse([*lip(-34, 22), *lip(26, 40)], fill=(255, 160, 130))

    # ---- 위: 재생 버튼 말풍선(영상/노래) ----
    bx0, by0 = P(318, 196)
    bx1, by1 = P(706, 486)
    bub_shadow = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    bsd = ImageDraw.Draw(bub_shadow)
    bsd.rounded_rectangle([bx0, by0 + R(16), bx1, by1 + R(16)], radius=R(70), fill=(20, 20, 80, 80))
    bub_shadow = bub_shadow.filter(ImageFilter.GaussianBlur(R(16)))
    img.alpha_composite(bub_shadow)
    d.rounded_rectangle([bx0, by0, bx1, by1], radius=R(70), fill=CORAL)
    # 말풍선 꼬리(오른쪽 페이지의 입 쪽을 가리킴)
    d.polygon([P(570, 470), P(660, 470), P(660, 580)], fill=CORAL)
    # 재생 삼각형
    d.polygon([P(462, 262), P(462, 420), P(590, 341)], fill=WHITE)

    return img.resize((size, size), Image.LANCZOS)


def full_icon(size, rounded=True):
    bg = background(size)
    fg = foreground(size)
    bg.alpha_composite(fg)
    if rounded:  # 구형 런처용: 둥근 사각형으로 잘라낸다
        mask = Image.new("L", (size * SS, size * SS), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, size * SS - 1, size * SS - 1], radius=int(size * SS * 0.22), fill=255)
        mask = mask.resize((size, size), Image.LANCZOS)
        out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        out.paste(bg, (0, 0), mask)
        return out
    return bg


def main():
    res = os.path.join(ROOT, "android/app/src/main/res")
    dens = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
    for name, k in dens.items():
        d = os.path.join(res, f"mipmap-{name}")
        os.makedirs(d, exist_ok=True)
        full_icon(int(48 * k)).save(os.path.join(d, "ic_launcher.png"))
        # 적응형 아이콘: 108dp 캔버스, 그림은 가운데 66dp 안전 영역에 들어가게 줄인다
        a = int(108 * k)
        foreground(a, scale=0.62).save(os.path.join(d, "ic_launcher_foreground.png"))
        background(a).save(os.path.join(d, "ic_launcher_background.png"))
    any_dir = os.path.join(res, "mipmap-anydpi-v26")
    os.makedirs(any_dir, exist_ok=True)
    with open(os.path.join(any_dir, "ic_launcher.xml"), "w") as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n'
                '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
                '    <background android:drawable="@mipmap/ic_launcher_background"/>\n'
                '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
                '    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>\n'
                '</adaptive-icon>\n')
    # 웹(미리보기용)
    web = os.path.join(ROOT, "web")
    if os.path.isdir(web):
        full_icon(32, rounded=False).save(os.path.join(web, "favicon.png"))
        for s in (192, 512):
            full_icon(s, rounded=False).save(os.path.join(web, "icons", f"Icon-{s}.png"))
            full_icon(s, rounded=False).save(os.path.join(web, "icons", f"Icon-maskable-{s}.png"))
    # 미리보기
    if len(sys.argv) > 1:
        out = sys.argv[1]
        prev = Image.new("RGBA", (1024 + 360, 1024), (244, 245, 248, 255))
        prev.alpha_composite(full_icon(1024), (0, 0))
        y = 40
        for s in (192, 96, 48):
            prev.alpha_composite(full_icon(s), (1100, y))
            y += s + 40
        prev.save(out)


if __name__ == "__main__":
    main()

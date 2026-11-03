#!/usr/bin/env python3
"""Crop the RARS screenshots in lab/images/ into the figures used by the report.

Each figure keeps only what the text discusses: the breakpoint line in the
Text Segment, the relevant rows of the Registers panel, and the relevant
cells of the Data Segment (boxed in red). Output goes to lab/images/report/.
All screenshots are 1600x1100 with the same RARS window layout.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

IMG = Path(__file__).resolve().parent.parent / "images"
OUT = IMG / "report"
FONT = ImageFont.truetype("/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc", 20)
RED = (220, 0, 0)
ROW = 15

# Registers panel: header row, then zero..t6 and pc, 15 px each.
REG_NAMES = ["zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2", "s0", "s1",
             "a0", "a1", "a2", "a3", "a4", "a5", "a6", "a7",
             "s2", "s3", "s4", "s5", "s6", "s7", "s8", "s9", "s10", "s11",
             "t3", "t4", "t5", "t6", "pc"]
REG_HEAD_Y, REG_ROW0_Y = 95, 117
REG_COLS = [(1180, 1326), (1442, 1598)]          # Name, Value

# Text Segment: header row and the yellow highlighted (current) line.
TEXT_HEAD_Y = 125
TEXT_COLS = [(150, 330), (508, 1150)]            # Address, Basic + Source

# Data Segment: header row, then rows of 8 words.
DATA_HEAD_Y, DATA_ROW0_Y = 473, 488
DATA_COLX = [10, 135, 262, 388, 514, 640, 766, 892, 1020, 1146]  # Address, +0 .. +1c


def hcat(parts, gap=0, bg=(255, 255, 255)):
    w = sum(p.width for p in parts) + gap * (len(parts) - 1)
    h = max(p.height for p in parts)
    out = Image.new("RGB", (w, h), bg)
    x = 0
    for p in parts:
        out.paste(p, (x, 0))
        x += p.width + gap
    return out


def vcat(parts, gap=0, bg=(255, 255, 255)):
    w = max(p.width for p in parts)
    h = sum(p.height for p in parts) + gap * (len(parts) - 1)
    out = Image.new("RGB", (w, h), bg)
    y = 0
    for p in parts:
        out.paste(p, (0, y))
        y += p.height + gap
    return out


def columns(im, y0, y1, cols):
    return hcat([im.crop((a, y0, b, y1)) for a, b in cols], gap=2, bg=(160, 160, 160))


def label(text, width):
    out = Image.new("RGB", (width, 30), "white")
    ImageDraw.Draw(out).text((2, 3), text, fill=(0, 0, 0), font=FONT)
    return out


def text_rows(im, before=3):
    """Header + `before` lines + the highlighted line of the Text Segment."""
    ys = [y for y in range(140, 440) if im.getpixel((600, y))[0] > 230 and im.getpixel((600, y))[2] < 170]
    top, bottom = ys[0] - 1, ys[-1] + 2
    head = columns(im, TEXT_HEAD_Y, TEXT_HEAD_Y + ROW, TEXT_COLS)
    body = columns(im, top - ROW * before, bottom, TEXT_COLS)
    return vcat([head, body])


def reg_rows(im, names):
    """Header + the given registers (in panel order); a grey bar marks skipped rows."""
    idx = sorted(REG_NAMES.index(n) for n in names)
    parts = [columns(im, REG_HEAD_Y, REG_HEAD_Y + 22, REG_COLS)]
    prev = None
    for i in idx:
        if prev is not None and i != prev + 1:
            parts.append(Image.new("RGB", (parts[0].width, 4), (160, 160, 160)))
        y = REG_ROW0_Y + ROW * i
        parts.append(columns(im, y, y + ROW, REG_COLS))
        prev = i
    return vcat(parts)


def data_cells(im, base, cells):
    """Header + rows holding `cells` (word addresses), showing only the needed columns, cells boxed."""
    rows = sorted({(a - base) // 32 for a in cells})
    cols = sorted({((a - base) % 32) // 4 for a in cells})
    xcols = [(DATA_COLX[0], DATA_COLX[1])] + [(DATA_COLX[c + 1], DATA_COLX[c + 2]) for c in cols]
    head = columns(im, DATA_HEAD_Y, DATA_HEAD_Y + ROW, xcols)
    body = []
    for r in rows:
        y = DATA_ROW0_Y + ROW * r
        line = columns(im, y, y + ROW, xcols)
        d = ImageDraw.Draw(line)
        for a in cells:
            if (a - base) // 32 == r:
                k = cols.index(((a - base) % 32) // 4) + 1
                x0 = sum(b - a_ + 2 for a_, b in xcols[:k])
                x1 = x0 + xcols[k][1] - xcols[k][0] - 1
                d.rectangle((x0, 0, x1, ROW - 1), outline=RED, width=2)
        body.append(line)
    return vcat([head] + body)


def shot(name):
    return Image.open(IMG / f"{name}.png").convert("RGB")


def save(img, name):
    OUT.mkdir(exist_ok=True)
    img.save(OUT / f"{name}.png")
    print(name, img.size)


def run_io(name, last_line_y):
    """Text area of the Run I/O tab, trimmed below the last line of output."""
    im = shot(name).crop((83, 286, 1165, last_line_y))
    g = im.convert("L")
    rows = [y for y in range(g.height) if g.crop((0, y, g.width, y + 1)).getextrema()[0] < 120]
    return im.crop((0, max(rows[0] - 4, 0), im.width, rows[-1] + 5))


def main():
    # Run I/O output of one case (the text area of the Run I/O tab).
    for case in ("02", "08", "10"):
        save(run_io(f"02-case-{case}-run-io", 776), f"run-io-case-{case}")

    # Instruction Counter (case 8): the counter dialog and the first lines of Run I/O.
    im = shot("01-instruction-counter")
    save(vcat([im.crop((563, 400, 1037, 696)), im.crop((83, 836, 1165, 1002))], gap=8), "instruction-counter")

    # Registers before / after div1024, and after mul1024.
    regs = ["sp", "s0", "s1", "s2", "s3", "s4", "a0", "pc"]
    blocks = []
    for f, t in (("03c-after-mul", "mul1024 返回后"), ("03a-before-div", "调用 div1024 前"), ("03b-after-div", "div1024 返回后")):
        r = reg_rows(shot(f), regs)
        blocks.append(vcat([label(t, r.width), r]))
    save(hcat(blocks, gap=24), "regs-call")

    # add1024 / sub1024: breakpoint line + registers at the first two stops.
    for pre, title in (("04", "add-carry"), ("05", "sub-borrow")):
        a, b = shot(f"{pre}a-{title}-1"), shot(f"{pre}b-{title}-2")
        rows = ["a0", "t1", "t2", "t3", "t4", "t5", "pc"]
        ra, rb = reg_rows(a, rows), reg_rows(b, rows)
        pair = hcat([vcat([label("第 1 次停下（i = 0）", ra.width), ra]),
                     vcat([label("第 2 次停下（i = 1）", rb.width), rb])], gap=24)
        save(vcat([text_rows(a, before=5), pair], gap=12), title)

    # mul1024: T[31] / T[32] on the stack (sp = 0x7fffeee0) and s2 = i.
    a = shot("06a-mul-high-1")
    blocks = [text_rows(a, before=4)]
    for f, t in (("06a-mul-high-1", "第 1 次停下（i = 0 结束）"), ("06b-mul-high-2", "第 2 次停下（i = 1 结束）")):
        im = shot(f)
        r = reg_rows(im, ["sp", "s2"])
        d = data_cells(im, 0x7FFFEEE0, [0x7FFFEF5C, 0x7FFFEF60])
        body = hcat([r, d], gap=24)
        blocks.append(vcat([label(t, body.width), body]))
    save(vcat(blocks, gap=12), "mul-high")

    # div1024: s4 = i, t3/t4 = R[j]/B[j] of the last compare, Q[0] and R[0] in .data.
    a = shot("07a-div-1")
    blocks = [text_rows(a, before=6)]
    for f, t in (("07a-div-1", "第 1 次停下"), ("07b-div-2", "第 2 次停下"), ("07c-div-3", "第 3 次停下")):
        im = shot(f)
        r = reg_rows(im, ["sp", "s4", "t3", "t4"])
        d = data_cells(im, 0x10010200, [0x10010308, 0x10010388])
        body = hcat([r, d], gap=24)
        blocks.append(vcat([label(t, body.width), body]))
    save(vcat(blocks, gap=12), "div-steps")


if __name__ == "__main__":
    main()

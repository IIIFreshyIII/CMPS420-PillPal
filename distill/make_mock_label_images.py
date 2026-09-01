"""
Render mock prescription-label IMAGES (not just text) to test the --images path
of build_real_testset.py end to end: image -> OCR -> annotate -> evaluate.

Fake data (from label_generator), rendered to a JPG, then knocked around to look
like a phone photo: rotation, blur, sensor noise, uneven lighting, low
resolution, JPEG artifacts.

    python make_mock_label_images.py --n 18 --out mock_labels/

Writes mock_labels/label_00.jpg ... and mock_labels/ANSWERS.md (the true field
values, so you can check your annotations).

CAVEAT: the underlying TEXT is still template-generated, so these mainly exercise
OCR robustness + the tooling. For the evaluation number that actually matters you
still need real label photos (or physically photograph printouts of these).
"""

from __future__ import annotations

import argparse
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

from label_generator import generate

_FONTS = [
    "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
]


def _font(size: int):
    for f in _FONTS:
        if Path(f).exists():
            return ImageFont.truetype(f, size)
    return ImageFont.load_default()


def render(text: str, seed: int) -> Image.Image:
    rng = random.Random(seed)
    size = rng.randint(21, 27)
    font = _font(size)
    pad = rng.randint(28, 55)
    lh = int(size * rng.uniform(1.45, 1.75))

    lines = text.split("\n")
    tmp = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    width = max((tmp.textlength(ln, font=font) for ln in lines), default=200)
    W = int(width + pad * 2)
    H = int(lh * len(lines) + pad * 2)

    bg = rng.randint(238, 255)
    img = Image.new("RGB", (W, H), (bg, bg, bg - rng.randint(0, 6)))
    d = ImageDraw.Draw(img)
    ink = rng.randint(0, 45)
    for i, ln in enumerate(lines):
        jitter = rng.randint(-2, 2)
        d.text((pad + jitter, pad + i * lh), ln, fill=(ink, ink, ink + rng.randint(0, 10)), font=font)

    # --- uneven lighting: multiply by a soft gradient ---
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    cx, cy = rng.uniform(0, W), rng.uniform(0, H)
    dist = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    shade = 1.0 - (dist / dist.max()) * rng.uniform(0.15, 0.4)
    arr = np.asarray(img).astype(np.float32) * shade[..., None]

    # --- sensor noise ---
    arr += np.random.default_rng(seed).normal(0, rng.uniform(4, 11), arr.shape)
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))

    # --- slight skew + rotation (like holding the phone off-square) ---
    shear = rng.uniform(-0.06, 0.06)
    img = img.transform(img.size, Image.AFFINE, (1, shear, 0, rng.uniform(-0.03, 0.03), 1, 0),
                        resample=Image.BICUBIC, fillcolor=(bg, bg, bg))
    img = img.rotate(rng.uniform(-3.5, 3.5), expand=True, fillcolor=(bg, bg, bg),
                     resample=Image.BICUBIC)

    # --- focus blur + resolution loss ---
    img = img.filter(ImageFilter.GaussianBlur(rng.uniform(0.4, 1.2)))
    scale = rng.uniform(0.45, 0.7)
    img = img.resize((int(img.width * scale), int(img.height * scale))).resize(
        (int(img.width), int(img.height)))
    return img


def answers_row(text: str, spans) -> dict:
    vals: dict[str, list[str]] = {}
    for s, e, lab in spans:
        vals.setdefault(lab, []).append(text[s:e])
    return vals


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=18)
    ap.add_argument("--out", default="mock_labels")
    ap.add_argument("--seed-start", type=int, default=5000)
    args = ap.parse_args()

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    ans = ["# Mock label answers", "",
           "True field values for each image. Check your annotations against this.",
           "(These are template-generated — the real test set still needs real photos.)", ""]
    for i in range(args.n):
        seed = args.seed_start + i
        split = "train" if i % 2 else "unseen"
        text, spans = generate(seed=seed, split=split)
        img = render(text, seed)
        name = f"label_{i:02d}.jpg"
        img.save(out / name, quality=random.Random(seed).randint(52, 82))
        v = answers_row(text, spans)
        ans.append(f"## {name}  ({split} vocab)")
        for lab in ("DRUG", "STRENGTH", "DOSAGE", "FORM", "ROUTE", "FREQUENCY", "DURATION"):
            got = " | ".join(dict.fromkeys(v.get(lab, []))) or "—"
            ans.append(f"- **{lab}**: {got}")
        ans.append("")
    (out / "ANSWERS.md").write_text("\n".join(ans))

    print(f"wrote {args.n} images -> {out}/  (+ ANSWERS.md)")
    print("\nNext:")
    print(f"  python build_real_testset.py --images {out}/ --out data/")
    print(f"  # edit data/real_test.draft.txt")
    print(f"  python build_real_testset.py --finalize data/real_test.draft.txt --out data/")
    print(f"  python evaluate.py --model model-run --data data/")


if __name__ == "__main__":
    main()

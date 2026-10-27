"""Generate normalized test images, pack real crops, inspect or send IMG1.

python image_tool.py generate --dots 12 2346 1356 --out cup.bin
python image_tool.py pack crop1.png crop2.png --out captured.bin
python image_tool.py inspect cup.bin
python image_tool.py send cup.bin --port COM5
"""
import argparse
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "k230"))
from image_protocol import encode_images, WIDTH, HEIGHT, CELL_BYTES


def to_rgb565(image):
    image = image.convert("RGB")
    if image.size != (WIDTH, HEIGHT):
        raise ValueError("image must already be normalized to 64x96; crop/align before packing")
    data = bytearray()
    for r, g, b in image.getdata():
        word = ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)
        data.extend([word >> 8, word & 255])
    return bytes(data)


def inspect(frame):
    if len(frame) < 9 or frame[:4] != b"IMG1" or frame[-2:] != b"\r\n":
        raise ValueError("bad image header/tail")
    count = frame[4]
    if not 1 <= count <= 16 or len(frame) != 9 + count * CELL_BYTES:
        raise ValueError("image count/length mismatch")
    check = sum(frame[4:-4]) & 65535
    if check != int.from_bytes(frame[-4:-2], "big"):
        raise ValueError("bad checksum")
    masks = []
    for cell in range(count):
        data = frame[5 + cell * CELL_BYTES:5 + (cell + 1) * CELL_BYTES]
        gray = []
        for i in range(0, len(data), 2):
            word = (data[i] << 8) | data[i+1]
            r, g, b = (word >> 11) & 31, (word >> 5) & 63, word & 31
            r, g, b = (r << 3) | (r >> 2), (g << 2) | (g >> 4), (b << 3) | (b >> 2)
            gray.append((77*r + 150*g + 29*b) >> 8)
        mask = 0
        for dot in range(6):
            cx, cy = (16 if dot < 3 else 48), 16 + (dot % 3) * 32
            dark = 0
            for y in range(cy-4, cy+5):
                for x in range(cx-4, cx+5):
                    mean = sum(gray[(y+dy)*WIDTH + x+dx] for dy in (-1, 0, 1)
                               for dx in (-1, 0, 1)) // 9
                    dark += mean < 160
            if dark >= 12:
                mask |= 1 << dot
        masks.append(mask)
    return masks


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    gen = sub.add_parser("generate")
    gen.add_argument("--dots", nargs="+", required=True)
    gen.add_argument("--out", type=Path, required=True)
    pack = sub.add_parser("pack")
    pack.add_argument("images", nargs="+", type=Path)
    pack.add_argument("--out", type=Path, required=True)
    for name in ("inspect", "send"):
        p = sub.add_parser(name)
        p.add_argument("frame", type=Path)
        if name == "send":
            p.add_argument("--port", required=True)
            p.add_argument("--baud", type=int, default=115200)
    args = parser.parse_args()
    if args.command in ("generate", "pack"):
        from PIL import Image, ImageDraw
        images = []
        if args.command == "generate":
            args.out.parent.mkdir(parents=True, exist_ok=True)
            for i, token in enumerate(args.dots):
                if token != "0" and (not token or any(c not in "123456" for c in token)
                                     or "".join(sorted(set(token))) != token):
                    raise ValueError("dots must be ascending unique 1..6, or 0")
                image = Image.new("RGB", (WIDTH, HEIGHT), "white")
                draw = ImageDraw.Draw(image)
                for c in token:
                    if c == "0": continue
                    dot = int(c)-1
                    x, y = (16 if dot < 3 else 48), 16+(dot % 3)*32
                    draw.ellipse((x-5, y-5, x+5, y+5), fill="black")
                image.save(args.out.with_name(args.out.stem + "_cell%d.png" % (i+1)))
                images.append(to_rgb565(image))
        else:
            for path in args.images:
                with Image.open(path) as image: images.append(to_rgb565(image))
        frame = encode_images(images)
        args.out.write_bytes(frame)
        print(json.dumps({"file": str(args.out), "bytes": len(frame),
                          "reference_masks": inspect(frame)}, ensure_ascii=False))
    elif args.command == "inspect":
        print(json.dumps({"reference_masks": inspect(args.frame.read_bytes())}))
    else:
        frame = args.frame.read_bytes()
        inspect(frame)
        import serial
        # Run only after the FPGA has sent hello in response to S4.
        with serial.Serial(args.port, args.baud, timeout=1, write_timeout=30) as port:
            for offset in range(0, len(frame), 128):
                chunk = frame[offset:offset+128]
                if port.write(chunk) != len(chunk): raise IOError("short UART write")
            port.flush()
            print("Sent", len(frame), "bytes; response:", port.read(5))


if __name__ == "__main__":
    main()

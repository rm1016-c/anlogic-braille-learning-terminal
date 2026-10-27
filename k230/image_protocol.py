"""IMG1 protocol shared by K230 and PC. No image-processing dependencies."""
WIDTH = 64
HEIGHT = 96
CELL_BYTES = WIDTH * HEIGHT * 2


def validate_images(images):
    if not 1 <= len(images) <= 16:
        raise ValueError("expected 1..16 normalized cell images")
    for image in images:
        if len(image) != CELL_BYTES:
            raise ValueError("each image must be 64x96 RGB565, high byte first")


def encode_images(images):
    validate_images(images)
    check = (len(images) + sum(sum(image) for image in images)) & 0xFFFF
    return (b"IMG1" + bytes([len(images)]) + b"".join(images)
            + bytes([check >> 8, check & 255, 13, 10]))


def send_images(uart, images, chunk_size=128):
    """uart.send must transmit raw bytes in order; use a blocking UART adapter.

    Supply actual normalized RGB565 cell crops, not six-bit answers. All image
    lengths are checked before starting. No newline/text encoding of pixels.
    """
    validate_images(images)
    if chunk_size < 1:
        raise ValueError("chunk_size must be positive")
    check = len(images)
    uart.send(b"IMG1" + bytes([len(images)]))
    for image in images:
        for offset in range(0, len(image), chunk_size):
            chunk = image[offset:offset + chunk_size]
            check = (check + sum(chunk)) & 0xFFFF
            uart.send(chunk)
    uart.send(bytes([check >> 8, check & 255, 13, 10]))

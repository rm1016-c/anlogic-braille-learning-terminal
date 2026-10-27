"""K230 UART adapter. uart must expose raw read() and send(bytes).

Call poll() every camera loop. On a True return, clear detector history.
Call send_braille(cells) only after an actual stable label detection.
This module handles communication; it does not extract dots from images.
"""
class FpgaLink:
    def __init__(self, uart):
        self.uart = uart
        self.mode = "object"
        self._hello_pos = 0
        self._result_sent = False
        self._last_object = None

    def poll(self):
        data = self.uart.read()
        changed = False
        if data:
            for value in data:
                if value == b"hello"[self._hello_pos]:
                    self._hello_pos += 1
                    if self._hello_pos == 5:
                        self._hello_pos = 0
                        self.mode = "braille" if self.mode == "object" else "object"
                        self._result_sent = False
                        self._last_object = None
                        changed = True
                else:
                    self._hello_pos = 1 if value == ord("h") else 0
        return changed

    def send_object(self, code):
        if self.mode != "object" or not 1 <= code <= 7:
            return False
        if code == self._last_object:
            return False
        self.uart.send(bytes([0xAA, code, 0x55]))
        self._last_object = code
        return True

    def send_braille(self, cells):
        if self.mode != "braille" or self._result_sent:
            return False
        if not 1 <= len(cells) <= 16:
            raise ValueError("expected 1..16 braille cells")
        tokens = []
        for mask in cells:
            if not isinstance(mask, int) or not 0 <= mask <= 63:
                raise ValueError("each cell must be a six-bit mask")
            tokens.append("".join(str(dot + 1) for dot in range(6)
                                  if mask & (1 << dot)) or "0")
        line = "BRL,%d,%s,END\n" % (len(tokens), ",".join(tokens))
        self.uart.send(line.encode("ascii"))
        self._result_sent = True
        return True

    def send_error(self):
        if self.mode == "braille" and not self._result_sent:
            self.uart.send(b"BRL,ERROR,END\n")

    def send_images(self, images):
        """Send actual 64x96 RGB565 crops for FPGA pixel processing."""
        if self.mode != "braille" or self._result_sent:
            return False
        from image_protocol import send_images
        send_images(self.uart, images)
        self._result_sent = True
        return True

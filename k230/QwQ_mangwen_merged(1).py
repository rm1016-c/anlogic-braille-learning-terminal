# K230 物品/颜色识别：终端打印并通过串口发送编号
# 仅使用 YOLO/摄像头、板载按键和串口；不启动 Wi-Fi、麦克风、唤醒词或 TTS。
import os
import ustruct as struct
import gc
import cv_lite
import nncase_runtime as nn
import ulab.numpy as np
import aidemo
from media.media import *
from libs.PipeLine import PipeLine
from libs.AIBase import AIBase
from libs.AI2D import Ai2d
from libs.Utils import *
from ybUtils.YbUart import YbUart
from ybUtils.YbKey import YbKey
DISPLAY_MODE = "lcd"
# YOLOv8n COCO 80类；类别顺序需与 yolov8n_224.kmodel 的训练标签一致。
LABELS = [
    "person", "bicycle", "car", "motorcycle", "airplane", "bus", "train", "truck", "boat",
    "traffic light", "fire hydrant", "stop sign", "parking meter", "bench", "bird", "cat", "dog",
    "horse", "sheep", "cow", "elephant", "bear", "zebra", "giraffe", "backpack", "umbrella",
    "handbag", "tie", "suitcase", "frisbee", "skis", "snowboard", "sports ball", "kite",
    "baseball bat", "baseball glove", "skateboard", "surfboard", "tennis racket", "bottle",
    "wine glass", "cup", "fork", "knife", "spoon", "bowl", "banana", "apple", "sandwich",
    "orange", "broccoli", "carrot", "hot dog", "pizza", "donut", "cake", "chair", "couch",
    "potted plant", "bed", "dining table", "toilet", "tv", "laptop", "mouse", "remote",
    "keyboard", "cell phone", "microwave", "oven", "toaster", "sink", "refrigerator", "book",
    "clock", "vase", "scissors", "teddy bear", "hair drier", "toothbrush"
]

RGB_SIZE = [224, 224]  # 物品/颜色/盲文共用原摄像头输入尺寸，切换时不重启管线
BRAILLE_RGB_SIZE = RGB_SIZE
DISPLAY_SIZE = [640, 480]
MODEL_SIZE = [224, 224]
MODEL_PATH = "/sdcard/kmodel/yolov8n_224.kmodel"
YOLO_CONFIDENCE_THRESHOLD = 0.15
MIN_BLOB_AREA = 35  # mangwen.py 连通域检测使用的最小面积

# 物品/颜色串口协议：二进制帧 AA 编号 55；盲文使用 BRL,...,END 换行文本帧。
CODE_NAMES = {
    1: "红色", 2: "绿色", 3: "蓝色", 4: "杯子",
    5: "苹果", 6: "橙子", 7: "鼠标", 8: "剪刀"
}
OBJECT_CODES = {41: 4, 47: 5, 49: 6, 64: 7, 76: 8}
OBJECT_NAMES = {41: "杯子", 47: "苹果", 49: "橙子", 64: "鼠标", 76: "剪刀"}
COLOR_CODES = {"红色": 1, "绿色": 2, "蓝色": 3}



def otsu_threshold(gray, width, height, step=4):
    hist = [0] * 256
    total = 0
    sum_all = 0
    for y in range(0, height, step):
        for x in range(0, width, step):
            value = int(gray[y, x])
            hist[value] += 1
            total += 1
            sum_all += value
    if total == 0:
        return 60
    sum_back = 0
    weight_back = 0
    best_var = -1
    best_t = 60
    for t in range(256):
        weight_back += hist[t]
        if weight_back == 0:
            continue
        weight_fore = total - weight_back
        if weight_fore == 0:
            break
        sum_back += t * hist[t]
        mean_back = sum_back / weight_back
        mean_fore = (sum_all - sum_back) / weight_fore
        between = weight_back * weight_fore * (mean_back - mean_fore) * (mean_back - mean_fore)
        if between > best_var:
            best_var = between
            best_t = t
    # Otsu 在纸张/背景边界明显时可能偏高，限制到合理范围避免把整片背景都当黑点。
    if best_t < 18:
        best_t = 18
    if best_t > 150:
        best_t = 150
    return int(best_t)


def core_contrast(gray, x, y, w, h):
    # 实心点中心比框外纸面暗；空心圈中心与框外纸面接近。
    x0 = x + w // 3
    x1 = x + (w * 2) // 3
    y0 = y + h // 3
    y1 = y + (h * 2) // 3
    if x1 <= x0:
        x1 = x0 + 1
    if y1 <= y0:
        y1 = y0 + 1
    center_sum = 0
    center_count = 0
    for yy in range(y0, y1, max(1, (y1 - y0) // 5)):
        for xx in range(x0, x1, max(1, (x1 - x0) // 5)):
            center_sum += int(gray[yy, xx])
            center_count += 1
    if center_count == 0:
        return 0
    center_mean = center_sum // center_count

    pad = max(2, min(w, h) // 5)
    bg_sum = 0
    bg_count = 0
    # 在候选框外侧取四条窄带，抵消整幅图亮度变化。
    for xx in range(x, x + w, max(1, w // 6)):
        for yy in (max(0, y - pad), min(height_limit(gray) - 1, y + h + pad)):
            bg_sum += int(gray[yy, xx])
            bg_count += 1
    for yy in range(y, y + h, max(1, h // 6)):
        for xx in (max(0, x - pad), min(width_limit(gray) - 1, x + w + pad)):
            bg_sum += int(gray[yy, xx])
            bg_count += 1
    if bg_count == 0:
        return 0
    return bg_sum // bg_count - center_mean


def height_limit(gray):
    return int(gray.shape[0])


def width_limit(gray):
    return int(gray.shape[1])


def cluster_1d(items, coordinate_index, tolerance):
    values = sorted(items, key=lambda item: item[coordinate_index])
    groups = []
    for item in values:
        value = item[coordinate_index]
        if not groups or value - groups[-1]["last"] > tolerance:
            groups.append({"items": [item], "last": value})
        else:
            groups[-1]["items"].append(item)
            groups[-1]["last"] = value
    centers = []
    for group in groups:
        members = group["items"]
        center = sum(item[coordinate_index] for item in members) / len(members)
        centers.append((center, members))
    return centers


def recognize(gray, width, height):
    threshold = otsu_threshold(gray, width, height)
    # 识别窗口按输入尺寸缩放；224x224 时避免沿用 640x480 的最小点尺寸而漏点。
    scale = min(width / 640.0, height / 480.0)
    min_blob_area = max(3, int(MIN_BLOB_AREA * scale * scale))
    min_mark_w = max(4, int(12 * scale))
    min_mark_h = max(6, int(16 * scale))
    # 稍微放宽分割阈值，尽量把虚线/模糊的空心点边缘连成定位框。
    # 全局 Otsu 常把灰纸背景一起纳入；降低阈值优先取墨迹/暗边缘。
    detect_threshold = max(15, threshold - 25)
    # cv_lite 返回扁平的 x,y,w,h 四元组；点心与邻近纸面的对比度负责黑/白分类。
    raw = cv_lite.grayscale_find_blobs(
        [height, width], gray, 0, detect_threshold, min_blob_area, 1)
    marks = []
    if raw:
        for i in range(0, len(raw) - 3, 4):
            x, y, w, h = int(raw[i]), int(raw[i + 1]), int(raw[i + 2]), int(raw[i + 3])
            # 盲文笔迹是较大的椭圆/不规则块；排除小噪声和大块阴影。
            if w < min_mark_w or h < min_mark_h or w > width // 6 or h > height // 4:
                continue
            aspect = w / h
            if aspect < 0.30 or aspect > 1.5:
                continue
            contrast = core_contrast(gray, x, y, w, h)
            marks.append({"x": x + w // 2, "y": y + h // 2,
                          "w": w, "h": h, "rect": (x, y, w, h),
                          "dark": contrast >= 12, "contrast": contrast})

    if len(marks) < 4:
        return threshold, marks, None

    # 用所有实心/空心标记一起估计三条横行，避免仅凭稀疏实心点分行。
    ys = sorted(p["y"] for p in marks)
    row_centers = [float(ys[len(ys) // 6]),
                   float(ys[len(ys) // 2]),
                   float(ys[(len(ys) * 5) // 6])]
    for _ in range(5):
        row_groups = [[], [], []]
        for point in marks:
            ri = min(range(3), key=lambda j: abs(point["y"] - row_centers[j]))
            row_groups[ri].append(point["y"])
        for ri in range(3):
            if row_groups[ri]:
                row_centers[ri] = sum(row_groups[ri]) / len(row_groups[ri])
    row_centers.sort()

    # 先按 x 聚成竖列。候选点不必全部找齐；漏掉一个空心圈不应让后续列错位。
    med_w = sorted(p["w"] for p in marks)[len(marks) // 2]
    columns = cluster_1d(marks, "x", max(3, int(med_w * 0.75)))
    if len(columns) < 2 or len(columns) % 2 != 0:
        return threshold, marks, None

    row_gaps = [row_centers[1] - row_centers[0],
                row_centers[2] - row_centers[1]]
    row_tolerance = max(4, int(min(row_gaps) * 0.48))
    cells = []
    for col_index in range(0, len(columns), 2):
        left_col = columns[col_index][1]
        right_col = columns[col_index + 1][1]
        cell = []
        for side, column in ((0, left_col), (1, right_col)):
            for row in range(3):
                in_row = [p for p in column
                          if abs(p["y"] - row_centers[row]) <= row_tolerance]
                if in_row:
                    point = min(in_row,
                                key=lambda p: abs(p["y"] - row_centers[row]))
                    if point["dark"]:
                        cell.append(str(row + 1 + side * 3))
        cells.append(",".join(cell) if cell else "空")
    return threshold, marks, ";".join(cells)



class ObjectDetectionApp(AIBase):
    """与课程 03.object_detect_yolov8n.py 相同的 YOLOv8n 推理流程。"""
    def __init__(self, kmodel_path, labels, model_input_size, max_boxes_num,
                 confidence_threshold=0.3, nms_threshold=0.65,
                 rgb888p_size=RGB_SIZE, display_size=DISPLAY_SIZE, debug_mode=0):
        super().__init__(kmodel_path, model_input_size, rgb888p_size, debug_mode)
        self.labels = labels
        self.model_input_size = model_input_size
        self.confidence_threshold = confidence_threshold
        self.nms_threshold = nms_threshold
        self.max_boxes_num = max_boxes_num
        self.rgb888p_size = [ALIGN_UP(rgb888p_size[0], 16), rgb888p_size[1]]
        self.display_size = [ALIGN_UP(display_size[0], 16), display_size[1]]
        self.debug_mode = debug_mode
        self.colors = get_colors(len(labels))
        self.ai2d = Ai2d(debug_mode)
        self.ai2d.set_ai2d_dtype(nn.ai2d_format.NCHW_FMT, nn.ai2d_format.NCHW_FMT,
                                 np.uint8, np.uint8)

    def config_preprocess(self, input_image_size=None):
        ai2d_input_size = input_image_size if input_image_size else self.rgb888p_size
        top, bottom, left, right, self.scale = letterbox_pad_param(
            self.rgb888p_size, self.model_input_size)
        self.ai2d.pad([0, 0, 0, 0, top, bottom, left, right], 0, [128, 128, 128])
        self.ai2d.resize(nn.interp_method.tf_bilinear, nn.interp_mode.half_pixel)
        self.ai2d.build([1, 3, ai2d_input_size[1], ai2d_input_size[0]],
                        [1, 3, self.model_input_size[1], self.model_input_size[0]])

    def preprocess(self, input_np):
        return [nn.from_numpy(input_np)]

    def postprocess(self, results):
        output = results[0][0].transpose()
        return aidemo.yolov8_det_postprocess(
            output.copy(), [self.rgb888p_size[1], self.rgb888p_size[0]],
            [self.model_input_size[1], self.model_input_size[0]],
            [self.display_size[1], self.display_size[0]], len(self.labels),
            self.confidence_threshold, self.nms_threshold, self.max_boxes_num)

    def draw_result(self, pipeline, detections):
        pipeline.osd_img.clear()
        if not detections:
            return
        for i in range(len(detections[0])):
            x, y, w, h = [int(round(v)) for v in detections[0][i]]
            cls_id = int(detections[1][i])
            label = self.labels[cls_id] if 0 <= cls_id < len(self.labels) else "object"
            color = self.colors[cls_id]
            pipeline.osd_img.draw_rectangle(x, y, w, h, color=color, thickness=3)
            pipeline.osd_img.draw_string_advanced(x, max(0, y - 28), 24,
                                                  "%s %.2f" % (label, detections[2][i]),
                                                  color=color)


def new_pipeline(rgb_size=None):
    mode = DISPLAY_MODE
    if rgb_size is None:
        rgb_size = RGB_SIZE
    p = PipeLine(rgb888p_size=rgb_size, display_size=DISPLAY_SIZE,
                 display_mode=mode)
    p.create()
    return p


def destroy_pipeline(pipeline):
    if pipeline:
        try:
            pipeline.destroy()
        except Exception as e:
            print("关闭摄像头管线提示:", e)
    try:
        MediaManager.deinit()
    except Exception:
        pass
    gc.collect()


def destroy_and_recreate_pipeline(pipeline, rgb_size):
    destroy_pipeline(pipeline)
    return new_pipeline(rgb_size)


def frame_shape(frame):
    shape = frame.shape
    if len(shape) == 4:
        return int(shape[1]), int(shape[2]), int(shape[3]), 4
    if len(shape) == 3:
        return int(shape[0]), int(shape[1]), int(shape[2]), 3
    return 0, 0, 0, 0


def sample_color(frame, box):
    channels, height, width, ndim = frame_shape(frame)
    if channels < 3 or height <= 0 or width <= 0:
        return None
    x, y, w, h = box
    x0 = max(0, int(x * width / DISPLAY_SIZE[0] + w * width / DISPLAY_SIZE[0] * 0.2))
    x1 = min(width, int((x + w * 0.8) * width / DISPLAY_SIZE[0]))
    y0 = max(0, int(y * height / DISPLAY_SIZE[1] + h * height / DISPLAY_SIZE[1] * 0.2))
    y1 = min(height, int((y + h * 0.8) * height / DISPLAY_SIZE[1]))
    if x1 <= x0 or y1 <= y0:
        return None
    sx = max(1, (x1 - x0) // 8)
    sy = max(1, (y1 - y0) // 8)
    sums = [0, 0, 0]
    count = 0
    try:
        for yy in range(y0, y1, sy):
            for xx in range(x0, x1, sx):
                if ndim == 4:
                    sums[0] += int(frame[0, 0, yy, xx])
                    sums[1] += int(frame[0, 1, yy, xx])
                    sums[2] += int(frame[0, 2, yy, xx])
                else:
                    sums[0] += int(frame[0, yy, xx])
                    sums[1] += int(frame[1, yy, xx])
                    sums[2] += int(frame[2, yy, xx])
                count += 1
    except Exception as e:
        print("颜色采样失败:", e)
        return None
    if count == 0:
        return None
    r, g, b = sums[0] // count, sums[1] // count, sums[2] // count
    values = [(r, "红色"), (g, "绿色"), (b, "蓝色")]
    values.sort()
    low, middle, high = values[0][0], values[1][0], values[2][0]
    if high < 65 or high - middle < 28 or high < middle * 1.22 or high - low < 45:
        return None
    return values[2][1]


def unpack_detections(result, frame):
    found = []
    if not result or len(result) < 3:
        return found
    for i in range(len(result[0])):
        box = [float(v) for v in result[0][i]]
        cls_id = int(result[1][i])
        score = float(result[2][i])
        if cls_id < 0 or cls_id >= len(LABELS):
            continue
        found.append({"box": box, "class_id": cls_id,
                      "label": LABELS[cls_id], "score": score,
                      "color": sample_color(frame, box)})
    found.sort(key=lambda item: item["score"], reverse=True)
    return found


def detect_codes(found, frame, mode):
    codes = set()
    if mode == "颜色识别":
        color = sample_color(frame, [160, 120, 320, 240])
        if color in COLOR_CODES:
            codes.add(COLOR_CODES[color])
        return codes

    for item in found:
        cls_id = item["class_id"]
        if cls_id in OBJECT_CODES:
            codes.add(OBJECT_CODES[cls_id])
    return codes
def send_new_codes(uart, current_codes, previous_codes, empty_frames):
    if current_codes:
        for code in sorted(current_codes - previous_codes):
            name = CODE_NAMES.get(code, "未知类别")
            print("识别到:", name, "编号:", code)
            send_code=int(code)
            packet = struct.pack(">BBB", 0xAA, send_code, 0x55)
            uart.send(packet)
            print("串口已发送: AA %02X 55" % int(code))
        return set(current_codes), 0
    empty_frames += 1
    if empty_frames >= 8:
        return set(), empty_frames
    return previous_codes, empty_frames


def send_braille_result(uart, pattern):
    # 文本协议：BRL,盲符数量,第1格点位,第2格点位,...,END\n。
    # 一格中的点号直接拼接；没有实心点的空格不作为盲符发送。
    # 例：1,3,5;1,2,5,6 -> BRL,2,135,1256,END\n。
    cells = []
    for cell in pattern.split(";"):
        if cell == "空" or not cell:
            continue
        digits = []
        for value in cell.split(","):
            dot = int(value)
            if dot < 1 or dot > 6:
                raise ValueError("盲文点号超出1~6: " + value)
            digits.append(str(dot))
        if digits:
            cells.append("".join(digits))
    if not cells:
        return False
    packet = "BRL,%d,%s,END\n" % (len(cells), ",".join(cells))
    uart.send(packet)
    print("盲文稳定结果:", pattern)
    print("盲文串口已发送:", repr(packet))
    return True


def main():
    os.exitpoint(os.EXITPOINT_ENABLE)
    nn.shrink_memory_pool()

    uart = None
    pipeline = None
    detector = None
    previous_codes = set()
    empty_frames = 0
    braille_candidate = None
    braille_same_count = 0
    braille_last_sent = None
    braille_empty_frames = 0
    mode = "颜色识别"
    return_mode = "颜色识别"
    key_was_down = False
    frame_no = 0
    uart_rx_buffer = ""

    try:
        uart = YbUart(baudrate=115200)
        key = YbKey()
        print("初始化摄像头管线，显示模式:", DISPLAY_MODE)
        pipeline = new_pipeline()

        print("初始化 YOLOv8n:", MODEL_PATH)
        detector = ObjectDetectionApp(
            MODEL_PATH, LABELS, MODEL_SIZE, max_boxes_num=8,
            confidence_threshold=YOLO_CONFIDENCE_THRESHOLD, nms_threshold=0.65,
            rgb888p_size=RGB_SIZE, display_size=DISPLAY_SIZE,
            debug_mode=0)
        detector.config_preprocess()
        print("当前模式：颜色识别。按键切换物品识别；串口发送 hello 切换盲文模式，再发 hello 返回原颜色/物品模式。")

        while True:
            os.exitpoint()

            # YbUart.read() 返回串口收到的字节；保留缓冲以兼容 hello 被分段到达。
            incoming = uart.read()
            if incoming:
                print("串口收到原始数据:", repr(incoming))
                if isinstance(incoming, str):
                    received_text = incoming
                else:
                    received_text = bytes(incoming).decode("utf-8", "ignore")
                uart_rx_buffer += received_text.lower()
                while "hello" in uart_rx_buffer:
                    command_index = uart_rx_buffer.find("hello")
                    uart_rx_buffer = uart_rx_buffer[command_index + 5:]
                    if mode == "盲文识别":
                        mode = return_mode
                    else:
                        return_mode = mode
                        mode = "盲文识别"
                    previous_codes = set()
                    empty_frames = 0
                    braille_candidate = None
                    braille_same_count = 0
                    braille_last_sent = None
                    braille_empty_frames = 0
                    print("串口收到 hello，切换到：", mode)
            if len(uart_rx_buffer) > 128:
                uart_rx_buffer = uart_rx_buffer[-4:]

            key_down = bool(key.is_pressed())
            if mode != "盲文识别" and key_down and not key_was_down:
                if mode == "颜色识别":
                    mode = "物品识别"
                else:
                    mode = "颜色识别"
                previous_codes = set()
                empty_frames = 0
                print("按键切换，当前模式：", mode)
            key_was_down = key_down

            frame = pipeline.get_frame()
            try:
                frame_no += 1
                if mode == "盲文识别":
                    frame_height = int(frame.shape[1])
                    frame_width = int(frame.shape[2])
                    gray = frame[0]
                    braille_threshold, braille_points, braille_pattern = recognize(
                        gray, frame_width, frame_height)
                    pipeline.osd_img.clear()

                    # 盲文模式只执行盲文识别，不运行YOLO物品识别。
                    dark_count = 0
                    for point in braille_points:
                        if point["dark"]:
                            dark_count += 1
                            x, y, w, h = point["rect"]
                            pipeline.osd_img.draw_rectangle(
                                x, y, w, h, color=(255, 0, 255, 0), thickness=2)
                            pipeline.osd_img.draw_cross(
                                point["x"], point["y"],
                                color=(255, 0, 255, 0), size=8, thickness=2)
                    if frame_no % 15 == 0:
                        print("盲文诊断：阈值=%d 实心点=%d 定位点=%d 序列=%s" %
                              (braille_threshold, dark_count, len(braille_points),
                               braille_pattern if braille_pattern else "点列不完整"))

                    if braille_pattern:
                        braille_empty_frames = 0
                        if braille_pattern == braille_candidate:
                            braille_same_count += 1
                        else:
                            braille_candidate = braille_pattern
                            braille_same_count = 1
                        if frame_no % 15 == 0:
                            print("盲文稳定计数：%d/10" % min(braille_same_count, 10))
                        if (braille_same_count >= 10 and
                                braille_pattern != braille_last_sent):
                            send_braille_result(uart, braille_pattern)
                            braille_last_sent = braille_pattern
                    else:
                        braille_candidate = None
                        braille_same_count = 0
                        if len(braille_points) < 3:
                            braille_empty_frames += 1
                        else:
                            braille_empty_frames = 0
                        if braille_empty_frames >= 8:
                            braille_last_sent = None
                            braille_empty_frames = 0
                else:
                    result = detector.run(frame)
                    found = unpack_detections(result, frame)
                    detector.draw_result(pipeline, result)
                    current_codes = detect_codes(found, frame, mode)
                    previous_codes, empty_frames = send_new_codes(
                        uart, current_codes, previous_codes, empty_frames)

                pipeline.show_image()
            finally:
                pipeline.cur_frame = None
                try:
                    del gray
                except Exception:
                    pass
                del frame
            gc.collect()

    except KeyboardInterrupt:
        print("用户停止程序")
    except Exception as e:
        print("主程序异常:", e)
        try:
            import sys
            sys.print_exception(e)
        except Exception:
            pass
    finally:
        if detector:
            try:
                detector.deinit()
            except Exception:
                pass
        destroy_pipeline(pipeline)
        gc.collect()


if __name__ == "__main__":
    main()



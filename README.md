# 三模式整合工程

所有FPGA源码集中在rtl，图像模块独立分组；模块名称、引脚和功能不变。

```text
rtl/top       顶层braille_modes_top.v
rtl/control   键盘、模式一二控制、UART、模式三判题及映射表
rtl/audio     音频PLL、ES8388初始化、Flash读取和I2S播放器
rtl/image     braille_image_rx.v与braille_image_core.v
constraints   引脚与时序约束
k230          通信和图像发送接口，不含摄像头主程序与模型
scripts       构建、17项仿真、音频打包、电脑发图
tests         全部仿真源码（含tb_braille_image.v）
audio_assets  audio.bin及172条音频清单
音频          全部172条WAV源素材，含模式三物品、字音及提示语
build         可下载bit文件
reports       资源、时序与回归记录
test_output/images  杯子图像测试帧
```

编译：`./scripts/build.ps1 -TD '实际TD安装目录/bin/td_commands_prompt.exe'`

测试：`./scripts/test.ps1 -Icarus '实际Icarus安装目录/bin'`

图像入口：`rtl/image/braille_image_rx.v`接收IMG1并检查完整性；`rtl/image/braille_image_core.v`执行灰度、3×3均值、阈值分割和六点提取。顶层连接原模式三判题及语音，不是另一个独立下载工程。

FPGA下载：`build/braille_modes_demo_Runs/phy_1/braille_modes_demo.bit`。

音频Flash烧录：`audio_assets/audio.bin`，使用W25Q128，从地址0开始。

图像仿真和编译证据不等同于实际纸面识别准确率。K230目录提供通信及图像发送接口，不包含完整摄像头主程序、模型和纸面定位算法。工程证据范围见reports/交付验证记录.md。

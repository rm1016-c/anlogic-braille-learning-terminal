param([string]$Icarus = "C:/iverilog/bin")
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot/..").Path
$out = "$root/test_output"
New-Item -ItemType Directory -Force $out | Out-Null

function Invoke-RtlTest {
    param([string]$Top, [string[]]$Sources, [string]$PassText)
    $vvp = "$out/$Top.vvp"
    $log = "$out/$Top.txt"
    & "$Icarus/iverilog.exe" -g2012 -s $Top -o $vvp @Sources
    if ($LASTEXITCODE -ne 0) { throw "$Top compile failed" }
    $result = & "$Icarus/vvp.exe" $vvp
    $exitCode = $LASTEXITCODE
    $result | Tee-Object $log
    if ($exitCode -ne 0 -or $result -match 'FATAL:' -or -not ($result -match $PassText)) {
        throw "$Top simulation failed"
    }
}

Invoke-RtlTest -Top tb_braille_image -Sources @(
    "$root/rtl/image/braille_image_core.v",
    "$root/rtl/image/braille_image_rx.v",
    "$root/tests/tb_braille_image.v"
) -PassText '^PASS image:'

Invoke-RtlTest -Top tb_mode3_writing -Sources @(
    "$root/rtl/control/recognition_uart.v",
    "$root/rtl/control/braille_text_rx.v",
    "$root/rtl/control/uart_hello_tx.v",
    "$root/rtl/control/mode3_uart_bridge.v",
    "$root/rtl/control/mode3_learning_lut.v",
    "$root/tests/tb_mode3_writing.v"
) -PassText '^PASS mode3 writing:'

Invoke-RtlTest -Top tb_uart_activity_diag -Sources @(
    "$root/rtl/control/uart_activity_diag.v",
    "$root/tests/tb_uart_activity_diag.v"
) -PassText '^PASS raw UART activity:'

Invoke-RtlTest -Top tb_recognition_uart -Sources @(
    "$root/rtl/control/recognition_uart.v",
    "$root/tests/tb_recognition_uart.v"
) -PassText '^PASS UART:'

Invoke-RtlTest -Top tb_mode3_audio_test -Sources @(
    "$root/rtl/control/mode12_controller.v",
    "$root/rtl/control/mode1_key_lut.v",
    "$root/rtl/control/mode2_question_rom.v",
    "$root/tests/tb_mode3_audio_test.v"
) -PassText '^PASS mode3 audio test:'

Invoke-RtlTest -Top tb_mode1_key_lut -Sources @(
    "$root/rtl/control/mode1_key_lut.v",
    "$root/tests/tb_mode1_key_lut.v"
) -PassText '^PASS mode1 LUT:'

Invoke-RtlTest -Top tb_matrix8x8_scanner -Sources @(
    "$root/rtl/control/matrix8x8_scanner.v",
    "$root/tests/tb_matrix8x8_scanner.v"
) -PassText '^PASS matrix scanner:'

Invoke-RtlTest -Top tb_mode12_controller -Sources @(
    "$root/rtl/control/mode1_key_lut.v",
    "$root/rtl/control/mode2_question_rom.v",
    "$root/rtl/control/mode12_controller.v",
    "$root/tests/tb_mode12_controller.v"
) -PassText '^PASS mode controller:'

Invoke-RtlTest -Top tb_mode2_full_session -Sources @(
    "$root/rtl/control/mode1_key_lut.v",
    "$root/rtl/control/mode2_question_rom.v",
    "$root/rtl/control/mode12_controller.v",
    "$root/tests/tb_mode2_full_session.v"
) -PassText '^PASS full mode2 session:'

Invoke-RtlTest -Top tb_mode2_correction -Sources @(
    "$root/rtl/control/mode1_key_lut.v",
    "$root/rtl/control/mode2_question_rom.v",
    "$root/rtl/control/mode12_controller.v",
    "$root/tests/tb_mode2_correction.v"
) -PassText '^PASS mode2 correction:'

Invoke-RtlTest -Top tb_mode2_stage1_normal -Sources @(
    "$root/rtl/control/mode1_key_lut.v",
    "$root/rtl/control/mode2_question_rom.v",
    "$root/rtl/control/mode12_controller.v",
    "$root/tests/tb_mode2_stage1_normal.v"
) -PassText '^PASS stage1 normal:'

Invoke-RtlTest -Top tb_mode2_dynamic_wrong -Sources @(
    "$root/rtl/control/mode1_key_lut.v",
    "$root/rtl/control/mode2_question_rom.v",
    "$root/rtl/control/mode12_controller.v",
    "$root/tests/tb_mode2_dynamic_wrong.v"
) -PassText '^PASS dynamic wrong set:'

Invoke-RtlTest -Top tb_mode2_stage1_retest -Sources @(
    "$root/rtl/control/mode1_key_lut.v",
    "$root/rtl/control/mode2_question_rom.v",
    "$root/rtl/control/mode12_controller.v",
    "$root/tests/tb_mode2_stage1_retest.v"
) -PassText '^PASS stage1 retest:'

Invoke-RtlTest -Top tb_mode2_all_stage_retest -Sources @(
    "$root/rtl/control/mode1_key_lut.v",
    "$root/rtl/control/mode2_question_rom.v",
    "$root/rtl/control/mode12_controller.v",
    "$root/tests/tb_mode2_all_stage_retest.v"
) -PassText '^PASS all-stage retest:'


Invoke-RtlTest -Top tb_pcm_stream_i2s_player -Sources @("$root/rtl/audio/pcm_stream_i2s_player.v", "$root/tests/tb_pcm_stream_i2s_player.v") -PassText '^PASS PCM stream player:'

Invoke-RtlTest -Top tb_w25q64_stream_reader -Sources @("$root/rtl/audio/w25q64_stream_reader.v", "$root/tests/tb_w25q64_stream_reader.v") -PassText '^PASS w25q64 reader:'

Invoke-RtlTest -Top tb_pcm_byte_assembler -Sources @("$root/rtl/audio/pcm_byte_assembler.v", "$root/tests/tb_pcm_byte_assembler.v") -PassText '^PASS PCM assembler:'


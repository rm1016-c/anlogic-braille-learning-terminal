if {[info exists ::env(BRAILLE_PROJECT_ROOT)]} {
    set project_root [file normalize $::env(BRAILLE_PROJECT_ROOT)]
} else {
    set project_root [file normalize [file join [file dirname [info script]] ..]]
}
file mkdir [file join $project_root build]
cd [file join $project_root build]
import_device eagle_s20.db -package EG4S20BG256
if {[file exists braille_modes_demo.al]} {
    open_project braille_modes_demo.al
} else {
    create_project braille_modes_demo . -family EG4 -device EG4S20BG256
}
add_files {../rtl/top/braille_modes_top.v ../rtl/control/matrix8x8_scanner.v ../rtl/control/mode1_key_lut.v ../rtl/control/mode2_question_rom.v ../rtl/control/mode12_controller.v}
add_files {../rtl/control/recognition_uart.v ../rtl/control/mode3_uart_bridge.v}
add_files ../rtl/control/mode3_learning_lut.v
add_files ../rtl/control/uart_activity_diag.v
add_files {../rtl/control/braille_text_rx.v ../rtl/control/uart_hello_tx.v}
add_files {../rtl/image/braille_image_core.v ../rtl/image/braille_image_rx.v}
add_files {../rtl/audio/pcm_stream_i2s_player.v}
add_files {../rtl/audio/flash_audio_source.v ../rtl/audio/w25q64_stream_reader.v ../rtl/audio/pcm_byte_assembler.v ../rtl/audio/audio_descriptor_rom.v}
add_files {../rtl/audio/audio_pll.v ../rtl/audio/es8388_init.v}
add_files ../constraints/braille_modes.adc
add_files ../constraints/braille_modes.sdc
top_module braille_modes_top
reset_runs syn_1
launch_runs {syn_1 phy_1}
wait_run syn_1
wait_run phy_1
close_project


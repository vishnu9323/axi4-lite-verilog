# Vivado batch flow for the AXI4-Lite project.
#
# Usage:
#   vivado -mode batch -source scripts\vivado_run.tcl -tclargs <part>
#
# Example:
#   vivado -mode batch -source scripts\vivado_run.tcl -tclargs xc7a35tcpg236-1
#
# The FPGA part is intentionally supplied by the caller because it depends on
# the target board/device.

if {$argc != 1} {
    puts "ERROR: supply the FPGA part as the only argument."
    puts "Usage: vivado -mode batch -source scripts\\vivado_run.tcl -tclargs <part>"
    exit 1
}

set part_name [lindex $argv 0]
set script_dir [file dirname [file normalize [info script]]]
set project_dir [file normalize [file join $script_dir ..]]
set project_name axi4lite_project

create_project $project_name $project_dir -part $part_name -force

set rtl_files [glob -nocomplain \
    [file join $project_dir rtl axi4lite_top.v] \
    [file join $project_dir rtl master *.v] \
    [file join $project_dir rtl slave *.v]]

if {[llength $rtl_files] == 0} {
    puts "ERROR: no RTL files were found."
    exit 1
}

add_files -fileset sources_1 $rtl_files
set_property top axi4lite_top [get_filesets sources_1]

set sim_files [glob -nocomplain [file join $project_dir tb *.v]]
if {[llength $sim_files] == 0} {
    puts "ERROR: no simulation testbench files were found in $project_dir\\tb."
    exit 1
}

add_files -fileset sim_1 $sim_files
set_property top axi4lite_top_tb [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "INFO: compiling and elaborating RTL..."
synth_design -top axi4lite_top -part $part_name

puts "INFO: running behavioral simulation..."
launch_simulation -simset sim_1 -mode behavioral
run all

close_sim
close_project
puts "INFO: AXI4-Lite compile and simulation completed."

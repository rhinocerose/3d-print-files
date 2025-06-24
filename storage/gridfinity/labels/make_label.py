import subprocess
import argparse

box_width = 5
max_font = 8
column_gap = 4

## COMPLETED
# print_list = [
    # ["Diode-COM-Standard", "Through Hole", "Diodes", "th-diode-label"],
    # ["Resistor-IEEE-Potentiometer", "Panel", "Pots", "panel-pot-label"],
    # ["Resistor-IEEE-Potentiometer", "PCB", "Pots", "pcb-pot-label"],
    # ["Resistor-IEEE-Trimmer", "Trimpots", None, "trimpot-label"],
    # ["Switch-COM-SPST", "Switches", None, "switch-label"],
    # ["Transistor-COM-BJT-NPN", "SMD", "Transistors", "smd-transistor-labels"],
    # ["Diode-COM-Standard", "SMD", "Diodes", "smd-diodes-labels"],
    # ["Diode-COM-LED", "SMD", "LEDs", "smd-leds-labels"],
    # ["Miscellaneous-COM-Crystal_Oscillator", "Crystals", None, "crystals-labels"],
    # ["IC-COM-OpAmp", "Through Hole", "Op Amps", "th-opamp-label"],
    # ["IC-COM-OpAmp", "SMD", "Op Amps", "smd-opamp-label"],
    # ["IC-COM-Logic-NOR", "Through Hole", "Logic IC", "th-logic-ic-label"],
    # ["IC-COM-Logic-NOR", "SMD", "Logic IC", "smd-logic-ic-label"],
    # ["Inductor-COM-Air", "Inductors", "Fuses", "fuse-inductor-label"],
    # ["Audio-COM-Loudspeaker", "Audio", "Connectors", "audio-connector-label"],
    # ["Source-COM-DC", "Power", "Connectors", "power-connector-label"],
# ]

print_list = [
    ["Custom-MCU", "SMD", "Microcontrollers", "smd-mcu-label"]
]


if __name__ == "__main__":

    for i in print_list:

        symbol_arg = '{symbol(' + i[0] + ')}{8|20}' + i[1]
        if i[2] is not None:
            symbol_arg += '\n' + i[2]
        gflabel_command = [
            "gflabel", "predbox", 
            "-w", str(box_width),
            "--font-size-max", str(max_font),
            "--no-overheight", 
            "--column-gap", str(column_gap),
            "--font-style", "bold",
            symbol_arg,
            "-o", i[3] + ".stl"
        ]

        print(gflabel_command)

        subprocess.run(gflabel_command)
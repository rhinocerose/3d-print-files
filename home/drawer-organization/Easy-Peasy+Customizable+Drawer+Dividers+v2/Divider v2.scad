/* [Drawer/Divider Parameters] */
// total height of each divider wall
drawer_depth = 50;
// internal drawer width (X-axis constraint)
drawer_width = 200;
// internal drawer length (Y-axis constraint)
drawer_length = 200;
// thickness of divider walls
divider_thickness = 3.5; // [1.5:.5:4]
// max printable X length before horizontal dividers split
max_print_length_x = 250; // [50:10:1000]
// max printable Y length before vertical dividers split
max_print_length_y = 250; // [50:10:1000]
/* [Columns and Rows] */
// Number of columns
columns = 3; // [1:6]
// Number of rows
rows = 4;    // [1:6]
/* [Special Cell] */
// Column spanning of the first cell
colspan = 1; // [1:6]
// Row spanning of the first cell
rowspan = 2; // [1:6]
/* [Pattern Parameters] */
// which pattern to put on the dividers
pattern="honeycomb 🐝"; // [none 🛇, honeycomb 🐝, pill 💊, diamond ◆, slots ▥]
// the thickness of the border around the pattern
pattern_border_thickness=2; // [1:8]
/* [Honeycomb 🐝 Pattern Parameters] */
// radius of each hexagon (tweak these to prevent overhangs on top row)
cell_radius = 3; // [3:0.1:10]
// spacing between adjacent hexagons
cell_gap = 1.4; // [1:0.1:10]
/* [Pill 💊 Pattern Parameters] */
// vertical spacing between pill rows
pill_vertical_gap = 4; // [3:10]
// horizontal spacing between adjacent pills
pill_horizontal_gap = 1; // [1:8]
// total height of each pill
pill_height = 8; // [1:17]
// radius of rounded ends (half pill width)
pill_radius = 1.5; // [.5:0.1:2]
// stagger offset between alternate rows
pill_offset = 5; // [0:5]
/* [Diamond ◆ Pattern Parameters] */
// width of each diamond cutout
diamond_width = 4.5; // [3:0.5:20]
// height of each diamond cutout
diamond_height = 6.5; // [3:0.5:25]
// horizontal spacing between diamond cutouts
diamond_horizontal_gap = 1.5; // [0:0.5:12]
// vertical spacing between diamond cutouts
diamond_vertical_gap = 2.5; // [0:0.5:12]
// stagger offset between alternate diamond rows, as a multiplier of horizontal spacing
diamond_offset = 0.5; // [0:0.1:1]
// vertical overlap between adjacent diamond rows, as a multiplier of diamond height
diamond_vertical_offset = 0.5; // [0:0.1:0.9]
/* [Slots ▥ Pattern Parameters] */
// width of each slot cutout
slot_width = 3; // [1:0.5:10]
// horizontal spacing between adjacent slot columns
slot_horizontal_gap = 5; // [1:0.5:20]
// angle of the slot cutouts
slot_angle = 20; // [-60:5:60]
/* [Junction Parameters] */
// Junction block dimensions
// the thickness of the junction out from the divider center
junction_thickness = 9;
junction_width     = 10;
junction_height    = drawer_depth;
// tweak at if things are too loose or too big
dovetail_clearence   = 0.05; //[0:.01:.3]
// height of each tooth (cut depth, not 1:1 with size)
teeth_height = (junction_thickness+.6)*2 - divider_thickness -1;
////////////////////////////////////////////////////////////
// DOVETAIL LIBRARY (unchanged from hugokernel)
// see https://github.com/hugokernel/OpenSCAD_Dovetail
////////////////////////////////////////////////////////////
module dovetail_teeth(width, height, thickness) {
    offset = width / 3;
    translate([-width/2, -height/2, 1]) {
        linear_extrude(height = thickness) {
            polygon([
                [0, 0],
                [width, 0],
                [width - offset, height],
                [offset, height]
            ]);
        }
    }
}
module dovetail(width, teeth_count, teeth_height, teeth_thickness, clear = dovetail_clearence, male = true, debug = false) {
    y = ((width - 1 * 2 * clear) / 1) / 4;
    compensation = -0.1;
    teeth_width = y * 3;
    offset = teeth_width / 3;
    start_at = clear * 2 + teeth_width/2 - width/2 - clear;
    translate([0, 0, -teeth_thickness/2]) {
        if (debug) {
            translate([-width/2, 0, -width/2]) {
                %cube(size = [width, 0.01, width]);
            }
        }
        for (i = [-1 : 1 * 2 - 1]) {
            x = start_at + y/2 + (teeth_width - offset + clear) * i;
            if (i % 2) {
                x = x + 0.1;
                translate([x + compensation, -clear, 0]) {
                    rotate([0, 0, 180]) {
                        if (male == true) {
                            dovetail_teeth(teeth_width - clear, teeth_height - clear, teeth_thickness);
                        }
                    }
                }
            } else {
                translate([x, clear, 0]) {
                    if (male == false) {
                        dovetail_teeth(teeth_width - clear, teeth_height - clear, teeth_thickness);
                    }
                }
            }
        }
    }
}
module cutter(position, dimension, teeths, male = true, debug = false) {
    translate(position) {
        dovetail(dimension[0], teeths[0], teeths[1], dimension[2], teeths[2], male, debug);
        if (male) {
            translate([
                -dimension[0]/2,
                -(teeths[1]/2 - 0.1) - dimension[1],
                -dimension[2]/2
            ]) {
                cube(size = dimension, center = false);
            }
        } else {
            translate([
                -dimension[0]/2,
                teeths[1]/2 - 0.1,
                -dimension[2]/2
            ]) {
                cube(size = dimension, center = false);
            }
        }
    }
}
////////////////////////////////////////////////////////////
// UTILITY MODULES
////////////////////////////////////////////////////////////
module rect_2d(width, height) {
    square([width, height], center = false);
}
module pattern_honeycomb_2d(width, height) {
    col_spacing = sqrt(3)*cell_radius + cell_gap;
    row_spacing = 1.5*cell_radius + cell_gap;
    rows = ceil(height / row_spacing) + 2;
    cols = ceil(width / col_spacing) + 2;
    for (row = [0 : rows - 1]) {
        for (col = [0 : cols - 1]) {
            x = col*col_spacing + (row % 2)*(col_spacing/2);
            y = row*row_spacing;
            translate([x, y])
                polygon(points = [
                    [0, cell_radius],
                    [(sqrt(3)*cell_radius)/2, cell_radius/2],
                    [(sqrt(3)*cell_radius)/2, -cell_radius/2],
                    [0, -cell_radius],
                    [-(sqrt(3)*cell_radius)/2, -cell_radius/2],
                    [-(sqrt(3)*cell_radius)/2, cell_radius/2]
                ]);
        }
    }
}
module pattern_pill_2d(width, height) {
    x_spacing = pill_vertical_gap;
    y_spacing = pill_height + pill_horizontal_gap;
    intersection() {
        square([width, height]);
        for (col = [0:ceil(width/x_spacing)]) {
            y_offset = (col % 2) ? pill_offset : 0;
            for (row = [0:ceil(height/y_spacing)*2]) {
                x = col * x_spacing;
                y = row * y_spacing;
                if (x < width && y < height) {
                    if (y+y_offset+pill_height - pill_horizontal_gap <= height && y+y_offset - pill_height >= 0) {
                        translate([x + pill_vertical_gap/2, y + y_offset])
                            pill_cutout_2d(pill_vertical_gap, pill_height, pill_radius);
                    }
                }
            }
        }
    }
}
module pattern_diamond_2d(width, height) {
    x_spacing = diamond_width + diamond_horizontal_gap;
    y_spacing = diamond_height + diamond_vertical_gap - diamond_height * diamond_vertical_offset;
    rows = ceil(height / y_spacing) + 1;
    cols = ceil(width / x_spacing) + 1;
    for (row = [0 : rows]) {
        for (col = [0 : cols]) {
            x = col * x_spacing + (row % 2) * x_spacing * diamond_offset;
            y = row * y_spacing;
            translate([x + diamond_width/2, y + diamond_height/2])
                polygon(points = [
                    [0, diamond_height/2],
                    [diamond_width/2, 0],
                    [0, -diamond_height/2],
                    [-diamond_width/2, 0]
                ]);
        }
    }
}
module slot_cutout_2d(cutout_width, cutout_length) {
    square([cutout_width, cutout_length], center=true);
}
module pattern_angled_slots_2d(width, height) {
    x_spacing = slot_width + slot_horizontal_gap;
    cutout_length = height / max(0.1, abs(cos(slot_angle))) + slot_width * 2;
    cols = ceil(width / x_spacing) + ceil(cutout_length / x_spacing) + 4;
    for (col = [-2 : cols]) {
        x = col * x_spacing;
        translate([x, height/2])
            rotate(slot_angle)
                slot_cutout_2d(slot_width, cutout_length);
    }
}
module pill_cutout_2d(width, height, radius) {
    hull() {
        translate([radius, -height/2 + radius])
            circle(r=radius, $fa=5, $fs=0.5);
        translate([radius, height/2 - radius])
            circle(r=radius, $fa=5, $fs=0.5);
    }
}
module divider_panel_2d(length, height) {
    union() {
        // Re-add the frame so pattern geometry cannot cut through the border.
        difference() {
            rect_2d(length, height);
            translate([pattern_border_thickness, pattern_border_thickness])
                rect_2d(length - 2*pattern_border_thickness, height - 2*pattern_border_thickness);
        }
        difference() {
            rect_2d(length, height);
            translate([pattern_border_thickness, pattern_border_thickness]) {
                if (pattern == "pill 💊")
                    pattern_pill_2d(length - 2*pattern_border_thickness, height - 2*pattern_border_thickness);
                if (pattern == "honeycomb 🐝")
                    pattern_honeycomb_2d(length - 2*pattern_border_thickness, height - 2*pattern_border_thickness);
                if (pattern == "diamond ◆")
                    pattern_diamond_2d(length - 2*pattern_border_thickness, height - 2*pattern_border_thickness);
                if (pattern == "slots ▥")
                    pattern_angled_slots_2d(length - 2*pattern_border_thickness, height - 2*pattern_border_thickness);
            }
        }
    }
}
////////////////////////////////////////////////////////////
// JUNCTION BLOCKS
////////////////////////////////////////////////////////////
module junction_female() {
    single_tooth = [1, teeth_height, 0.2];
    difference() {
        rotate([90, 0, 0]) {
            union() {
                cube([junction_width, junction_thickness, junction_height], center = false);
                linear_extrude(height = junction_height)
                    polygon(points = [
                        [0, 0],
                        [-junction_width/6, junction_thickness],
                        [junction_width, junction_thickness]
                    ]);
                linear_extrude(height = junction_height)
                    polygon(points = [
                        [junction_width, 0],
                        [junction_width+junction_width/6, junction_thickness],
                        [0, junction_thickness]
                    ]);
                linear_extrude(height = junction_height)
                    polygon(points = [
                        [junction_width/2, junction_thickness + divider_thickness/3],
                        [junction_width + junction_width/6, junction_thickness],
                        [-junction_width/6, junction_thickness]
                    ]);
            }
        }
        rotate([90, 0, 0]) {
            cutter(
                [0, 0, 0],
                [junction_width, junction_thickness, junction_height * 2],
                single_tooth,
                true
            );
        }
    }
}
module junction_male() {
    single_tooth = [1, teeth_height, .2 + dovetail_clearence];
    intersection() {
        rotate([90, 0, 0]) {
            cube([junction_width, junction_thickness, junction_height], center = false);
        }
        rotate([90, 0, 0]) {
            cutter(
                [0, 0, 0],
                [junction_width, junction_thickness, junction_height*2],
                single_tooth,
                true
            );
        }
    }
}
////////////////////////////////////////////////////////////
// DIVIDER END HELPERS
////////////////////////////////////////////////////////////
function dovetail_tooth_width(clearance=dovetail_clearence) =
    ((junction_width - 2 * clearance) / 4) * 3;

function dovetail_offset(clearance=dovetail_clearence) =
    (junction_width - dovetail_tooth_width(clearance)) / 2;

module dovetail_end_male_start() {
    teeth_width = dovetail_tooth_width();
    offset = dovetail_offset();
    rotate([0, 270, 0]) {
        translate([
            -offset - teeth_width/2 + divider_thickness/2,
            drawer_depth,
            -(teeth_height - ((.2 + dovetail_clearence) * 3)) / 2
        ]) {
            junction_male();
        }
    }
}
module dovetail_end_male_end(length) {
    teeth_width = dovetail_tooth_width();
    offset = dovetail_offset();
    translate([length, 0, 0]) {
        rotate([0, 90, 0]) {
            translate([
                -offset - teeth_width/2 - divider_thickness/2,
                drawer_depth,
                -(teeth_height - ((.2 + dovetail_clearence) * 3)) / 2
            ]) {
                junction_male();
            }
        }
    }
}
module dovetail_end_female_end(length) {
    teeth_width = dovetail_tooth_width(.2);
    offset = dovetail_offset(.2);
    translate([length, 0, 0]) {
        rotate([0, 90, 0]) {
            translate([
                -offset - teeth_width/2 - divider_thickness/2,
                0,
                (teeth_height - ((.2 + dovetail_clearence) * 3)) / 2
            ]) {
                rotate([180, 0, 0])
                    junction_female();
            }
        }
    }
}
////////////////////////////////////////////////////////////
// DIVIDER MODULES
////////////////////////////////////////////////////////////
module divider_y_segment(height) {
    linear_extrude(height = divider_thickness)
        divider_panel_2d(height, drawer_depth);
    dovetail_end_male_start();
    dovetail_end_male_end(height);
}
module divider_panel_segment(length) {
    linear_extrude(height = divider_thickness)
        divider_panel_2d(length, drawer_depth);
}
// V2: vertical dividers can now also split when longer than max_print_length_y.
module divider_y_split(total_height) {
    if (total_height <= max_print_length_y) {
        divider_y_segment(total_height);
    } else {
        nsections = ceil(total_height / max_print_length_y);
        section_length = total_height / nsections;
        for (s = [0 : nsections - 1]) {
            section_start = s * section_length;
            actual_length = (s == nsections - 1)
                ? total_height - section_start
                : section_length;
            translate([section_start, 0, 0]) {
                divider_panel_segment(actual_length);
                dovetail_end_male_start();
                if (s < nsections - 1)
                    dovetail_end_female_end(actual_length);
                else
                    dovetail_end_male_end(actual_length);
            }
        }
    }
}
function adjust_split_boundary(candidate, junction_positions, buffer) =
    let ( close = [ for (junction_position = junction_positions) if (abs(candidate - junction_position) < buffer) junction_position ] )
    ( len(close) > 0 ) ?
         ( candidate < close[0] ? close[0] - buffer : close[0] + buffer )
         : candidate;
module divider_x_split(total_length, junction_positions, borders_special_cell=false) {
    if (total_length <= max_print_length_x) {
        for (i = [0 : len(junction_positions)]) {
            start_pos = (i == 0) ? 0 : junction_positions[i-1] + junction_width;
            end_pos = (i == len(junction_positions)) ? total_length : junction_positions[i];
            if (end_pos > start_pos)
                translate([start_pos, 0, 0])
                    divider_panel_segment(end_pos - start_pos);
        }
        for (pos = junction_positions) {
            translate([pos, drawer_depth, -junction_thickness + (divider_thickness + 1 - .6) / 2])
                junction_female();
            rotate([180, 0, 0])
                translate([pos, 0, -junction_thickness - divider_thickness + (divider_thickness + 1 - .6) / 2])
                    junction_female();
        }
        if (borders_special_cell == false)
            dovetail_end_male_start();
        dovetail_end_male_end(total_length);
    } else {
        split_junction_buffer = junction_width*2;
        nsections = ceil(total_length / max_print_length_x);
        base_section_length = total_length / nsections;
        split_boundaries = [ for (i = [0 : nsections])
            (i == 0) ? 0 : (i == nsections) ? total_length
            : adjust_split_boundary(i * base_section_length, junction_positions, split_junction_buffer)
        ];
        for (s = [0 : len(split_boundaries) - 2]) {
            section_start = split_boundaries[s];
            section_end = split_boundaries[s+1];
            section_length = section_end - section_start;
            section_junctions = [ for (jp = junction_positions)
                if (jp >= section_start && jp <= section_end)
                    jp - section_start
            ];
            translate([section_start, 0, 0]) {
                for (i = [0 : len(section_junctions)]) {
                    start_pos = (i == 0) ? 0 : section_junctions[i-1] + junction_width;
                    end_pos = (i == len(section_junctions)) ? section_length : section_junctions[i];
                    if (end_pos > start_pos)
                        translate([start_pos, 0, 0])
                            divider_panel_segment(end_pos - start_pos - 1);
                }
                for (pos = section_junctions) {
                    color("blue")
                        translate([pos, drawer_depth, -junction_thickness + (divider_thickness + 1 - .6) / 2])
                            junction_female();
                    color("green")
                        rotate([180, 0, 0])
                            translate([pos, 0, -junction_thickness - divider_thickness + (divider_thickness + 1 - .6) / 2])
                                junction_female();
                }
                if (borders_special_cell == true && s != 0 || borders_special_cell == false) {
                    dovetail_end_male_start();
                }
                if (borders_special_cell == true && s == 0) {
                    color("blue")
                        translate([-junction_width/2, drawer_depth, -junction_thickness + (divider_thickness + 1 - .6) / 2])
                            junction_female();
                    color("green")
                        rotate([180, 0, 0])
                            translate([-junction_width/2, 0, -junction_thickness - divider_thickness + (divider_thickness + 1 - .6) / 2])
                                junction_female();
                }
                if (section_end < total_length)
                    dovetail_end_female_end(section_length);
                else
                    dovetail_end_male_end(section_length);
            }
        }
    }
}
module drawer_divider_grid() {
    junction_gap = 25;
    real_colspan = min(colspan, columns);
    real_rowspan = min(rowspan, rows);
    cell_width = drawer_width / columns;
    cell_height = drawer_length / rows;
    echo("cell_width", cell_width);
    echo("cell_height", cell_height);
    special_width = real_colspan * cell_width;
    function visual_y(index) =
        (index == 0) ? 0 :
        (index * cell_height);
    v_dividers_logical = [for (c = [1 : columns-1]) c * cell_width - junction_width/2];
    h_positions = [for (r = [0 : rows]) visual_y(r)];
    for (r = [1 : rows-1]) {
        visual_pos_y = visual_y(r);
        if (r < real_rowspan) {
            if (real_colspan < columns) {
                translate([real_colspan * cell_width, visual_pos_y + ((junction_gap * r)-junction_gap/2 + divider_thickness/2), 0]) {
                    rotate([90, 0, 0]) {
                        junctions = [for (c = [real_colspan : columns-1])
                                    (c - real_colspan) * cell_width - junction_width/2];
                        divider_x_split(
                            drawer_width - special_width,
                            junctions,
                            true
                        );
                    }
                }
            }
        } else {
            translate([0, visual_pos_y + ((junction_gap * r)-junction_gap/2 + divider_thickness/2), 0]) {
                rotate([90, 0, 0]) {
                    divider_x_split(
                        drawer_width,
                        v_dividers_logical
                    );
                }
            }
        }
    }
    for (c = [1 : columns-1]) {
        logical_pos_x = c * cell_width;
        if (c < real_colspan) {
            if (real_rowspan < rows) {
                for (i = [real_rowspan : rows-1]) {
                    segment_start = h_positions[i];
                    segment_end = h_positions[i+1];
                    segment_height = segment_end - segment_start - ((rows-1)*divider_thickness)/rows;
                    echo("segment_height", segment_height);
                    translate([logical_pos_x - divider_thickness/2, segment_start + junction_gap * i, 0]) {
                        rotate([90, 0, 90]) {
                            divider_y_split(segment_height);
                        }
                    }
                }
            }
        } else {
            for (i = [0 : rows-1]) {
                segment_start = h_positions[i];
                segment_end = h_positions[i+1];
                segment_height = segment_end - segment_start - ((rows-1)*divider_thickness)/rows;
                echo("segment_height", segment_height);
                translate([logical_pos_x - divider_thickness/2, segment_start + junction_gap * i, 0]) {
                    rotate([90, 0, 90]) {
                            divider_y_split(segment_height);
                    }
                }
            }
        }
    }
}
translate([-drawer_width/2, -drawer_length/2, 0])
    drawer_divider_grid();

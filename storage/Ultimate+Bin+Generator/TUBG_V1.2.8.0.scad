// ============================================================================
// Parametric Storage Bin
// Optional lid, dividers, label recesses, wall styles, and bottom/base styles
// Supports flat, perimeter-foot, cornered perimeter-foot, and Gridfinity base options
// ============================================================================

$fn = 100;


// ============================================================================


/* [01 - Gridfinity / Size Mode] */
use_gridfinity       = false;

// Used only when Gridfinity is enabled.
// Bin footprint becomes true Gridfinity sizing: units * 42 mm - 0.5 mm body clearance.
gridfinity_x_units   = 2;
gridfinity_y_units   = 2;

// Used only when Gridfinity is disabled.
bin_width            = 120;
bin_depth            = 80;

// Always in mm.
bin_height           = 70;

wall_thickness       = 2.4;
bottom_thickness     = 2.8;


/* [02 - Shape / Corners] */
corner_style         = "rounded"; // [square, soft, rounded, industrial]
corner_radius        = 10;


/* [03 - Bottom / Base] */
// Used only when Gridfinity is disabled.
// When Gridfinity is enabled above, the bottom type is automatically forced to Gridfinity.
bottom_style         = "flat"; // [flat, perimeter, cornered_perimeter]
foot_height          = 2.0;
perimeter_foot_inset = 4;
perimeter_foot_width = 5;


/* [04 - Lid / Stacking] */
add_lid              = true;
lid_wall_thickness   = 2.4;
lid_clearance        = 0.25;   // per side
lid_top_thickness    = 2.4;
lid_overlap_depth    = 10;
stackable_lid        = false;


/* [05 - Internal Dividers] */
add_dividers         = true;
divider_count_width  = 1;
divider_count_depth  = 0;
divider_thickness    = 2.0;
divider_height       = 40;


/* [06 - Bin Label Recess] */
add_label_recess_bin     = true;
label_bin_width          = 54;
label_bin_height         = 18;
label_bin_z_pos          = 18;
label_bin_corner_radius  = 3;


/* [07 - Lid Label Recess] */
add_label_recess_lid     = false;
label_lid_position       = "top"; // [top, front]
label_lid_width          = 54;
label_lid_height         = 18;
label_lid_x_pos          = 0;
label_lid_y_pos          = 0;
label_lid_corner_radius  = 3;


/* [08 - Wall Pattern] */
wall_style           = "plain"; // [plain, ribbed, perforated, honeycomb, diamond, vertical_slots]
wall_feature_size    = 8;
wall_feature_spacing = 14;      // edge-to-edge spacing for perforated, honeycomb, diamond
wall_feature_depth   = 1.0;
wall_start_z         = 10;
wall_top_margin      = 10;


/* [09 - Top Edge] */
top_edge_style       = "rim"; // [normal, rim]
top_edge_rim_width   = 2.0;
top_edge_rim_height  = 2.0;


/* [10 - Lid Top Indentation] */
add_lid_indentation       = false;
lid_indentation_style     = "oval"; // [oval, rounded_rectangle, stadium, diamond, rim]
lid_indentation_width     = 70;
lid_indentation_depth_y   = 40;
lid_indentation_cut_depth = 0.4;
lid_indentation_x_pos     = 0;
lid_indentation_y_pos     = 0;
lid_indentation_corner_radius = 8;
lid_indentation_rim_width     = 5;


/* [11 - Advanced Settings] */
label_depth          = 0.3;
stackable_clearance  = 0.1;
stackable_min_top_thickness = 0.8;

// Gridfinity reference dimensions
// 42 mm pitch. Bin body is 0.5 mm undersized overall for clearance.
// The bottom foot itself follows the reference profile and is not reduced by body clearance.
gf_pitch             = 42;
gf_body_clearance    = 0.50;   // total clearance over the full bin footprint, not per side
gf_foot_fit_clearance = 0.00;  // optional printer tuning for the foot only; keep 0 for true Gridfinity

gf_base_total_h      = 4.75;

// Gridfinity foot profile, matching the reference as taper -> straight -> taper.
// lower 45 degree chamfer: 35.6 -> 37.2 mm over 0.80 mm
// middle straight land: 37.2 mm for 1.80 mm
// upper 45 degree chamfer: 37.2 -> 41.5 mm over 2.15 mm
// total base height: 0.80 + 1.80 + 2.15 = 4.75 mm
gf_lower_chamfer_h   = 0.80;
gf_middle_straight_h = 1.80;
gf_upper_chamfer_h   = 2.15;

gf_foot_bottom_size  = 35.6;
gf_foot_middle_size  = 37.2;
gf_foot_top_size     = 41.5;
gf_foot_corner_r     = 3.75;


/* [Hidden] */
lid_gap_front        = 20;
label_style_margin   = 2;


// ============================================================================
// DERIVED VALUES
// ============================================================================

bottom_style_resolved = use_gridfinity ? "gridfinity" : bottom_style;

grid_bin_outer_w = gridfinity_x_units * gf_pitch - gf_body_clearance;
grid_bin_outer_d = gridfinity_y_units * gf_pitch - gf_body_clearance;

corner_radius_resolved =
    use_gridfinity ? gf_foot_corner_r :
    (corner_style == "square") ? 0 :
    (corner_style == "soft") ? 4 :
    (corner_style == "rounded") ? corner_radius :
    (corner_style == "industrial") ? 1.5 :
    corner_radius;

bin_outer_w = use_gridfinity ? grid_bin_outer_w : bin_width;
bin_outer_d = use_gridfinity ? grid_bin_outer_d : bin_depth;
bin_outer_h = bin_height;

bin_inner_w = bin_outer_w - 2 * wall_thickness;
bin_inner_d = bin_outer_d - 2 * wall_thickness;
bin_inner_h = bin_outer_h - bottom_thickness;

bin_outer_r = corner_radius_resolved;
bin_inner_r = max(0.01, bin_outer_r - wall_thickness);

divider_actual_h = min(divider_height, bin_inner_h);

lid_outer_w = bin_outer_w + 2 * (lid_clearance + lid_wall_thickness);
lid_outer_d = bin_outer_d + 2 * (lid_clearance + lid_wall_thickness);

lid_skirt_outer_w = lid_outer_w;
lid_skirt_outer_d = lid_outer_d;

lid_skirt_inner_w = lid_outer_w - 2 * lid_wall_thickness;
lid_skirt_inner_d = lid_outer_d - 2 * lid_wall_thickness;

lid_outer_r       = bin_outer_r + lid_clearance + lid_wall_thickness;
lid_skirt_outer_r = lid_outer_r;
lid_skirt_inner_r = max(0.01, lid_outer_r - lid_wall_thickness);

label_lid_front_z_pos = (lid_top_thickness + lid_overlap_depth) / 2;

stackable_recess_cut_depth = (bottom_style_resolved == "gridfinity") ? gf_base_total_h : foot_height;
stackable_backing_height   = stackable_recess_cut_depth + stackable_min_top_thickness;

pattern_z_min = max(bottom_thickness + 1, wall_start_z);
pattern_z_max = max(pattern_z_min, bin_outer_h - wall_top_margin);

label_keepout_x_min = -label_bin_width / 2 - label_style_margin;
label_keepout_x_max =  label_bin_width / 2 + label_style_margin;
label_keepout_z_min =  label_bin_z_pos - label_bin_height / 2 - label_style_margin;
label_keepout_z_max =  label_bin_z_pos + label_bin_height / 2 + label_style_margin;

// Gridfinity sanity checks
assert(gf_pitch == 42, "Gridfinity pitch must stay 42 mm.");
assert(gf_middle_straight_h >= 0, "Gridfinity profile heights exceed gf_base_total_h.");
assert(abs(gf_base_total_h - (gf_lower_chamfer_h + gf_middle_straight_h + gf_upper_chamfer_h)) < 0.001, "Gridfinity profile segment heights must add up to gf_base_total_h.");

// Export/build orientation fix
// Gridfinity foot geometry is generated downward from the bin floor so it does not get cut by the inner cavity.
// This lift moves the complete bin upward for preview/export, so the lowest Gridfinity contact face sits at Z=0.
gridfinity_export_lift = (bottom_style_resolved == "gridfinity") ? gf_base_total_h : 0;


// ============================================================================
// MODEL OUTPUT
// ============================================================================

translate([0, 0, gridfinity_export_lift])
    storage_bin();

if (add_lid) {
    translate([0, -(bin_outer_d / 2 + lid_outer_d / 2 + lid_gap_front), 0])
        lid();
}


// ============================================================================
// HELPERS
// ============================================================================

function centered_positions(span, pitch) =
    let(n = max(1, floor(span / pitch) + 1))
    [for (i = [0 : n - 1]) (-((n - 1) * pitch) / 2 + i * pitch)];

function front_label_clear(px, pz) =
    !(add_label_recess_bin &&
      px >= label_keepout_x_min && px <= label_keepout_x_max &&
      pz >= label_keepout_z_min && pz <= label_keepout_z_max);

function front_label_clear_with_margin(px, pz, half_w, half_h) =
    !(add_label_recess_bin &&
      px + half_w >= label_keepout_x_min &&
      px - half_w <= label_keepout_x_max &&
      pz + half_h >= label_keepout_z_min &&
      pz - half_h <= label_keepout_z_max);


// ============================================================================
// MAIN ASSEMBLY
// ============================================================================

module storage_bin() {
    union() {
        difference() {
            storage_bin_positive_geometry();
            storage_bin_cutouts();
        }

        if (add_dividers) {
            divider_system();
        }
    }
}

module storage_bin_positive_geometry() {
    union() {
        bin_outer_shell();

        if (wall_style == "ribbed") {
            wall_ribs();
        }

        if (top_edge_style == "rim") {
            top_edge_rim();
        }

        if (bottom_style_resolved == "perimeter") {
            perimeter_foot();
        }

        if (bottom_style_resolved == "cornered_perimeter") {
            cornered_perimeter_foot();
        }

        if (bottom_style_resolved == "gridfinity") {
            gridfinity_bottom_interface();
        }
    }
}

module storage_bin_cutouts() {
    bin_inner_cavity();

    if (add_label_recess_bin) {
        front_label_recess_bin();
    }

    if (wall_style == "perforated") {
        wall_perforations();
    }

    if (wall_style == "honeycomb") {
        wall_honeycomb_cutouts();
    }

    if (wall_style == "diamond") {
        wall_diamond_cutouts();
    }

    if (wall_style == "vertical_slots") {
        wall_vertical_slots();
    }
}

module lid() {
    difference() {
        union() {
            lid_top_plate();
            lid_skirt();

            if (stackable_lid) {
                lid_stackable_recess_backing();
            }
        }

        if (add_label_recess_lid) {
            lid_label_recess();
        }

        if (add_lid_indentation) {
            lid_top_indentation();
        }

        if (stackable_lid) {
            lid_stackable_recess();
        }
    }
}


// ============================================================================
// BIN BODY AND CUTOUTS
// ============================================================================

module bin_outer_shell() {
    linear_extrude(height = bin_outer_h)
        shape2d(bin_outer_w, bin_outer_d, bin_outer_r);
}

module bin_inner_cavity() {
    translate([0, 0, bottom_thickness])
        linear_extrude(height = bin_inner_h + 0.2)
            shape2d(bin_inner_w, bin_inner_d, bin_inner_r);
}

module front_label_recess_bin() {
    translate([0, bin_outer_d / 2 + 0.01, label_bin_z_pos])
        rotate([90, 0, 0])
            linear_extrude(height = label_depth + 0.05)
                rounded_rect_2d(label_bin_width, label_bin_height, label_bin_corner_radius);
}


// ============================================================================
// INTERNAL DIVIDERS
// ============================================================================

module divider_system() {
    if (divider_count_width > 0) width_dividers();
    if (divider_count_depth > 0) depth_dividers();
}

module width_dividers() {
    for (i = [1 : divider_count_width]) {
        x_pos = -bin_inner_w / 2 + i * (bin_inner_w / (divider_count_width + 1));
        translate([x_pos - divider_thickness / 2, -bin_inner_d / 2, bottom_thickness])
            cube([divider_thickness, bin_inner_d, divider_actual_h]);
    }
}

module depth_dividers() {
    for (i = [1 : divider_count_depth]) {
        y_pos = -bin_inner_d / 2 + i * (bin_inner_d / (divider_count_depth + 1));
        translate([-bin_inner_w / 2, y_pos - divider_thickness / 2, bottom_thickness])
            cube([bin_inner_w, divider_thickness, divider_actual_h]);
    }
}


// ============================================================================
// WALL STYLE: RIBBED
// ============================================================================

module wall_ribs() {
    rib_depth = max(0.6, wall_feature_depth);
    rib_w     = max(1, wall_feature_size);
    eps       = 0.02;

    z0    = pattern_z_min;
    rib_h = max(0, pattern_z_max - pattern_z_min);

    x_margin = bin_outer_r + rib_w / 2 + wall_feature_spacing / 2;
    y_margin = bin_outer_r + rib_w / 2 + wall_feature_spacing / 2;

    x_span = max(0, bin_outer_w - 2 * x_margin);
    y_span = max(0, bin_outer_d - 2 * y_margin);

    x_positions = centered_positions(x_span, wall_feature_spacing);
    y_positions = centered_positions(y_span, wall_feature_spacing);

    wall_ribs_front_and_back(x_positions, rib_w, rib_depth, eps, z0, rib_h);
    wall_ribs_left_and_right(y_positions, rib_w, rib_depth, eps, z0, rib_h);
}

module wall_ribs_front_and_back(x_positions, rib_w, rib_depth, eps, z0, rib_h) {
    for (xx = x_positions) {
        translate([xx, -bin_outer_d / 2 - rib_depth / 2 - eps / 2, z0 + rib_h / 2])
            cube([rib_w, rib_depth + eps, rib_h], center = true);

        if (!front_label_clear_with_margin(xx, (pattern_z_min + pattern_z_max) / 2, rib_w / 2, rib_h / 2)) {
            lower_top = min(pattern_z_max, label_keepout_z_min);
            lower_h   = max(0, lower_top - z0);

            if (lower_h > 0) {
                translate([xx, bin_outer_d / 2 + rib_depth / 2 + eps / 2, z0 + lower_h / 2])
                    cube([rib_w, rib_depth + eps, lower_h], center = true);
            }

            upper_bot = max(z0, label_keepout_z_max);
            upper_h   = max(0, pattern_z_max - upper_bot);

            if (upper_h > 0) {
                translate([xx, bin_outer_d / 2 + rib_depth / 2 + eps / 2, upper_bot + upper_h / 2])
                    cube([rib_w, rib_depth + eps, upper_h], center = true);
            }
        } else {
            translate([xx, bin_outer_d / 2 + rib_depth / 2 + eps / 2, z0 + rib_h / 2])
                cube([rib_w, rib_depth + eps, rib_h], center = true);
        }
    }
}

module wall_ribs_left_and_right(y_positions, rib_w, rib_depth, eps, z0, rib_h) {
    for (yy = y_positions) {
        translate([bin_outer_w / 2 + rib_depth / 2 + eps / 2, yy, z0 + rib_h / 2])
            cube([rib_depth + eps, rib_w, rib_h], center = true);
        translate([-bin_outer_w / 2 - rib_depth / 2 - eps / 2, yy, z0 + rib_h / 2])
            cube([rib_depth + eps, rib_w, rib_h], center = true);
    }
}


// ============================================================================
// WALL STYLE: PERFORATED
// ============================================================================

module wall_perforations() {
    feature_d  = wall_feature_size;
    hole_r     = feature_d / 2;
    x_pitch    = feature_d + wall_feature_spacing;
    z_pitch    = feature_d + wall_feature_spacing;
    row_offset = x_pitch / 2;
    keepout    = bin_outer_r + feature_d / 2 + wall_feature_spacing / 2;

    x_start = -bin_outer_w / 2 + keepout;
    x_end   =  bin_outer_w / 2 - keepout;
    y_start = -bin_outer_d / 2 + keepout;
    y_end   =  bin_outer_d / 2 - keepout;

    z_rows = [for (zz = [pattern_z_min + feature_d / 2 : z_pitch : pattern_z_max - feature_d / 2]) zz];

    perforations_front_and_back(z_rows, x_start, x_end, x_pitch, row_offset, hole_r);
    perforations_left_and_right(z_rows, y_start, y_end, x_pitch, row_offset, hole_r);
}

module perforations_front_and_back(z_rows, x_start, x_end, x_pitch, row_offset, hole_r) {
    for (row = [0 : len(z_rows) - 1]) {
        zz = z_rows[row];
        x0 = x_start + ((row % 2 == 0) ? 0 : row_offset);

        for (xx = [x0 : x_pitch : x_end]) {
            translate([xx, -bin_outer_d / 2 - 0.1, zz])
                rotate([-90, 0, 0])
                    cylinder(h = wall_thickness + 0.3, r = hole_r, center = false);

            if (front_label_clear_with_margin(xx, zz, hole_r, hole_r)) {
                translate([xx, bin_outer_d / 2 + 0.1, zz])
                    rotate([90, 0, 0])
                        cylinder(h = wall_thickness + 0.3, r = hole_r, center = false);
            }
        }
    }
}

module perforations_left_and_right(z_rows, y_start, y_end, x_pitch, row_offset, hole_r) {
    for (row = [0 : len(z_rows) - 1]) {
        zz = z_rows[row];
        y0 = y_start + ((row % 2 == 0) ? 0 : row_offset);

        for (yy = [y0 : x_pitch : y_end]) {
            translate([bin_outer_w / 2 + 0.1, yy, zz])
                rotate([0, 90, 0])
                    cylinder(h = wall_thickness + 0.3, r = hole_r, center = false);

            translate([-bin_outer_w / 2 - 0.1, yy, zz])
                rotate([0, -90, 0])
                    cylinder(h = wall_thickness + 0.3, r = hole_r, center = false);
        }
    }
}


// ============================================================================
// WALL STYLE: HONEYCOMB
// ============================================================================

module wall_honeycomb_cutouts() {
    feature_af = wall_feature_size;
    hex_r      = feature_af / sqrt(3);
    hex_w      = 2 * hex_r;
    x_pitch    = hex_w + wall_feature_spacing;
    z_pitch    = feature_af * 0.75 + wall_feature_spacing;
    keepout    = bin_outer_r + hex_w / 2 + wall_feature_spacing / 2;

    x_start = -bin_outer_w / 2 + keepout;
    x_end   =  bin_outer_w / 2 - keepout;
    y_start = -bin_outer_d / 2 + keepout;
    y_end   =  bin_outer_d / 2 - keepout;

    z_rows = [for (zz = [pattern_z_min + feature_af / 2 : z_pitch : pattern_z_max - feature_af / 2]) zz];

    honeycomb_front_and_back(z_rows, x_start, x_end, x_pitch, hex_w, feature_af, hex_r);
    honeycomb_left_and_right(z_rows, y_start, y_end, x_pitch, hex_r);
}

module honeycomb_front_and_back(z_rows, x_start, x_end, x_pitch, hex_w, feature_af, hex_r) {
    for (row = [0 : len(z_rows) - 1]) {
        zz = z_rows[row];
        x0 = x_start + ((row % 2 == 0) ? 0 : x_pitch / 2);

        for (xx = [x0 : x_pitch : x_end]) {
            translate([xx, -bin_outer_d / 2 - 0.1, zz])
                rotate([-90, 0, 0])
                    hex_cutout(hex_r);

            if (front_label_clear_with_margin(xx, zz, hex_w / 2, feature_af / 2)) {
                translate([xx, bin_outer_d / 2 + 0.1, zz])
                    rotate([90, 0, 0])
                        hex_cutout(hex_r);
            }
        }
    }
}

module honeycomb_left_and_right(z_rows, y_start, y_end, x_pitch, hex_r) {
    for (row = [0 : len(z_rows) - 1]) {
        zz = z_rows[row];
        y0 = y_start + ((row % 2 == 0) ? 0 : x_pitch / 2);

        for (yy = [y0 : x_pitch : y_end]) {
            translate([bin_outer_w / 2 + 0.1, yy, zz])
                rotate([0, 90, 0])
                    hex_cutout(hex_r);

            translate([-bin_outer_w / 2 - 0.1, yy, zz])
                rotate([0, -90, 0])
                    hex_cutout(hex_r);
        }
    }
}

module hex_cutout(hex_r) {
    linear_extrude(height = wall_thickness + 0.3)
        rotate(30)
            circle(r = hex_r, $fn = 6);
}


// ============================================================================
// WALL STYLE: DIAMOND
// ============================================================================

module wall_diamond_cutouts() {
    feature_w    = wall_feature_size;
    diamond_side = feature_w / sqrt(2);
    x_pitch      = feature_w + wall_feature_spacing;
    z_pitch      = feature_w + wall_feature_spacing;
    row_offset   = x_pitch / 2;
    keepout      = bin_outer_r + feature_w / 2 + wall_feature_spacing / 2;

    x_start = -bin_outer_w / 2 + keepout;
    x_end   =  bin_outer_w / 2 - keepout;
    y_start = -bin_outer_d / 2 + keepout;
    y_end   =  bin_outer_d / 2 - keepout;

    z_rows = [for (zz = [pattern_z_min + feature_w / 2 : z_pitch : pattern_z_max - feature_w / 2]) zz];

    diamond_front_and_back(z_rows, x_start, x_end, x_pitch, row_offset, feature_w, diamond_side);
    diamond_left_and_right(z_rows, y_start, y_end, x_pitch, row_offset, diamond_side);
}

module diamond_front_and_back(z_rows, x_start, x_end, x_pitch, row_offset, feature_w, diamond_side) {
    for (row = [0 : len(z_rows) - 1]) {
        zz = z_rows[row];
        x0 = x_start + ((row % 2 == 0) ? 0 : row_offset);

        for (xx = [x0 : x_pitch : x_end]) {
            translate([xx, -bin_outer_d / 2 - 0.1, zz])
                rotate([-90, 0, 0])
                    diamond_cutout(diamond_side);

            if (front_label_clear_with_margin(xx, zz, feature_w / 2, feature_w / 2)) {
                translate([xx, bin_outer_d / 2 + 0.1, zz])
                    rotate([90, 0, 0])
                        diamond_cutout(diamond_side);
            }
        }
    }
}

module diamond_left_and_right(z_rows, y_start, y_end, x_pitch, row_offset, diamond_side) {
    for (row = [0 : len(z_rows) - 1]) {
        zz = z_rows[row];
        y0 = y_start + ((row % 2 == 0) ? 0 : row_offset);

        for (yy = [y0 : x_pitch : y_end]) {
            translate([bin_outer_w / 2 + 0.1, yy, zz])
                rotate([0, 90, 0])
                    diamond_cutout(diamond_side);

            translate([-bin_outer_w / 2 - 0.1, yy, zz])
                rotate([0, -90, 0])
                    diamond_cutout(diamond_side);
        }
    }
}

module diamond_cutout(diamond_side) {
    linear_extrude(height = wall_thickness + 0.3)
        rotate(45)
            square([diamond_side, diamond_side], center = true);
}


// ============================================================================
// WALL STYLE: VERTICAL SLOTS
// ============================================================================

module wall_vertical_slots() {
    slot_w  = max(1, wall_feature_size / 3);
    slot_h  = wall_feature_size * 1.8;
    step_x  = slot_w + wall_feature_spacing;
    step_z  = slot_h + wall_feature_spacing;
    keepout = bin_outer_r + max(slot_w, slot_h) / 2 + wall_feature_spacing / 2;

    x_start = -bin_outer_w / 2 + keepout;
    x_end   =  bin_outer_w / 2 - keepout;
    y_start = -bin_outer_d / 2 + keepout;
    y_end   =  bin_outer_d / 2 - keepout;

    z_start = pattern_z_min + slot_h / 2;
    z_end   = pattern_z_max - slot_h / 2;

    vertical_slots_front_and_back(x_start, x_end, step_x, z_start, z_end, step_z, slot_w, slot_h);
    vertical_slots_left_and_right(y_start, y_end, step_x, z_start, z_end, step_z, slot_w, slot_h);
}

module vertical_slots_front_and_back(x_start, x_end, step_x, z_start, z_end, step_z, slot_w, slot_h) {
    for (xx = [x_start : step_x : x_end]) {
        for (zz = [z_start : step_z : z_end]) {
            translate([xx, -bin_outer_d / 2 - 0.1, zz])
                rotate([-90, 0, 0])
                    vertical_slot_cutout(slot_w, slot_h);

            if (front_label_clear_with_margin(xx, zz, slot_w / 2, slot_h / 2)) {
                translate([xx, bin_outer_d / 2 + 0.1, zz])
                    rotate([90, 0, 0])
                        vertical_slot_cutout(slot_w, slot_h);
            }
        }
    }
}

module vertical_slots_left_and_right(y_start, y_end, step_x, z_start, z_end, step_z, slot_w, slot_h) {
    for (yy = [y_start : step_x : y_end]) {
        for (zz = [z_start : step_z : z_end]) {
            translate([bin_outer_w / 2 + 0.1, yy, zz])
                rotate([0, 90, 0])
                    vertical_slot_cutout(slot_w, slot_h);

            translate([-bin_outer_w / 2 - 0.1, yy, zz])
                rotate([0, -90, 0])
                    vertical_slot_cutout(slot_w, slot_h);
        }
    }
}

module vertical_slot_cutout(slot_w, slot_h) {
    linear_extrude(height = wall_thickness + 0.3)
        rounded_rect_2d(slot_w, slot_h, slot_w / 2);
}


// ============================================================================
// TOP EDGE / RIM
// Fixed: keeps the bin opening clear when rim is enabled.
// Rim height is now the straight vertical rim height.
// The underside chamfer is added below the rim instead of being included in that height.
// ============================================================================

module top_edge_rim() {
    if (top_edge_rim_height > 0 && top_edge_rim_width > 0) {

        chamfer_h = min(top_edge_rim_width, top_edge_rim_height);

        // The straight rim starts at the top of the bin wall.
        // The chamfer is added below it and does not reduce the requested rim height.
        chamfer_z = bin_outer_h - chamfer_h;
        rim_z     = bin_outer_h;

        outer_w = bin_outer_w + 2 * top_edge_rim_width;
        outer_d = bin_outer_d + 2 * top_edge_rim_width;
        outer_r = bin_outer_r + top_edge_rim_width;

        total_rim_h = chamfer_h + top_edge_rim_height;

        difference() {
            union() {
                // Underside chamfer from normal bin wall size to wider rim size.
                hull() {
                    translate([0, 0, chamfer_z])
                        linear_extrude(height = 0.01)
                            shape2d(bin_outer_w, bin_outer_d, bin_outer_r);

                    translate([0, 0, rim_z])
                        linear_extrude(height = 0.01)
                            shape2d(outer_w, outer_d, outer_r);
                }

                // Straight rim section above the original bin height.
                translate([0, 0, rim_z])
                    linear_extrude(height = top_edge_rim_height)
                        shape2d(outer_w, outer_d, outer_r);
            }

            // Cut the real internal cavity through both the added chamfer and straight rim.
            translate([0, 0, chamfer_z - 0.05])
                linear_extrude(height = total_rim_h + 0.15)
                    shape2d(bin_inner_w, bin_inner_d, bin_inner_r);
        }
    }
}


// ============================================================================
// BOTTOM STYLE: PERIMETER FOOT
// ============================================================================

module perimeter_foot() {
    translate([0, 0, -foot_height])
        difference() {
            perimeter_foot_outer_2d(foot_height);
            perimeter_foot_inner_cutout_2d(foot_height);
        }
}

module perimeter_foot_outer_2d(extrude_h) {
    linear_extrude(height = extrude_h)
        shape2d(
            bin_outer_w - 2 * perimeter_foot_inset,
            bin_outer_d - 2 * perimeter_foot_inset,
            max(0.01, bin_outer_r - perimeter_foot_inset)
        );
}

module perimeter_foot_inner_cutout_2d(extrude_h) {
    translate([0, 0, -0.05])
        linear_extrude(height = extrude_h + 0.1)
            shape2d(
                max(1, bin_outer_w - 2 * perimeter_foot_inset - 2 * perimeter_foot_width),
                max(1, bin_outer_d - 2 * perimeter_foot_inset - 2 * perimeter_foot_width),
                max(0.01, bin_outer_r - perimeter_foot_inset - perimeter_foot_width)
            );
}


// ============================================================================
// BOTTOM STYLE: CORNERED PERIMETER FOOT
// ============================================================================

module cornered_perimeter_foot() {
    corner_len = max(0.01, 2 * bin_outer_r);

    translate([0, 0, -foot_height])
        intersection() {
            difference() {
                perimeter_foot_outer_2d(foot_height);
                perimeter_foot_inner_cutout_2d(foot_height);
            }

            cornered_perimeter_mask(corner_len, foot_height);
        }
}

module cornered_perimeter_mask(corner_len, mask_h) {
    mask_w = max(0.01, corner_len);
    mask_d = max(0.01, corner_len);

    for (sx = [-1, 1]) {
        for (sy = [-1, 1]) {
            translate([
                sx * ((bin_outer_w - 2 * perimeter_foot_inset) / 2 - mask_w / 2),
                sy * ((bin_outer_d - 2 * perimeter_foot_inset) / 2 - mask_d / 2),
                mask_h / 2
            ])
                cube([mask_w, mask_d, mask_h + 0.1], center = true);
        }
    }
}


// ============================================================================
// BOTTOM STYLE: GRIDFINITY BASE
// ============================================================================

module gridfinity_bottom_interface() {
    for (gx = [0 : gridfinity_x_units - 1]) {
        for (gy = [0 : gridfinity_y_units - 1]) {
            translate([
                (gx - (gridfinity_x_units - 1) / 2) * gf_pitch,
                (gy - (gridfinity_y_units - 1) / 2) * gf_pitch,
                0
            ])
                gridfinity_foot();
        }
    }
}

module gridfinity_foot() {
    // Correct Gridfinity foot profile: taper -> straight -> taper.
    // There is no straight bottom land. The profile starts with the lower 45-degree taper,
    // then a straight 37.2 mm middle land, then the upper taper to the 41.5 mm top.

    bottom_size = gf_foot_bottom_size - 2 * gf_foot_fit_clearance;
    middle_size = gf_foot_middle_size - 2 * gf_foot_fit_clearance;
    top_size    = gf_foot_top_size    - 2 * gf_foot_fit_clearance;

    bottom_r = min(gf_foot_corner_r, bottom_size / 2 - 0.01);
    middle_r = min(gf_foot_corner_r, middle_size / 2 - 0.01);
    top_r    = min(gf_foot_corner_r, top_size / 2 - 0.01);

    // Built downward from the bin floor, then lifted at model output.
    // After export lift:
    // z0 = 0.00  bottom contact face, 35.6 mm
    // z1 = 0.80  end of lower taper, 37.2 mm
    // z2 = 2.60  end of straight middle land, 37.2 mm
    // z3 = 4.75  top face joins bin body, 41.5 mm
    z0 = -gf_base_total_h;
    z1 = z0 + gf_lower_chamfer_h;
    z2 = z1 + gf_middle_straight_h;
    z3 = 0;

    union() {
        // Lower 45-degree chamfer: 35.6 -> 37.2 mm.
        hull() {
            translate([0, 0, z0])
                linear_extrude(height = 0.01)
                    rounded_rect_2d(bottom_size, bottom_size, bottom_r);

            translate([0, 0, z1])
                linear_extrude(height = 0.01)
                    rounded_rect_2d(middle_size, middle_size, middle_r);
        }

        // Middle straight land: constant 37.2 mm.
        translate([0, 0, z1])
            linear_extrude(height = gf_middle_straight_h)
                rounded_rect_2d(middle_size, middle_size, middle_r);

        // Upper 45-degree chamfer: 37.2 -> 41.5 mm.
        hull() {
            translate([0, 0, z2])
                linear_extrude(height = 0.01)
                    rounded_rect_2d(middle_size, middle_size, middle_r);

            translate([0, 0, z3])
                linear_extrude(height = 0.01)
                    rounded_rect_2d(top_size, top_size, top_r);
        }
    }
}


// ============================================================================
// LID STACKING BACKING
// ============================================================================

module lid_stackable_recess_backing() {
    if (bottom_style_resolved == "perimeter") lid_stackable_perimeter_backing();
    if (bottom_style_resolved == "cornered_perimeter") lid_stackable_cornered_perimeter_backing();
    if (bottom_style_resolved == "gridfinity") lid_stackable_gridfinity_backing();
}

module lid_stackable_perimeter_backing() {
    linear_extrude(height = stackable_backing_height)
        shape2d(
            bin_outer_w - 2 * perimeter_foot_inset + 2 * stackable_clearance + 2 * stackable_min_top_thickness,
            bin_outer_d - 2 * perimeter_foot_inset + 2 * stackable_clearance + 2 * stackable_min_top_thickness,
            max(0.01, bin_outer_r - perimeter_foot_inset + stackable_clearance + stackable_min_top_thickness)
        );
}

module lid_stackable_cornered_perimeter_backing() {
    corner_len = max(0.01, 2 * bin_outer_r);

    intersection() {
        lid_stackable_perimeter_backing();
        cornered_perimeter_mask(corner_len + 2 * stackable_clearance + 2 * stackable_min_top_thickness, stackable_backing_height);
    }
}

module lid_stackable_gridfinity_backing() {
    backing_size = gf_foot_top_size - 2 * gf_foot_fit_clearance + 2 * stackable_clearance + 2 * stackable_min_top_thickness;
    backing_r    = min(gf_foot_corner_r + stackable_clearance + stackable_min_top_thickness, backing_size / 2 - 0.01);

    for (gx = [0 : gridfinity_x_units - 1]) {
        for (gy = [0 : gridfinity_y_units - 1]) {
            translate([
                (gx - (gridfinity_x_units - 1) / 2) * gf_pitch,
                (gy - (gridfinity_y_units - 1) / 2) * gf_pitch,
                0
            ])
                linear_extrude(height = stackable_backing_height)
                    rounded_rect_2d(backing_size, backing_size, backing_r);
        }
    }
}


// ============================================================================
// LID STACKING POCKET
// ============================================================================

module lid_stackable_recess() {
    if (bottom_style_resolved == "perimeter") lid_stackable_perimeter_recess();
    if (bottom_style_resolved == "cornered_perimeter") lid_stackable_cornered_perimeter_recess();
    if (bottom_style_resolved == "gridfinity") lid_stackable_gridfinity_recess();
}

module lid_stackable_perimeter_recess() {
    translate([0, 0, -0.01])
        difference() {
            lid_stackable_perimeter_outer_2d(stackable_recess_cut_depth + 0.05);
            lid_stackable_perimeter_inner_cutout_2d(stackable_recess_cut_depth + 0.05);
        }
}

module lid_stackable_cornered_perimeter_recess() {
    corner_len = max(0.01, 2 * bin_outer_r);

    translate([0, 0, -0.01])
        intersection() {
            difference() {
                lid_stackable_perimeter_outer_2d(stackable_recess_cut_depth + 0.05);
                lid_stackable_perimeter_inner_cutout_2d(stackable_recess_cut_depth + 0.05);
            }

            cornered_perimeter_mask(corner_len + 2 * stackable_clearance, stackable_recess_cut_depth + 0.05);
        }
}

module lid_stackable_perimeter_outer_2d(extrude_h) {
    linear_extrude(height = extrude_h)
        shape2d(
            bin_outer_w - 2 * perimeter_foot_inset + 2 * stackable_clearance,
            bin_outer_d - 2 * perimeter_foot_inset + 2 * stackable_clearance,
            max(0.01, bin_outer_r - perimeter_foot_inset + stackable_clearance)
        );
}

module lid_stackable_perimeter_inner_cutout_2d(extrude_h) {
    translate([0, 0, -0.05])
        linear_extrude(height = extrude_h + 0.1)
            shape2d(
                max(1, bin_outer_w - 2 * perimeter_foot_inset - 2 * perimeter_foot_width - 2 * stackable_clearance),
                max(1, bin_outer_d - 2 * perimeter_foot_inset - 2 * perimeter_foot_width - 2 * stackable_clearance),
                max(0.01, bin_outer_r - perimeter_foot_inset - perimeter_foot_width - stackable_clearance)
            );
}

module lid_stackable_gridfinity_recess() {
    for (gx = [0 : gridfinity_x_units - 1]) {
        for (gy = [0 : gridfinity_y_units - 1]) {
            translate([
                (gx - (gridfinity_x_units - 1) / 2) * gf_pitch,
                (gy - (gridfinity_y_units - 1) / 2) * gf_pitch,
                -0.01
            ])
                lid_stackable_gridfinity_foot_recess();
        }
    }
}

module lid_stackable_gridfinity_foot_recess() {
    bottom_size = gf_foot_bottom_size - 2 * gf_foot_fit_clearance + 2 * stackable_clearance;
    middle_size = gf_foot_middle_size - 2 * gf_foot_fit_clearance + 2 * stackable_clearance;
    top_size    = gf_foot_top_size    - 2 * gf_foot_fit_clearance + 2 * stackable_clearance;

    bottom_r = min(gf_foot_corner_r + stackable_clearance, bottom_size / 2 - 0.01);
    middle_r = min(gf_foot_corner_r + stackable_clearance, middle_size / 2 - 0.01);
    top_r    = min(gf_foot_corner_r + stackable_clearance, top_size / 2 - 0.01);

    // The lid is generated upside down for printing:
    // z = 0 is the visible top face of the lid, and the recess cuts upward into the printed part.
    // Therefore this pocket must be the inverse of the bin foot in Z.
    // Surface opening: 41.5 mm. Deepest point: 35.6 mm.
    z0 = 0;
    z1 = z0 + gf_upper_chamfer_h;
    z2 = z1 + gf_middle_straight_h;
    z3 = gf_base_total_h;

    union() {
        // Reversed upper taper pocket: large opening 41.5 mm -> 37.2 mm.
        hull() {
            translate([0, 0, z0])
                linear_extrude(height = 0.01)
                    rounded_rect_2d(top_size, top_size, top_r);

            translate([0, 0, z1])
                linear_extrude(height = 0.01)
                    rounded_rect_2d(middle_size, middle_size, middle_r);
        }

        // Straight middle pocket: constant 37.2 mm.
        translate([0, 0, z1])
            linear_extrude(height = gf_middle_straight_h)
                rounded_rect_2d(middle_size, middle_size, middle_r);

        // Reversed lower taper pocket: 37.2 mm -> deepest 35.6 mm.
        hull() {
            translate([0, 0, z2])
                linear_extrude(height = 0.01)
                    rounded_rect_2d(middle_size, middle_size, middle_r);

            translate([0, 0, z3])
                linear_extrude(height = 0.01)
                    rounded_rect_2d(bottom_size, bottom_size, bottom_r);
        }
    }
}



// ============================================================================
// LID TOP INDENTATION
// ============================================================================

module lid_top_indentation() {
    translate([lid_indentation_x_pos, lid_indentation_y_pos, -0.01])
        linear_extrude(height = lid_indentation_cut_depth + 0.05)
            lid_top_indentation_shape_2d();
}

module lid_top_indentation_shape_2d() {
    if (lid_indentation_style == "oval") oval_2d(lid_indentation_width, lid_indentation_depth_y);

    if (lid_indentation_style == "rounded_rectangle") {
        rounded_rect_2d(lid_indentation_width, lid_indentation_depth_y, lid_indentation_corner_radius);
    }

    if (lid_indentation_style == "stadium") {
        rounded_rect_2d(
            lid_indentation_width,
            lid_indentation_depth_y,
            min(lid_indentation_width, lid_indentation_depth_y) / 2 - 0.01
        );
    }

    if (lid_indentation_style == "diamond") diamond_2d(lid_indentation_width, lid_indentation_depth_y);

    if (lid_indentation_style == "rim") lid_top_indentation_rim_2d();
}

module lid_top_indentation_rim_2d() {
    difference() {
        rounded_rect_2d(lid_indentation_width, lid_indentation_depth_y, lid_indentation_corner_radius);
        rounded_rect_2d(
            max(1, lid_indentation_width - 2 * lid_indentation_rim_width),
            max(1, lid_indentation_depth_y - 2 * lid_indentation_rim_width),
            max(0.01, lid_indentation_corner_radius - lid_indentation_rim_width)
        );
    }
}


// ============================================================================
// LID BODY AND LABELS
// ============================================================================

module lid_top_plate() {
    linear_extrude(height = lid_top_thickness)
        shape2d(lid_outer_w, lid_outer_d, lid_outer_r);
}

module lid_skirt() {
    translate([0, 0, lid_top_thickness])
        difference() {
            linear_extrude(height = lid_overlap_depth)
                shape2d(lid_skirt_outer_w, lid_skirt_outer_d, lid_skirt_outer_r);

            translate([0, 0, -0.05])
                linear_extrude(height = lid_overlap_depth + 0.1)
                    shape2d(lid_skirt_inner_w, lid_skirt_inner_d, lid_skirt_inner_r);
        }
}

module lid_label_recess() {
    if (label_lid_position == "top") lid_label_recess_top();
    if (label_lid_position == "front") lid_label_recess_front();
}

module lid_label_recess_top() {
    translate([label_lid_x_pos, label_lid_y_pos, -0.01])
        linear_extrude(height = label_depth + 0.05)
            rounded_rect_2d(label_lid_width, label_lid_height, label_lid_corner_radius);
}

module lid_label_recess_front() {
    translate([0, lid_outer_d / 2 + 0.01, label_lid_front_z_pos])
        rotate([90, 0, 0])
            linear_extrude(height = label_depth + 0.05)
                rounded_rect_2d(
                    label_lid_width,
                    label_lid_height,
                    min(label_lid_corner_radius, label_lid_height / 2 - 0.01)
                );
}


// ============================================================================
// SHARED 2D PROFILES
// ============================================================================

module shape2d(w, d, r) {
    if (r <= 0) {
        square([w, d], center = true);
    } else {
        rounded_rect_2d(w, d, r);
    }
}

module oval_2d(w, d) {
    scale([w / 2, d / 2])
        circle(r = 1);
}

module diamond_2d(w, d) {
    polygon(points = [
        [0, d / 2],
        [w / 2, 0],
        [0, -d / 2],
        [-w / 2, 0]
    ]);
}

module rounded_rect_2d(w, d, r) {
    rr = min(r, min(w, d) / 2 - 0.01);

    hull() {
        translate([ w / 2 - rr,  d / 2 - rr]) circle(r = rr);
        translate([-w / 2 + rr,  d / 2 - rr]) circle(r = rr);
        translate([-w / 2 + rr, -d / 2 + rr]) circle(r = rr);
        translate([ w / 2 - rr, -d / 2 + rr]) circle(r = rr);
    }
}

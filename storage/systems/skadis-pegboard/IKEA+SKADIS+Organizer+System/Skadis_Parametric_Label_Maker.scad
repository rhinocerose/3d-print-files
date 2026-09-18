// =======================================================
// Label Creator for SKÅDIS Organizer System
// =======================================================

// ===============================
// Visible user parameters (ordered)
// ===============================

// Label size options
// Options: "S", "M", "L", "XL", "XXL"
Size = "S";

// Text size options
// Options: "S", "M", "L"
Text_Size = "L";

// Number of labels to generate (1–10)
Count = 1;  // increase to add more labels vertically

Label_1 = "Label 1";
Label_2 = "Label 2";
Label_3 = "Label 3";
Label_4 = "Label 4";
Label_5 = "Label 5";
Label_6 = "Label 6";
Label_7 = "Label 7";
Label_8 = "Label 8";
Label_9 = "Label 9";
Label_10 = "Label 10";


// ===============================
// Internal, non-editable values
// ===============================
/* [Hidden] */

Font = "Rubik";           // Fixed font
corner_radius = 1;        // mm corner radius
corner_segments = 32;     // smooth corners
Spacing = 5;              // vertical distance between labels

// --- Helper function: clamp ---
function clamp(v, vmin, vmax) = max(vmin, min(v, vmax));

// --- Map text size option to numeric value ---
function get_text_size(opt) =
    (opt == "S" || opt == "s") ? 4.5 :
    (opt == "M" || opt == "m") ? 5.0 :
    (opt == "L" || opt == "l") ? 5.5 :
                                 5.0; // fallback

Text_Size_Value = get_text_size(Text_Size);

// --- Label dimensions based on preset ---
function get_label_length(s) =
    (s == "S"   || s == "s")   ? 30 :
    (s == "M"   || s == "m")   ? 70 :
    (s == "L"   || s == "l")   ? 110 :
    (s == "XL"  || s == "xl")  ? 150 :
    (s == "XXL" || s == "xxl") ? 190 :
                                 30; // fallback

label_length = get_label_length(Size);
label_width  = 11;
label_height = 0.8;
text_height  = 0.4;

// --- Collect visible labels into a list ---
Texts = [
    Label_1, Label_2, Label_3, Label_4, Label_5,
    Label_6, Label_7, Label_8, Label_9, Label_10
];


// ===============================
// Geometry modules
// ===============================

module Label_Plate() {
    color("White")
        translate([-label_length/2, -label_width/2, 0])
            linear_extrude(height = label_height)
                hull() {
                    translate([corner_radius, corner_radius])
                        circle(r = corner_radius, $fn = corner_segments);
                    translate([label_length - corner_radius, corner_radius])
                        circle(r = corner_radius, $fn = corner_segments);
                    translate([corner_radius, label_width - corner_radius])
                        circle(r = corner_radius, $fn = corner_segments);
                    translate([label_length - corner_radius, label_width - corner_radius])
                        circle(r = corner_radius, $fn = corner_segments);
                }
}

module Label_Text(t) {
    color("Black")
        translate([0, 0, label_height])
            linear_extrude(height = text_height)
                text(t,
                     size = Text_Size_Value,
                     font = Font,
                     halign = "center",
                     valign = "center");
}


// ===============================
// Render output (color-separated for multi-material export)
// ===============================

n = clamp(Count, 1, len(Texts));
total_height = n * label_width + (n - 1) * Spacing;
start_offset = total_height / 2 - label_width / 2;

// Generate both color layers (plates + text) separately at top-level
for (i = [0 : n - 1]) {
    offset = -(i * (label_width + Spacing) - start_offset);
    
    // Base plate (white)
    translate([0, offset, 0])
        Label_Plate();
    
    // Text (black)
    translate([0, offset, 0])
        Label_Text(Texts[i]);
}

// resolution or number of sides for circles
$fn = 90+0; 
// Width of print bed
t_bed_width = 220 ;
// Depth of print bed
t_bed_depth = 220;
// Shape to be printed at test points ("circle" or "square")
t_shape = "square";  //[circle,square]
// Print extra shape in center?
t_shape_center = "false"; // [true,false]
// Number of test columns
t_shape_xcount = 11; // [0,1,2,3,4,5,6,7,8,9,10]
// Number of test rows
t_shape_ycount = 11; // [0,1,2,3,4,5,6,7,8,9,10]
// Width of test shape
t_shape_xsize = 10; // width of shape or diameter of circle
// Depth of test shape
t_shape_ysize = 10; // depth of shape
// Width of connecting grid
t_line_width = 1.6; // 1.6 works well, 0 to skip
// Thickness of test print
t_thickness = 0.2; // layer height
// Safety border around edges of bed
t_bed_border = 5; // safety margin around edge of bed

/* [Hidden] */
t_print_width = t_bed_width - t_shape_xsize - (2*t_bed_border);
t_print_depth = t_bed_depth - t_shape_ysize - (2*t_bed_border);

// Bed size
//%square([t_bed_width, t_bed_depth]); 

// Grid area
translate([t_bed_width/2,t_bed_depth/2]){
    %square([t_print_width,t_print_depth], true);
}

// Print area
translate([t_bed_width/2,t_bed_depth/2]){
    %square([t_bed_width-(2*t_bed_border),t_bed_depth-(2*t_bed_border)], true);
}

linear_extrude(height = t_thickness) { 
    // shift everything to center in print area
    translate([(t_shape_xsize/2)+t_bed_border,(t_shape_ysize/2)+t_bed_border,0]){
        // intervals between printed shapes
        t_increment_x = t_print_width / (t_shape_xcount-1);
        t_increment_y = t_print_depth / (t_shape_ycount-1);
        t_center_x = 0;
        t_center_y = 0;
    
        // draw grid
        // draw horizontal lines along X axis
        if(t_shape_ycount > 0) {
            for(t_curr_x = [0:t_shape_xcount-1]){
                translate([t_center_x, t_print_depth/2, 0]){
                    square([t_line_width,t_print_depth], true);
                }
                t_center_x = t_curr_x * t_increment_x;
            }
        }
        if(t_shape_xcount > 0 ) {
            // draw vertical lines along Y axis
            for(t_curr_y = [0:t_shape_ycount-1]){
                translate([t_print_width/2, t_center_y, 0]){
                    square([t_print_width, t_line_width], true);
                }
                t_center_y = t_curr_y * t_increment_y;
            }
        }
        // draw shapes
        if(t_shape_xcount > 0){
            t_center_x = 0;
            for(t_curr_x = [0:t_shape_xcount-1]){
                t_center_y = 0;
                for(t_curr_y = [0:t_shape_ycount-1]){
                    translate([t_center_x,t_center_y]){
                        if (t_shape == "circle") { 
                            circle(d=t_shape_xsize);
                            } else { 
                           square([t_shape_xsize,t_shape_ysize],true);
                        }
                    }
                    t_center_y = t_curr_y * t_increment_y;
                }
                t_center_x = t_curr_x * t_increment_x;
            }
        }
        // print bed center shape and grid if enabled
        if(t_shape_center == "true" ) {
            t_center_x= (t_bed_width-(2*t_bed_border )-(t_shape_xsize)) /2;
            t_center_y=(t_bed_depth-(2*t_bed_border )-(t_shape_ysize)) /2;
             translate([t_center_x,t_center_y]){
                if (t_shape == "circle") { 
                   circle(d=t_shape_xsize);
                } else { 
                   square([t_shape_xsize,t_shape_ysize],true);
                }
            }
            if(t_shape_ycount > 0){
                // draw horizontal lines along X axis
                translate([t_center_x, t_print_depth/2, 0]){
                    square([t_line_width,t_print_depth], true);
                }
            }
            if(t_shape_xcount > 0){
                // draw vertical lines along Y axis
                translate([t_print_width/2, t_center_y, 0]){
                    square([t_print_width, t_line_width], true);
                }
            }
        }
    }
}
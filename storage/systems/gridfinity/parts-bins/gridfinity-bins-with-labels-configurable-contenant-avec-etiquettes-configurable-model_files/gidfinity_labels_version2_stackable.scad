number_of_block_x = 1;
number_of_block_y = 1;
number_of_block_z = 3;
label = "Magnet 4x2";
font_size = 5;

base();
container();
stackable_lip();
difference() {
    lid();
    place_text();
}


standard_size = 41.5;
// Constants for base
bottom_size = 35.6;
bottom_diameter = 1.6;
bottom_z = .8;

mid_size = bottom_size + 1.6;
mid_diameter = 3.2;
mid_z = 1.8;

top_size = standard_size;
top_diameter = 7.5;
top_z = 2.15;



last_z = 7 - top_z - mid_z - bottom_z;
last_size_x = number_of_block_x * standard_size;
last_size_y = number_of_block_y * standard_size;

// Constants for stackable lip
stack_lip_z = 4.4;

// Constants for lid
lid_size_y = standard_size/3;

container_z = number_of_block_z * 7;

module place_text() {
    translate([
        last_size_x / 2 - standard_size/2 ,
        last_size_y - standard_size/2 - lid_size_y/2 ,
        bottom_z + mid_z + top_z + last_z + container_z - 0.5
    ]) {
        linear_extrude(0.6)
        text( label, size= font_size, ,halign = "center", valign = "center");
    }
}

module lid() {
    lid_size_z = 1;
    
    // This is the lid
    color("yellow", 1.0)
    translate([
        last_size_x / 2 - standard_size/2 ,
        last_size_y - standard_size/2 - lid_size_y/2 ,
        bottom_z + mid_z + top_z + last_z +container_z-lid_size_z
    ]) {
        custom_rectangle(
            size_z = lid_size_z,
            base_size_x1 = last_size_x,
            base_size_y1 = lid_size_y,
            diameter1 = top_diameter,
            round_corner_x0_y0 = true,
            round_corner_x1_y0 = true,
            round_corner_x2_y2 = true,
            round_corner_x3_y2 = true
        );
    }
    
    // This is the chamfer
    translate([
        last_size_x / 2 - standard_size/2 ,
        last_size_y - standard_size/2 - lid_size_y/2 ,
        bottom_z + mid_z + top_z + last_z +container_z-lid_size_z
    ]) {
        difference() {
            rotate([0,180, 180]) {
                intersection() {
                    color("plum", 1.0)
                    
                    // First a triangle for the 45 degrees angle
                    custom_triangle(
                        size_z = lid_size_y,
                        base_size_x = last_size_x,
                        base_size_y = lid_size_y
                    );
                    
                // Intersection for the corners
                custom_rectangle(
                    size_z = lid_size_z*1000,
                    base_size_x1 = last_size_x,
                    base_size_y1 = lid_size_y,
                    diameter1 = top_diameter,
                    round_corner_x0_y0 = true,
                    round_corner_x1_y0 = true,
                    round_corner_x2_y2 = true,
                    round_corner_x3_y2 = true
                );
                    
                }
            }
            translate([
                - last_size_x / 2 + standard_size/2 ,
                - last_size_y / 2 + lid_size_y/2 ,
                - bottom_z - mid_z - top_z - last_z - container_z + lid_size_z
            ]) 
            cube([last_size_x*2, last_size_y*2, 7*2], center = true);
        }
    }
         
}

module stackable_lip() {
    color("grey", 1.0)
    translate([last_size_x / 2 - standard_size/2 ,last_size_y / 2 - standard_size/2 ,bottom_z + mid_z + top_z + last_z +container_z]) {
        difference() {
            custom_rectangle(
                size_z = stack_lip_z,
                base_size_x1 = last_size_x,
                base_size_y1 = last_size_y,
                diameter1 = top_diameter,
                base_size_x2 = last_size_x,
                base_size_y2 = last_size_y,               
                diameter2 = top_diameter
            );
            translate([0,0,-0.01])
            custom_rectangle(
                size_z = stack_lip_z+0.02,
                base_size_x1 = last_size_x - stack_lip_z,
                base_size_y1 = last_size_y - stack_lip_z,
                diameter1 = top_diameter,
                base_size_x2 = last_size_x,
                base_size_y2 = last_size_y,               
                diameter2 = top_diameter
            );
        }
    }     
    
}

module container() {
    color("purple", 1.0)
    translate([last_size_x / 2 - standard_size/2 ,last_size_y / 2 - standard_size/2 ,bottom_z + mid_z + top_z + last_z]) {
        difference() {
            custom_rectangle(
                size_z = container_z,
                base_size_x1 = last_size_x,
                base_size_y1 = last_size_y,
                diameter1 = top_diameter,
                base_size_x2 = last_size_x,
                base_size_y2 = last_size_y,               
                diameter2 = top_diameter
            );
            custom_rectangle(
                size_z = container_z*2,
                base_size_x1 = last_size_x - stack_lip_z,
                base_size_y1 = last_size_y - stack_lip_z,
                diameter1 = top_diameter,
                base_size_x2 = last_size_x - stack_lip_z,
                base_size_y2 = last_size_y - stack_lip_z,               
                diameter2 = top_diameter,
                sphere_corner = true
            );
        }
    }

}

module base() {
    for ( i = [0 : number_of_block_x - 1] ) {
        for ( y = [0 : number_of_block_y - 1] ) {
            translate([i * standard_size, y * standard_size]) {
                first_base();
                second_base();
                third_base();
            }
        }
        forth_base();
    }
}

module first_base() {
    color("blue", 1.0)
    custom_rectangle(
        size_z = bottom_z,
        base_size_x1 = bottom_size,
        base_size_y1 = bottom_size,
        diameter1 = bottom_diameter,
        base_size_x2 = mid_size,
        base_size_y2 = mid_size,        
        diameter2 = mid_diameter
    );
}

module second_base() {
    color("red", 1.0)
    translate([0,0,bottom_z]) {
        custom_rectangle(
            size_z = mid_z,
            base_size_x1 = mid_size,
            base_size_y1 = mid_size,
            diameter1 = mid_diameter,
            base_size_x2 = mid_size,
            base_size_y2 = mid_size,               
            diameter2 = mid_diameter
        );
    }
}

module third_base() {
    color("orange", 1.0)
    translate([0,0,bottom_z + mid_z]) {
        custom_rectangle(
            size_z = top_z,
            base_size_x1 = mid_size,
            base_size_y1 = mid_size,
            diameter1 = mid_diameter,
            base_size_x2 = top_size,
            base_size_y2 = top_size,               
            diameter2 = top_diameter
        );
    }    
}

module forth_base() {
    color("green", 1.0)
    translate([last_size_x / 2 - standard_size/2 ,last_size_y / 2 - standard_size/2 ,bottom_z + mid_z + top_z]) {
        custom_rectangle(
            size_z = last_z,
            base_size_x1 = last_size_x,
            base_size_y1 = last_size_y,
            diameter1 = top_diameter,
            base_size_x2 = last_size_x,
            base_size_y2 = last_size_y,               
            diameter2 = top_diameter
        );
    }    
}

module custom_triangle(
    size_z,                         // Heigth on Z axis
    base_size_x,                    // Size on X axis
    base_size_y,                    // Size on Y axis 
) {
   
    // Coordinates for of the corners
    
    x0_y0 = -base_size_x/2;
    y0_x0 = -base_size_y/2;
    
    x1_y0 = base_size_x/2;
    y0_x1 = -base_size_y/2;
    
    x1_y1 = base_size_x/2;
    y1_x1 = base_size_y/2;
    
    x0_y1 = -base_size_x/2;
    y1_x0 = base_size_y/2;
    
    x2_y2 = -base_size_x/2;
    y2_x2 = -base_size_y/2;
    
    x2_y3 = base_size_x/2;
    y3_x2 = -base_size_y/2;

    height = 0.001;
    
    $fn = 20;
    
    // Create figure
    hull() {
        
        // bottom
        color("blue", 1.0)
        translate([x0_y0,y0_x0,0])
            cylinder(h = height, d = 0.001);
        translate([x1_y0,y0_x1,0])
            cylinder(h = height, d = 0.001);
        translate([x1_y1,y1_x1,0])
            cylinder(h = height, d = 0.001);
        translate([x0_y1,y1_x0,0])
            cylinder(h = height, d = 0.001);
        
        // top
        color("orange", 1.0)
        translate([x2_y2,y2_x2,size_z])        
            cylinder(h = height, d = 0.001);
        translate([x2_y3,y3_x2,size_z])
            cylinder(h = height, d = 0.001);;
    }
    
}


module custom_rectangle(
    size_z,                 // Heigth on Z axis
    base_size_x1,           // Bottom size on X axis
    base_size_y1,           // Bottom size on Y axis 
    diameter1,              // Diameter for bottom round corner 
    base_size_x2,           // Top size on X axis (optional)
    base_size_y2,           // Top size on Y axis (optional)
    diameter2,              // Diameter for top round corner (optional)
    sphere_corner = false,  // Sphere or cylinder
    round_corner_x0_y0 = true,      // bottom low left     
    round_corner_x0_y1 = true,      // bottom high left
    round_corner_x1_y1 = true,      // bottom high right
    round_corner_x1_y0 = true,      // bottom low right 
    round_corner_x2_y2 = true,      // top low left 
    round_corner_x2_y3 = true,      // top high left 
    round_corner_x3_y3 = true,      // top high right
    round_corner_x3_y2 = true       // top low right
    
) {
    // set default value if not provided
    base_size_x2 = is_undef(base_size_x2) ? base_size_x1 : base_size_x2;
    base_size_y2 = is_undef(base_size_y2) ? base_size_y1 : base_size_y2;
    diameter2 = is_undef(diameter2) ? diameter1 : diameter2;

    // set diameters
    diameter_x0_y0 = round_corner_x0_y0 ? diameter1 : 0.001;
    diameter_x0_y1 = round_corner_x0_y1 ? diameter1 : 0.001;
    diameter_x1_y1 = round_corner_x1_y1 ? diameter1 : 0.001;
    diameter_x1_y0 = round_corner_x1_y0 ? diameter1 : 0.001;
    
    diameter_x2_y2 = round_corner_x2_y2 ? diameter2 : 0.001;
    diameter_x2_y3 = round_corner_x2_y3 ? diameter2 : 0.001;
    diameter_x3_y3 = round_corner_x3_y3 ? diameter2 : 0.001;
    diameter_x3_y2 = round_corner_x3_y2 ? diameter2 : 0.001;

    
    // Coordinates for bottom of the shape
    
    x0_y0 = -base_size_x1/2 + diameter_x0_y0/2;
    y0_x0 = -base_size_y1/2 + diameter_x0_y0/2;
    
    x1_y0 = base_size_x1/2 - (diameter_x1_y0/2);
    y0_x1 = -base_size_y1/2 + diameter_x1_y0/2;
    
    x1_y1 = base_size_x1/2 - (diameter_x1_y1/2);
    y1_x1 = base_size_y1/2 - (diameter_x1_y1/2);
    
    x0_y1 = -base_size_x1/2 + diameter_x0_y1/2;
    y1_x0 = base_size_y1/2 - (diameter_x0_y1/2);
    
    // Coordinates for top of the shape
    x2_y2 = -base_size_x2/2 + diameter_x2_y2/2;
    y2_x2 = -base_size_y2/2 + diameter_x2_y2/2;
    
    x2_y3 = -base_size_x2/2 + diameter_x2_y3/2;
    y3_x2 = base_size_y2/2 - (diameter_x2_y3/2);
    
    x3_y3 = base_size_x2/2 - (diameter_x3_y3/2);
    y3_x3 = base_size_y2/2 - (diameter_x3_y3/2);
    
    x3_y2 = base_size_x2/2 - (diameter_x3_y2/2);
    y2_x3 = -base_size_y2/2 + diameter_x3_y2/2;
    
    height = 0.001;
    
    $fn = 20;
    
    // Create figure
    hull() {
        
        if (sphere_corner) {
            // bottom
            color("blue", 1.0)
            translate([x0_y0,y0_x0,diameter_x0_y0/2])
                sphere(d = diameter_x0_y0);
            translate([x1_y0,y0_x1,diameter_x1_y0/2])
                sphere(d = diameter_x1_y0);
            translate([x1_y1,y1_x1,diameter_x1_y1/2])
                sphere(d = diameter_x1_y1);
            translate([x0_y1,y1_x0,diameter_x0_y1/2])
                sphere(d = diameter_x0_y1);
            
            // top
            color("orange", 1.0)
            translate([x2_y2,y2_x2,size_z - diameter_x2_y2/2])        
                sphere(d = diameter_x2_y2);
            translate([x3_y2,y2_x3,size_z - diameter_x3_y2/2])
                sphere(d = diameter_x3_y2);
            translate([x3_y3,y3_x3,size_z - diameter_x3_y3/2])
                sphere(d = diameter_x3_y3);
            translate([x2_y3,y3_x2,size_z - diameter_x2_y3/2])
                sphere(d = diameter_x2_y3);
        }
        else {
        
            // bottom
            color("blue", 1.0)
            translate([x0_y0,y0_x0,0])
                cylinder(h = height, d = diameter_x0_y0);
            translate([x1_y0,y0_x1,0])
                cylinder(h = height, d = diameter_x1_y0);
            translate([x1_y1,y1_x1,0])
                cylinder(h = height, d = diameter_x1_y1);
            translate([x0_y1,y1_x0,0])
                cylinder(h = height, d = diameter_x0_y1);
            
            // top
            color("orange", 1.0)
            translate([x2_y2,y2_x2,size_z])        
                cylinder(h = height, d = diameter_x2_y2);
            translate([x3_y2,y2_x3,size_z])
                cylinder(h = height, d = diameter_x3_y2);
            translate([x3_y3,y3_x3,size_z])
                cylinder(h = height, d = diameter_x3_y3);
            translate([x2_y3,y3_x2,size_z])
                cylinder(h = height, d = diameter_x2_y3);
        }
    }
    
}


function get_diameter(a, b) = sqrt((a*a)+(b*b));

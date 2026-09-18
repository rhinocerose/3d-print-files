/* [Hidden] */
peg_board_w = 99;
peg_board_h = 99;
peg_h = 13;
peg_w = 4.4;
peg_d = 5;
v_dist = 20;
h_dist = 20;
base_dist = 5;

/* [Global] */
// The width of the shelf
shelf_width = 160; // [80, 120, 160, 200, 240, 280]
// The length of the shelf. How far it sticks out from the board
shelf_depth = 100; // [40:5:260]
// This is the number of pegs to include on each support, if you want and even strong support you can increase this number, if you don't need it to be as strong you can lower it. 
num_pegs_base = 3;
shelf_length = shelf_depth;
// Thickness of the top piece of the shelf.
shelf_thickness = 5; // [5:15]

// Include a wall on the left side of the shelf
left_wall = false;
// Include a wall on the rigth side of the shelf
right_wall = false;
// Include a wall on the front side of the shelf
front_wall = false;
// Include a wall on the back side of the shelf
back_wall = false;
// Height of the walls if you have included them 
wall_height = 40;

// The support legs extends the depth of the shelf minus this number. A small inset like the default of 10 can be more visual appealing as it hides the leg slightly and won't stick out on the curved edges of the board.
leg_inset = 10;
l = shelf_length - leg_inset;


/* [Hidden] */
base_h = (num_pegs_base - 1) * 20 + (peg_h / 2);
base_w = 20 + 10 + peg_w / 2; 
support_l = (l / 4) * 3;
pegs_d = 3;
top_r = 5;
top_w = shelf_width;
base_d = 8;
beam_w = 8;
beam_h = 8;
wall_thickness = 5;
$fn = 20;


module peg() {
    cube([peg_w,peg_h / 2 - peg_w, peg_d]);
    translate(([peg_w/2,0,0])) 
        cylinder(h = peg_d, r = peg_w / 2);
    translate(([peg_w/2,peg_h / 2 - peg_w,0])) 
        cylinder(h = peg_d, r = peg_w / 2);
    // big part
    translate(([0,0,base_dist])) 
        union() {
            cube([peg_w,peg_h - peg_w, peg_d]);
            translate(([peg_w/2,0,0])) 
                cylinder(h = peg_d, r = peg_w / 2);
            translate(([peg_w/2,peg_h - peg_w,0])) 
                cylinder(h = peg_d, r = peg_w / 2);
        }
}


module pegs(w,h) {
    for(x=[0:h_dist * 2:w-peg_w]) {
        for(y=[0:v_dist * 2:h-peg_w]) {
            translate([x,y,0]) 
                peg();
        }
    }
    for(x=[h_dist:h_dist * 2:w-peg_w]) {
        for(y=[v_dist:v_dist * 2:h-peg_w]) {
            translate([x,y,0]) 
                peg();
        }
    }
}



module hexagon(id) {
    r = id / 2;
    x = cos(30) * r;
    polygon([[-x,.5 * r],[0,r],[x, .5 * r],[x, -.5 * r],[0,-r],[-x, -0.5 * r]]);
}

module insert() {
    translate(([(beam_w - id) / 2 + id / 2,0,0]))
        linear_extrude(5)
        difference() {
            hexagon(hex_d);
        }
}

module inserts(offset_r, h) {
    y_off = (id + gap) * sqrt(3) / 2;
    for(i=[y_off * 2 + y_off: y_off * 7 - y_off:l - hex_d / 2]) {
        translate([0,i,0])
        linear_extrude(h) 
        offset(r=offset_r)
        projection()
        insert();
    }
}

module support() {
        difference() {
            union() {
                cube([base_w,base_d, base_h]);
                translate([0,0,base_h - beam_h]) 
                cube([beam_w,l, beam_h]);
                translate([0,0,base_h])
                inserts(offset_r = -.3, h = 5);
                sideTri();
            }
            translate([0,l,base_h])
            rotate([0,0,90 + 180]) 
            chamfer(beam_w * 4);
        }
}


gap = 1.5;
L = 40 - gap;
N = 5;
id = (L - (N-1) * gap) / (N) ;
hex_d = id / cos(30); 
echo(id);

module hexagons(x, y) {
    y_off = (id + gap) * sqrt(3) / 2;
    x_off = (id + gap) * .5;
    h = max(shelf_thickness, beam_w, wall_thickness);
    for(i=[0:1:x]){
        for(j=[0:1:y]){
            translate([i * (id + gap), j * y_off * 2,0]) 
                linear_extrude(h) 
                hexagon(hex_d);
            translate([i * (id + gap) + x_off, j * y_off * 2 + y_off,0]) 
                linear_extrude(h) 
                hexagon(hex_d);
        }
    }
}
module sideTri() {
    o = 6;
    x_off = beam_h - o;
    difference() {
        translate([0,0, - beam_h])
        rotate([90,90,90])
        difference() {
            linear_extrude(beam_w)  
            // bottom, top right, top left
            polygon([[-beam_h + o/sqrt(2),x_off],[-base_h - (o), x_off],[-base_h-(o), support_l]]);
            intersection() {
                linear_extrude(beam_w)  
                offset(-o)
            polygon([[-beam_h + o/sqrt(2),x_off],[-base_h - (o), x_off],[-base_h-(o), support_l]]);
                rotate([0,0,90])
                hexagons(20,15);
            }
        }
        translate([0,0,-o * 3])
        cube([o * 3,o * 3,o * 3]);
    }
}


module wall(x, y, r, h, corners) {
    d = r * 2;
    translate([r,r,0]) 
    hull() {
        if (corners[0]) {
            translate([0,0,h/2]) 
            cube([r*2,r*2, h], center=true);
        } else {
            cylinder(h=h, r=r);
        }

        translate([0, y - d, 0]) 
        if (corners[1]) {
            translate([0,0,h/2]) 
            cube([r*2,r*2, h], center=true);
        } else {
            cylinder(h=h, r=r);
        }

        translate([x - d, y - d, 0]) 
        if (corners[2]) {
            translate([0,0,h/2]) 
            cube([r*2,r*2, h], center=true);
        } else {
            cylinder(h=h, r=r);
        }
        translate([x - d, 0, 0]) 
        if (corners[3]) {
            translate([0,0,h/2]) 
            cube([r*2,r*2, h], center=true);
        } else {
            cylinder(h=h, r=r);
        }
    }
}

module hex_wall(x, y, r, h, corners, os) {
    difference() {
        wall(x,y,r,h,corners);
        intersection() {
            union() {
                linear_extrude(h)
                offset(r = os) 
                projection() 
                wall(x,y,r,h,corners);
            }
            translate([- gap / 2 + gap/2,0]) 
            hexagons(x / id, y / id);
        }
    }
}



module bottom() {
    hex_wall(x = top_w, y = shelf_length, r = top_r, h = shelf_thickness, [true, right_wall || front_wall, left_wall || front_wall, true], os = -5);
}

module right() {
    union() {
        translate([0,0,shelf_thickness - 2]) 
        rotate([90,0,90]) 
        hex_wall(x = shelf_length, y = wall_height, r = top_r, h = wall_thickness, [true, true, front_wall, true], os = -wall_thickness);
        cube([wall_thickness,shelf_length,shelf_thickness]);
    }
}
module left() {
    translate([top_w - wall_thickness,0,0]) 
    right();
}

module back() {
    union() {
        translate([0,wall_thickness,shelf_thickness - 2]) 
        rotate([0,0,-90]) 
        union() {
        rotate([90, 0,90]) 
            hex_wall(x = top_w, y = wall_height, r = top_r, h = wall_thickness, [true, right_wall, left_wall, true], os = -wall_thickness);
            translate([0,0,-shelf_thickness + 2]) 
            cube([wall_thickness,top_w,shelf_thickness]);
        }
    }
}

module front() {
    translate([0,shelf_length - wall_thickness,0])
    back();
}

module fillet(r, h) {
    difference() {
        cube([r * 2, r * 2, h]);
        cylinder(r=r,h=h);
    }
}

module chamfer(x) {
    difference() {
        translate([0,0,-x]) 
        cube([x, x, x]);
        rotate([0,atan((base_h) / (support_l - base_d)),0]) 
        cube([x * 2, x,x]);
    }
}

module shelf() {
    difference() {
        union() {
            bottom();
            if (right_wall) {
                right();
            }
            if(left_wall) {
                left();
            }
            if(front_wall) {
                front();
            }
            if(back_wall) {
                back();
            }
        }
        union() {
            if (right_wall && front_wall) {
                translate([top_r,shelf_length - top_r,0]) 
                rotate([0,0,90])
                fillet(r = top_r, h = wall_height + shelf_thickness * 2);
            }
            if (left_wall && front_wall) {
                translate([top_w - top_r,shelf_length - top_r,0]) 
                fillet(r = top_r, h = wall_height + shelf_thickness * 2);
            }

            inserts(0, shelf_thickness);
            translate([top_w - beam_w,0,0])
                inserts(0, shelf_thickness);
        }
    }
}

color("#2e2e2e")
translate([0,0,base_h + 5 + .2]) 
shelf();

module rightSupport(){
    support();
    translate([0,0,-v_dist * 2 + base_h - peg_h]) 
    translate([base_w,0,40 + peg_w + peg_h / 2]) 
    rotate([90,180,0])
    pegs(base_w,base_h);
}
module leftSupport(){
    translate([base_w,0,0]) 
    mirror([1,0,0]) 
    support();
    translate([0,0,-v_dist * 2 + base_h - peg_h]) 
    translate([base_w - 10 + peg_w / 2,0,40 + peg_w + peg_h / 2]) 
    rotate([90,180,0])
    pegs(base_w,base_h);
}

rightSupport();
translate([shelf_width- base_w,0,0]) 
leftSupport();


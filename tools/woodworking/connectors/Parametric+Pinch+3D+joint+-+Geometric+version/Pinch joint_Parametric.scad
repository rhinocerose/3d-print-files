include <BOSL2/shapes3d.scad>
include <BOSL2/std.scad> 

wall = 4;
rod = 28.6;
rod_depth = 45;
plank = 17.3;
offset = 15.77;
hole_diameter = 3.5;

rodw = rod+2*wall;
plankw = plank+2*wall;
angledOffset = sqrt(2*wall*wall);

module plankSpace(x,y,z) {   
    translate([0,y/2,0])
    rotate([90,0,0])
    linear_extrude(y)
    polygon(points=[[-x/2, 0],[x/2, 0],[x/2-z, z],[-x/2+z, z]]);
}

module hole() {    
    cylinder(wall/2, hole_diameter/2+wall/2, hole_diameter/2,$fn=64);
    up(wall/2) cylinder(wall/2, hole_diameter/2, hole_diameter/2, $fn=64);    
}

difference() {
    cuboid([rodw, 2*rod_depth + plankw, rodw], anchor=BOTTOM+CENTER);
    up(wall) cuboid([rod, 2*rod_depth + plankw+2, rod], anchor=BOTTOM+CENTER);
    plankSpace(rodw*3,plankw, rodw);
    translate([0, plankw/2+rod_depth/2,0]) hole();
    translate([0, -plankw/2-rod_depth/2,0]) hole();    
}
difference() {
    plankSpace(rodw*3+2*offset, plankw, rodw);
    plankSpace(rodw*3-2*angledOffset+2*offset, plankw-2*wall, (rodw*3-2*angledOffset+2*offset)/2);
    translate([0, plankw/2,rodw/2]) rotate([90,0,0]) hole();
    translate([0, -plankw/2,rodw/2]) rotate([-90,0,0]) hole();
}

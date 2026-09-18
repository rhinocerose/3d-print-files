// Preambel
include <BOSL2/std.scad>

// Parameters
function clamp_width(clampsize, AWG) =
    (clampsize == 2 && AWG == "24...12") ? 13.2 :
    (clampsize == 3 && AWG == "24...12") ? 18.8 :
    (clampsize == 5 && AWG == "24...12") ? 30 :
    (clampsize == 2 && AWG == "20...10") ? 16 :
    (clampsize == 3 && AWG == "20...10") ? 22.9 :
    (clampsize == 5 && AWG == "20...10") ? 36.7 :
    "";
    
function clamp_height(AWG) =
    AWG == "24...12" ? 8.4 :
    AWG == "20...10" ? 10.1 :
    "";
    
function clamp_depth(AWG) =
    AWG == "24...12" ? 18.6 :
    AWG == "20...10" ? 21.1 :
    "";
    
function box_height(cable_diameter, clamp_height, box_b) =
    cable_diameter + 4 > clamp_height + 7*0.2 + 1.4 ? cable_diameter + 6 + 2*box_b +1.5:
    clamp_height + box_b + 7*0.2 + 3;
    
//Number of cables each clamp can handle
clampsize = 3; //[2,3,5]
//Use "24...12" for Wago 221-4XX and "20...10" for Wago 221-6XX
AWG = "24...12"; //[24...12, 20...10]
number_of_clamps = 3;
//Cable holes on the bottom. Each one gets a dedicated zip tie hook for strain relief
number_of_cables_bottom = 3;
//Cable holes on the right
number_of_cables_right = 0;
//Cable holes on the left
number_of_cables_left = 0;
cable_diameter = 10;
//Screw Diameter for wall mount. Set 0 for no wall mount holes
screw_diameter = 3;
//Edit this for more cable space. Standard outer depth for "24...12" = 55mm, for "20...10" = 60mm. If less than standard, nothing will change
depth = 0;
//Edit this for more cable space. Standard outer height for "24...12" = 16mm, for "20...10" = 17.7mm. If less than standard, nothing will change
height = 0;

/* [Hidden] */
// Calculations
clamp_width = clamp_width(clampsize, AWG);
clamp_height = clamp_height(AWG);
clamp_depth = clamp_depth(AWG);
box_b = 1.6;
detail = 64;
box_width = 2*box_b + number_of_clamps*clamp_width + (number_of_clamps+1)*box_b + number_of_clamps*0.2;
box_depth = max(depth, 2*clamp_depth + 17.8);
box_height = max(height, box_height(cable_diameter, clamp_height, box_b));

// Box generation
module box(){
    difference(){
        cuboid([box_width,box_depth,box_height], rounding=5, edges=[FRONT+LEFT, FRONT+RIGHT, BACK+LEFT, BACK+RIGHT], $fn=detail);
        
        translate([0,0,box_b])
        cuboid([box_width-2*box_b,box_depth-2*box_b,box_height], rounding=5-box_b, edges=[FRONT+LEFT, FRONT+RIGHT, BACK+LEFT, BACK+RIGHT], $fn=detail);
    }

    translate([box_b/2-(box_width-2*box_b)/2,-clamp_depth/2+(box_depth-2*box_b)/2-box_b-1.75,(clamp_height+0.2)/2-box_height/2+box_b])
    cuboid([box_b,clamp_depth+3.5,clamp_height+0.2], rounding=box_b/2, edges=[FRONT+RIGHT], $fn=detail);
    
    translate([(box_b+0.6)/2-(box_width-2*box_b)/2,-clamp_depth/2+(box_depth-2*box_b)/2-box_b-1.75,-box_height/2+box_b+(6*0.2)/2+clamp_height+0.2])
    cuboid([box_b+0.8,clamp_depth+3.5,6*0.2], rounding=box_b/2, edges=[FRONT+RIGHT], $fn=detail);

    translate([-box_b/2+(box_width-2*box_b)/2,-clamp_depth/2+(box_depth-2*box_b)/2-box_b-1.75,(clamp_height+0.2)/2-box_height/2+box_b])
    cuboid([box_b,clamp_depth+3.5,clamp_height+0.2], rounding=box_b/2, edges=[FRONT+LEFT], $fn=detail);
    
    translate([-(box_b+0.6)/2+(box_width-2*box_b)/2,-clamp_depth/2+(box_depth-2*box_b)/2-box_b-1.75,-box_height/2+box_b+(6*0.2)/2+clamp_height+0.2])
    cuboid([box_b+0.8,clamp_depth+3.5,6*0.2], rounding=box_b/2, edges=[FRONT+LEFT], $fn=detail);

    for (i = [1:number_of_clamps-1]){
        translate([-(box_width/2-3/2*box_b)+i*(box_width-3*box_b)/number_of_clamps,-clamp_depth/2+(box_depth-2*box_b)/2-box_b-1.75,(clamp_height+0.2)/2-box_height/2+box_b])
        cuboid([box_b,clamp_depth+3.5,clamp_height+0.2], rounding=box_b/2, edges=[FRONT+LEFT, FRONT+RIGHT], $fn=detail);
        
        translate([-(box_width/2-3/2*box_b)+i*(box_width-3*box_b)/number_of_clamps,-clamp_depth/2+(box_depth-2*box_b)/2-box_b-1.75,-box_height/2+box_b+(6*0.2)/2+clamp_height+0.2])
        cuboid([box_b+0.8,clamp_depth+3.5,6*0.2], rounding=box_b/2, edges=[FRONT+LEFT, FRONT+RIGHT], $fn=detail);
        
        translate([-(box_width/2-3/2*box_b)+i*(box_width-3*box_b)/number_of_clamps-box_b/2,box_depth/2-2*box_b-0.5,-box_height/2+box_b])
        cylinder(clamp_height+0.2+6*0.2,3,3, $fn=detail);
        
        translate([-(box_width/2-3/2*box_b)+i*(box_width-3*box_b)/number_of_clamps+box_b/2,box_depth/2-2*box_b-0.5,-box_height/2+box_b])
        cylinder(clamp_height+0.2+6*0.2,3,3, $fn=detail);
    }
    
    translate([0,box_depth/2-3*box_b/2,-box_height/2+box_b+(clamp_height+0.2+6*0.2)/2])
    cuboid([box_width-2*box_b,box_b,clamp_height+0.2+6*0.2]);

    translate([-box_width/2+2*box_b+0.5,box_depth/2-2*box_b-0.5,-box_height/2])
    cylinder(box_height,3,3, $fn=detail);
    
    translate([+box_width/2-2*box_b-0.5,box_depth/2-2*box_b-0.5,-box_height/2])
    cylinder(box_height,3,3, $fn=detail);
    
    translate([box_width/2-2*box_b-0.5,-box_depth/2+2*box_b+0.5,-box_height/2])
    cylinder(box_height,3,3, $fn=detail);
    
    translate([-box_width/2+2*box_b+0.5,-box_depth/2+2*box_b+0.5,-box_height/2])
    cylinder(box_height,3,3, $fn=detail);
    
    if (number_of_cables_bottom > 0){
        for (i = [1:min(number_of_cables_bottom, floor((box_width-5)/(2*cable_diameter)))]){
            rotate([90,0,0])
            translate([(box_width-5)/2-i*(box_width-5)/(min(number_of_cables_bottom, floor((box_width-5)/(2*cable_diameter)))+1),box_b,box_depth/2-1.5*box_b])
            cylinder(2*box_b,cable_diameter/2+2,cable_diameter/2+2, $fn=detail);
            
            translate([(box_width-5)/2-i*(box_width-5)/(min(number_of_cables_bottom, floor((box_width-5)/(2*cable_diameter)))+1),-box_depth/2+box_b+(3.5+2*1.2)/2+2,-box_height/2+box_b+2-0.6])
            cuboid([2,3.5+2*1.2,3.2]); 
        }
    }
    
    if (number_of_cables_right > 0){
        for (i = [1:min(number_of_cables_right, floor((box_depth-clamp_depth)/(2*cable_diameter+4)))]){
            rotate([0,90,0])
            translate([-box_b,-clamp_depth/2+(box_depth-clamp_depth)/2-i*(box_depth-clamp_depth)/(min(number_of_cables_right, floor((box_depth-clamp_depth)/(2*cable_diameter+4)))+1),box_width/2-3*box_b/2])
            cylinder(2*box_b,cable_diameter/2+2,cable_diameter/2+2, $fn=detail);
        }
    }
    
    if (number_of_cables_left > 0){
        for (i = [1:min(number_of_cables_left, floor((box_depth-clamp_depth)/(2*cable_diameter+4)))]){
            rotate([0,90,0])
            translate([-box_b,-clamp_depth/2+(box_depth-clamp_depth)/2-i*(box_depth-clamp_depth)/(min(number_of_cables_left, floor((box_depth-clamp_depth)/(2*cable_diameter+4)))+1),-box_width/2-box_b/2])
            cylinder(2*box_b,cable_diameter/2+2,cable_diameter/2+2, $fn=detail);
        }
    }
    
    for (i = [0:number_of_clamps-1]){
        translate([-box_width/2+2*box_b+(clamp_width+0.2)/2+i*(clamp_width+box_b+0.2),(box_depth/2-2*box_b-clamp_depth-5.2),-box_height/2+box_b])
        #prismoid(size1=[5,3], size2=[5,0], h=0.6, shift=[0,1.5]);
    }
    
    if (screw_diameter>0){
        for (i = [0:1]){
        translate([-box_width/2+2*box_b+(clamp_width+0.2)/2+i*(number_of_clamps-1)*(clamp_width+box_b+0.2),-box_depth/4+box_b,-box_height/2])
        cylinder(box_b+box_b/2,screw_diameter+0.2,screw_diameter+0.2, $fn=detail);
        }
    }
}

module screws_box(){
    difference(){
        box();
        
        translate([-box_width/2+2*box_b+0.5,box_depth/2-2*box_b-0.5,-box_height/2+5])
        cylinder(box_height+0.2,1.4,1.4, $fn=detail);
        
        translate([+box_width/2-2*box_b-0.5,box_depth/2-2*box_b-0.5,-box_height/2+5])
        cylinder(box_height+0.2,1.4,1.4, $fn=detail);
        
        translate([box_width/2-2*box_b-0.5,-box_depth/2+2*box_b+0.5,-box_height/2+5])
        cylinder(box_height+0.2,1.4,1.4, $fn=detail);
        
        translate([-box_width/2+2*box_b+0.5,-box_depth/2+2*box_b+0.5,-box_height/2+5])
        cylinder(box_height+0.2,1.4,1.4, $fn=detail);
        
        if (number_of_cables_bottom > 0){
            for (i = [1:min(number_of_cables_bottom, floor((box_width-5)/(2*cable_diameter)))]){
                rotate([90,0,0])
                translate([(box_width-5)/2-i*(box_width-5)/(min(number_of_cables_bottom, floor((box_width-5)/(2*cable_diameter)))+1),box_b,box_depth/2-2.5*box_b])
                cylinder(4*box_b,cable_diameter/2+1,cable_diameter/2+1, $fn=detail);
                
                translate([(box_width-5)/2-i*(box_width-5)/(min(number_of_cables_bottom, floor((box_width-5)/(2*cable_diameter)))+1),-box_depth/2+box_b+(3.5+2*1.2)/2+2,-box_height/2+box_b+2-1.2])
                cuboid([6,3.5,2], chamfer=1, edges=[BOTTOM+LEFT, BOTTOM+RIGHT]);
            }
        }
        
        if (number_of_cables_right > 0){
            for (i = [1:min(number_of_cables_right, floor((box_depth-clamp_depth)/(2*cable_diameter+4)))]){
                rotate([0,90,0])
                translate([-box_b,-clamp_depth/2+(box_depth-clamp_depth)/2-i*(box_depth-clamp_depth)/(min(number_of_cables_right, floor((box_depth-clamp_depth)/(2*cable_diameter+4)))+1),box_width/2-5*box_b/2])
                cylinder(4*box_b,cable_diameter/2+1,cable_diameter/2+1, $fn=detail);
            }
        }
        
        if (number_of_cables_left > 0){
            for (i = [1:min(number_of_cables_left, floor((box_depth-clamp_depth)/(2*cable_diameter+4)))]){
                rotate([0,90,0])
                translate([-box_b,-clamp_depth/2+(box_depth-clamp_depth)/2-i*(box_depth-clamp_depth)/(min(number_of_cables_left, floor((box_depth-clamp_depth)/(2*cable_diameter+4)))+1),-box_width/2-3*box_b/2])
                cylinder(4*box_b,cable_diameter/2+1,cable_diameter/2+1, $fn=detail);
            }
        }
        if (screw_diameter>0){
            for (i = [0:1]){
            translate([-box_width/2+2*box_b+(clamp_width+0.2)/2+i*(number_of_clamps-1)*(clamp_width+box_b+0.2),-box_depth/4+box_b,-box_height/2-box_b ])
            cylinder(10,screw_diameter/2+0.2,screw_diameter/2+0.2, $fn=detail);
            }
        }
    }
}

screws_box();

// Lid generation
module lid(){
    translate([0,-box_depth-4*box_b,-box_height/2+box_b/2])
    cuboid([box_width,box_depth,box_b], rounding=5, edges=[FRONT+LEFT, FRONT+RIGHT, BACK+LEFT, BACK+RIGHT], $fn=detail);
    
    difference(){
        difference(){
            translate([0,-box_depth-4*box_b,-box_height/2+box_b+0.7])
            cuboid([box_width-2*box_b-0.2,box_depth-2*box_b-0.2,1.3], rounding=5-box_b-0.2, edges=[FRONT+LEFT, FRONT+RIGHT, BACK+LEFT, BACK+RIGHT], $fn=detail);
            
            translate([0,-box_depth-4*box_b,-box_height/2+box_b+0.7])
            cuboid([box_width-4*box_b-0.2,box_depth-4*box_b-0.2,1.5], rounding=5-box_b-0.2-2, edges=[FRONT+LEFT, FRONT+RIGHT, BACK+LEFT, BACK+RIGHT], $fn=detail);
        }
        
        translate([-box_width/2+2*box_b+0.5,box_depth/2-2*box_b-0.5-box_depth-4*box_b,-box_height/2])
        cylinder(box_height,5,5, $fn=detail);
        
        translate([+box_width/2-2*box_b-0.5,box_depth/2-2*box_b-0.5-box_depth-4*box_b,-box_height/2])
        cylinder(box_height,5,5, $fn=detail);
        
        translate([box_width/2-2*box_b-0.5,-box_depth/2+2*box_b+0.5-box_depth-4*box_b,-box_height/2])
        cylinder(box_height,5,5, $fn=detail);
        
        translate([-box_width/2+2*box_b+0.5,-box_depth/2+2*box_b+0.5-box_depth-4*box_b,-box_height/2])
        cylinder(box_height,5,5, $fn=detail);
    }
}

module screws_lid(){
    difference(){
        lid();
        
        translate([-box_width/2+2*box_b+0.5,box_depth/2-2*box_b-0.5-box_depth-4*box_b,-box_height/2-5])
        cylinder(box_height+0.2,1.6,1.6, $fn=detail);
        
        translate([+box_width/2-2*box_b-0.5,box_depth/2-2*box_b-0.5-box_depth-4*box_b,-box_height/2-5])
        cylinder(box_height+0.2,1.6,1.6, $fn=detail);
        
        translate([box_width/2-2*box_b-0.5,-box_depth/2+2*box_b+0.5-box_depth-4*box_b,-box_height/2-5])
        cylinder(box_height+0.2,1.6,1.6, $fn=detail);
        
        translate([-box_width/2+2*box_b+0.5,-box_depth/2+2*box_b+0.5-box_depth-4*box_b,-box_height/2-5])
        cylinder(box_height+0.2,1.6,1.6, $fn=detail);
    }
}

screws_lid();
//Designed for M3 heat melt inserts, 5mm diameter, 4mm depth


$fn=64;
depth_u = 2;
height_mm = 110;

hole_d = 4.5;
hole_r = 2.4;

save_filament = true;
sidewall_mm = 10;
top_mm = 12;

difference(){
//cube([(depth_u*42)-0.5,height_mm,6]);
union(){
 hull(){ //base portion
    translate([0,0,3.75]) cube([(depth_u*42)-0.5,6,8.5]); //Upper cube
    translate([3.75,0,3.75]) rotate([-90,0,0]) cylinder(h=10, r=3.75);
    translate([depth_u*42-3.75-.5,0,3.75]) rotate([-90,0,0]) cylinder(h=10, r=3.75);
    translate([0,13,3.75]) cube([(depth_u*42)-0.5,2,2]); //Middle cube
    //translate([0,height_mm-2,3.75]) cube([(depth_u*42)-0.5,2,4]); //Upper cube
    

    //translate([0,height_mm,12]) rotate([90,0,0]) cylinder(h=hole_d, r=hole_r);
    //translate([12,height_mm,12]) rotate([90,0,0]) cylinder(h=hole_d, r=hole_r);

    //translate([0,height_mm,0]) rotate([90,0,0]) cylinder(h=hole_d, r=hole_r);
    //translate([12,height_mm,12]) rotate([90,0,0]) cylinder(h=hole_d, r=hole_r);
//
 }
 hull(){ //vertical extension
    translate([0,12,3.75]) cube([(depth_u*42)-0.5,2,4.1]); //Middle cube
    translate([0,height_mm-2,3.75]) cube([(depth_u*42)-0.5,2,4.1]); //Upper cube
    translate([3.75,0,3.75]) rotate([-90,0,0]) cylinder(h=height_mm, r=3.75);
    translate([depth_u*42-3.75-.5,0,3.75]) rotate([-90,0,0]) cylinder(h=height_mm, r=3.75);
    } 
}// end union
    
translate([8.05,hole_d-0.1,8.05]) rotate([90,0,0]) cylinder(h=hole_d, r=hole_r); //bottom left hole
translate([((depth_u)*42)-8.55,hole_d-0.1,8.05]) rotate([90,0,0]) cylinder(h=hole_d, r=hole_r); //bottom right hole

// middle screw holes
if(depth_u>1)
{
translate([(((depth_u)*42)/2)-0.25,hole_d-0.1,8.05]) rotate([90,0,0]) cylinder(h=hole_d, r=hole_r); //bottom middle hole
translate([(((depth_u)*42)/2)-0.25,(height_mm)+0.1,4]) rotate([90,0,0]) cylinder(h=hole_d, r=hole_r); //top middle hole
}

translate([4,(height_mm)+0.1,4]) rotate([90,0,0]) cylinder(h=hole_d, r=hole_r); //top left hole
translate([((depth_u)*42)-4.5,(height_mm)+0.1,4]) rotate([90,0,0]) cylinder(h=hole_d, r=hole_r); //top right hole

if(save_filament){
hull(){
    translate([sidewall_mm,20,-0.01]) cylinder(h=20,r=5);
    translate([sidewall_mm,height_mm-top_mm,-0.01]) cylinder(h=20,r=5);
    translate([((depth_u)*42)-sidewall_mm-.5,20,-0.01]) cylinder(h=20,r=5);
    translate([((depth_u)*42)-sidewall_mm-.5,height_mm-top_mm,-0.01]) cylinder(h=20,r=5);
    }
    }

} //end difference

//Notes
/*
Need to be 17mm in form the perimated on the bottom for the screws to come in 

*/
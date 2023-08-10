// Gridfinity lifted top plate 
// Designed to be compatible with Gridfinity

$fn = 64;   

middle_screws = true;

screwHead_cutouts = true; //These are statically sized for M3 screws (6mm diameter)

depth_u = 1;
width_u = 3;

plate_h = 7;
screw_r = 1.6;

depth = (depth_u*42) - 0.5;
width = (width_u*42) - 0.5;

rearOffset=depth*.3;
frontOffset=depth*.7;

not_flat = true; //Want just flat paltes, make this false. Also set screwHead_cutouts to false.


hexWidths = [12.5,12.5,12.5,12.5,12.5,12.5,12.5]; //Width of parallel sides of hexagons, left to right
cutoutWidths = [4,4,4,4,4,4,4]; //Width of cutouts, must have same length as hexWidths
toolSides=[6,6,6,6,6,6,6]; //Use 6 for hex base, 0 for round base, must have same length as hexWidths. Hex(6) will adjust for paralel side distance, all others will match outer dimension.
numTools=len(hexWidths);

sideOffset=width/(numTools+1);

frontChannels = true; //Do you want cut out channels to the front?

difference(){
hull(){
    translate([3.75,3.75,0]) cylinder(h=plate_h, r=3.75);
    translate([((depth_u)*42)-4.25,3.75,0]) cylinder(h=plate_h, r=3.75);
    translate([3.75,(width_u*42)-4.25,0]) cylinder(h=plate_h, r=3.75);
    translate([((depth_u)*42)-4.25,(width_u*42)-4.25,0]) cylinder(h=plate_h, r=3.75);
}
//cube([depth,width,7]); //square corners are boring

usedOffset=20;

//Back screw holes
    translate([4,4,-.01]) cylinder(h=7.1, r=screw_r);
    if(screwHead_cutouts){
    translate([4,4,4]) cylinder(h=7.1, r=3);
    translate([-0.01,-0.01,4]) cube([4,7,20]);
    translate([-0.01,-0.01,4]) cube([7,4,20]);
    }
    
    translate([((depth_u)*42)-4.5,4,-.01]) cylinder(h=7.1, r=screw_r);
    if(screwHead_cutouts){
    translate([((depth_u)*42)-4.5,4,4]) cylinder(h=7.1, r=3);
    translate([((depth_u)*42)-4.49,-0.01,4]) cube([4,7,20]);
    translate([((depth_u)*42)-7.49,-0.01,4]) cube([7,4,20]);
    }

//Middle screw holes
if((depth_u>1) && middle_screws)
{
    translate([((depth_u*42-0.5)/2),4,-.01]) cylinder(h=7.1, r=screw_r);
    if(screwHead_cutouts){
    translate([((depth_u*42-0.5)/2),4,4]) cylinder(h=7.1, r=3);
    translate([((depth_u*42-0.5)/2)-3,-0.01,4]) cube([6,4,20]);
    }
    
    
    translate([((depth_u*42-0.5)/2),(width_u*42)-0.5-4,-.01]) cylinder(h=7.1, r=screw_r);
    if(screwHead_cutouts){
    translate([((depth_u*42-0.5)/2),(width_u*42)-0.5-4,4]) cylinder(h=7.1, r=3);
    translate([((depth_u*42-0.5)/2)-3,(width_u*42)-4.49,4]) cube([6,4,20]);
    }   
}

//Front screw holes
    translate([4,(width_u*42)-4.5,-.01]) cylinder(h=7.1, r=screw_r);
    if(screwHead_cutouts){
    translate([4,(width_u*42)-4.5,4]) cylinder(h=7.1, r=3);
    translate([-0.01,(width_u*42)-7.49,4]) cube([4,7,20]);
    translate([-0.01,(width_u*42)-4.49,4]) cube([7,4,20]);
    }
    
    translate([((depth_u)*42)-4.5,(width_u*42)-4.5,-.01]) cylinder(h=7.1, r=screw_r);
    if(screwHead_cutouts){
    translate([((depth_u)*42)-4.5,(width_u*42)-0.5-4,4]) cylinder(h=7.1, r=3);
    translate([((depth_u)*42)-4.49,(width_u*42)-7.49,4]) cube([4,7,20]);
    translate([((depth_u)*42)-7.49,(width_u*42)-4.49,4]) cube([7,4,20]);
    }
   

if(not_flat){
 for(h=[1:1:numTools]){
    
    if((h%2 < 1)) {
        cutout(frontOffset, sideOffset*h, h);
        }
    if((h%2 >0)) {
        cutout(rearOffset, sideOffset*h, h);
        }  
 }
}
}

module cutout(offsetBack, offsetSide, index){
    if(toolSides[index-1]==6){
        translate([offsetBack, offsetSide, 4]) rotate([0, 0, 30])  
        hull(){
            cylinder(r=hexWidths[index-1]*1.1547005/2, h=6, $fn=6);
            translate ([0,0,-2.5]) cylinder(r=3.75,h=0.01);
        };
        translate([offsetBack, offsetSide, -1])  cylinder(10,cutoutWidths[index-1]/2,cutoutWidths[index-1]/2);
        if(frontChannels){
        translate([offsetBack, offsetSide-(cutoutWidths[index-1]/2), -1])  cube([102,cutoutWidths[index-1],20]);
        }
    }
    else{
        echo("circle");
        translate([offsetBack, offsetSide, 4]) rotate([0, 0, 30]) chamferCylinder(15, hexWidths[index-1]/2, hexWidths[index-1]/2, 1,  0, 360, toolSides[index-1]);
        translate([offsetBack, offsetSide, -1])  cylinder(10,cutoutWidths[index-1]/2,cutoutWidths[index-1]/2);
        if(frontChannels){
        translate([offsetBack, offsetSide-(cutoutWidths[index-1]/2), -1])  cube([102,cutoutWidths[index-1],20]);
        }
    }
    
}

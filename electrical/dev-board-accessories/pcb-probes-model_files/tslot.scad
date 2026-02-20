//======================================================================
// tslot.scad
//
// models for AL T-slot extrusions, corner braces, etc
// Note these are slightly simplified from the actual shape
// 
// Here is a link for the 6-series 30x30 
// https://us.misumi-ec.com/vona2/detail/110302686450/?ProductCode=HFS6-3030
//
// 
// DrTomFlint, 2020
//======================================================================

//----------------------------------------------------------------------
module tslot1(
tol = 0.0,
len = 60,
type = 1
){
    
// 30x30     
if(type==1){
    linear_extrude(height=len,convexity=10)
    difference(){
        offset(r=2.0+tol,$fn=20)
        square([26,26],center=true);
 
        translate([0,12,0])
        square([8.2-tol,8.2-tol],center=true);
        translate([0,-12,0])
        square([8.2-tol,8.2-tol],center=true);
        translate([12,0,0])
        square([8.2-tol,8.2-tol],center=true);
        translate([-12,0,0])
        square([8.2-tol,8.2-tol],center=true);
    }
}
    
// 30x60
if(type==2){
    linear_extrude(height=len,convexity=10)
    difference(){
        offset(r=2.0+tol,$fn=20)
        square([26,56],center=true);
 
        translate([0,27,0])
        square([8.2-tol,8.2-tol],center=true);
        translate([0,-27,0])
        square([8.2-tol,8.2-tol],center=true);
        
        translate([12,15,0])
        square([8.2-tol,8.2-tol],center=true);
        translate([-12,15,0])
        square([8.2-tol,8.2-tol],center=true);

        translate([12,-15,0])
        square([8.2-tol,8.2-tol],center=true);
        translate([-12,-15,0])
        square([8.2-tol,8.2-tol],center=true);
    }
}
    
// 36x60
if(type==3){
    linear_extrude(height=len,convexity=10)
    difference(){
        offset(r=2.0+tol,$fn=20)
        square([56,56],center=true);
 
        translate([15,27,0])
        square([8.2-tol,8.2-tol],center=true);
        translate([15,-27,0])
        square([8.2-tol,8.2-tol],center=true);
        
        translate([-15,27,0])
        square([8.2-tol,8.2-tol],center=true);
        translate([-15,-27,0])
        square([8.2-tol,8.2-tol],center=true);
        
        translate([27,15,0])
        square([8.2-tol,8.2-tol],center=true);
        translate([-27,15,0])
        square([8.2-tol,8.2-tol],center=true);

        translate([27,-15,0])
        square([8.2-tol,8.2-tol],center=true);
        translate([-27,-15,0])
        square([8.2-tol,8.2-tol],center=true);
    }
}
    
}

//----------------------------------------------------------------------
module tbrace(
tol=0.0
){

F2=22;
 
translate([0,0,2-15])    
difference(){    
union(){
        cube([4.8,60,26]);
        cube([60,4.8,26]);
    
    hull(){
        translate([60-2.4,4.8,0])
        cylinder(r=2.4,h=26,$fn=F2);
        translate([4.8,60-2.4,0])
        cylinder(r=2.4,h=26,$fn=F2);
    }
}    

        translate([15,0,26/2])
        rotate([-90,0,0])
        cylinder(r1=3.5,r2=4.5,h=60,$fn=F2);
        translate([15+30,0,26/2])
        rotate([-90,0,0])
        cylinder(r1=3.5,r2=4.5,h=60,$fn=F2);

        translate([0,15,26/2])
        rotate([0,90,0])
        cylinder(r1=3.5,r2=4.5,h=60,$fn=F2);
        translate([0,15+30,26/2])
        rotate([0,90,0])
        cylinder(r1=3.5,r2=4.5,h=60,$fn=F2);

}
}

//----------------------------------------------------------------------
module lbrace(
tol=0,
holes=0,
nuts=1
){

F2=22;
    
pts1=[ [5,0], [80,0], [85,5], [85,22], [80,28],
    [28,28], [28,80], [22,85], [5,85], [0,80], [0,5] ];
    
if(holes==1){
    difference(){
        linear_extrude(height=3.25+tol,convexity=10)
        offset(r=tol)
        polygon(points=pts1);
        
        translate([16+30,14,-1])
        cylinder(r=3.25,h=5,$fn=F2);
        translate([16+60,14,-1])
        cylinder(r=3.25,h=5,$fn=F2);

        translate([14,16+30,-1])
        cylinder(r=3.25,h=5,$fn=F2);
        translate([14,16+60,-1])
        cylinder(r=3.25,h=5,$fn=F2);
    }
}else{
        linear_extrude(height=3.25+tol,convexity=10)
        offset(r=tol)
        polygon(points=pts1);
}

if(nuts==1){
    
        translate([16+30,14,0])
        cylinder(r=5,h=6+3.25,$fn=F2);
        translate([16+60,14,0])
        cylinder(r=5,h=6+3.25,$fn=F2);

        translate([14,16+30,0])
        cylinder(r=5,h=6+3.25,$fn=F2);
        translate([14,16+60,0])
        cylinder(r=5,h=6+3.25,$fn=F2);
}

}


//======================================================================

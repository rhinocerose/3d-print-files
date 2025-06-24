//======================================================================
// rounder.scad
//
// cutting tools for rounding off corners and making bevels
//
// DrTomFlint 26 March 2024
//======================================================================


//----------------------------------------------------------------------
module rounder(
r=10,   // radius
h=10,   // height
f=22,    // $fn
extra=0.01  // extra size for the cube to ensure a clean cut
){

difference(){
  translate([-extra,-extra,-extra])
  cube([r+extra,r+extra,h+2*extra]);
  translate([r,r,-1])
  cylinder(r=r,h=h+2,$fn=f);
}

}

//----------------------------------------------------------------------
module bevel(x=1,y=1,h=10){

linear_extrude(height=h)
polygon(points=[[0,0],[x,0],[0,y]]);
    
}
  
//======================================================================
// call the two modules as a demo, these are not printed on their own
// just used to make cuts and fillets

rounder();

translate([0,20,0])
bevel(x=2,y=4,h=6);

//======================================================================

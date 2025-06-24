// tplug.scad
// plugs for the ends of the tslots

//----------------------------------------------------------------
module tab(z2=6){
  
pts=[ [0,6], [4.7,6], [8.2,9.6], [8.2,13], [4.1,13], [4.1,15], [0,15] ];

translate([0,0,-z2])
linear_extrude(height=z2,scale=1.015)
offset(r=0.2,$fn=44)
offset(r=-0.4)
union(){
  polygon(pts);
  mirror([1,0,0]) polygon(pts);
}

}
//----------------------------------------------------------------
module tplug(type=1,tabs=4){

rx=1.5;   // rounding radius
z1=3;     // thickness of end

if(type==1){

  // rounded plug end
  difference(){
    translate([-15+rx,-15+rx,0])
    minkowski(){
      cube([30-2*rx,30-2*rx,z1-rx]);
      sphere(r=rx, $fn=40);
    }
    translate([-16,-16,-3])
    cube([32,32,3]);
  }

  // tabs
  tab();
  rotate([0,0,90]) tab();
  rotate([0,0,180]) tab();
  if(tabs==4){
    rotate([0,0,270]) tab();
  }
}

if(type==2){

  // rounded plug end
  difference(){
    translate([-15+rx,-15+rx,0])
    minkowski(){
      cube([60-2*rx,30-2*rx,z1-rx]);
      sphere(r=rx, $fn=40);
    }
    translate([-16,-16,-3])
    cube([62,32,3]);
  }

  // tabs
  tab();
  translate([30,0,0]) tab();

  rotate([0,0,90]) tab();
  rotate([0,0,180]) tab();
  translate([30,0,0]) rotate([0,0,180]) tab();
  translate([30,0,0]) rotate([0,0,270]) tab();
}



}

//=================================================================

tplug(type=1);
//tplug(type=1,tabs=3);
//tplug(type=2);

//=================================================================

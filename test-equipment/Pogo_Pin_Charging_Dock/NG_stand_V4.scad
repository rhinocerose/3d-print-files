include  <MCAD/boxes.scad>
include </Users/aaronciuffo/Documents/Hobby/OpenScad/libraries/puzzlecutlib/multicutdemo.scad>

/*
Nexus Galaxy dock with multiple puzzle cuts
V3.2
*/

/* [Plate Dimensions] */
//Plate Length
pX=170; //[140:200]
//Plate Width
pY=80; //[50:100]
//Plate Thickness
pZ=5; //[5:10]

/* [Feet Dimensions] */
//Feet Diameter
feetDia=6; //[6:20]
//Feet Length
feetLen=20; //[15:30]

/* [Slot Dimensions] */
//Slot Length
slotLen=20; //[15:35]
//Slot Width
slotWidth=3.5; 

/* [Pogo Pin Hole] */
//Pogo Pin Hole - Length
pinX=15; //[10:20]
//Pogo Pin Hole - Width
pinY=8; //[5:10]
//Pogo Pin Offset from center 
offset=-18.5;

/* [Counter Sunk Holes] */
//Screw Head Diameter
dia=5.8;
//Head Height
headHt=2;
//Thread diameter
threadDia=3.2;

/* [Hidden] */
//ignore this variable!
plateDim=[pX,pY,pZ]; //Plate Dimensions
//ignore this variable!
pinHole=[pinX,pinY,pZ*2]; //stamp to cut the pin hole


module drawBase(plate){
  //corner round radius
  corner=5;
  roundedBox(plate,corner,sidesonly=1);
}

module drawFeet(plate,feetDia,feetLen){
  feetRad=.5*feetDia;
  //set the z length of the legs
  z=-((feetLen/2)+(plate[2]/2));
  //front left
  cornerA=[-((plate[0]/2)-feetDia),-((plate[1]/2)-feetDia),z];
  //back left
  cornerB=[-((plate[0]/2)-feetDia),((plate[1]/2)-feetDia),z];
  //back right
  cornerC=[((plate[0]/2)-feetDia),((plate[1]/2)-feetDia),z];
  //front right
  cornerD=[((plate[0]/2)-feetDia),-((plate[1]/2)-feetDia),z];
  
  translate(cornerA) cylinder(r=feetRad,h=feetLen,center=true, $fn=20);
  translate(cornerB) cylinder(r=feetRad,h=feetLen,center=true, $fn=20);
  translate(cornerC) cylinder(r=feetRad,h=feetLen,center=true, $fn=20);
  translate(cornerD) cylinder(r=feetRad,h=feetLen,center=true, $fn=20);
}

module cutXSlot(slotWidth,slotLen,plate){
  union(){
    translate([-slotLen/2,0,0]) cylinder(r=slotWidth/2,h=plate[2]+1, center=true, $fn=20);
    translate([slotLen/2,0,0]) cylinder(r=(slotWidth/2),h=plate[2]+1, center=true, $fn=20);
    cube([slotLen,slotWidth,plate[2]+1],center=true);
  }
}

module cutYSlot(slotWidth,slotLen,plate){
  union ()
  {
    translate([0,slotLen/2,0]) cylinder(r=slotWidth/2,h=plate[2]+1, center=true, $fn=20);
    translate([0,-slotLen/2,0]) cylinder(r=(slotWidth/2),h=plate[2]+1, center=true, $fn=20);
    cube([slotWidth,slotLen,plate[2]+1],center=true);
  }
}

module csHole (){
  translate([0,0,(pZ/2)-(headHt+.6)]) union(){
    cylinder(r2=dia/2,r1=threadDia/2,h=headHt, $fn=24);
    translate([0,0,-20]) cylinder(r=threadDia/2,h=50, $fn=24);
    translate([0,0,headHt-0.001]) cylinder(r=dia/2, h=10, $fn=24);
  }
}

module cutPinHole(pinHole,offset){
  translate([offset,0,0])cube(pinHole,center=true);
  translate([(pinX/2)+10+offset,(pinY/2)+4])csHole();
  translate([(pinX/2)+10+offset,-((pinY/2)+4)])csHole();
  translate([-((pinX/2)+10-offset),(pinY/2)+4])csHole();
  translate([-((pinX/2)+10-offset),-((pinY/2)+4)])csHole();

}

//draw the complte dock
module drawDock(){
  difference(){
    //join the feet to the plate
    union(){
      drawBase(plateDim);
      drawFeet(plateDim,feetDia,feetLen);
    }
    //make cuts
    //cut right and left X slot
    //translate the slots to the edge of the plate plus 9mm to keep on plate
    translate([(plateDim[0]/2)-((.5*slotLen)+9),0,0]) cutXSlot(slotWidth,slotLen,plateDim);
    translate([-((plateDim[0]/2)-((.5*slotLen)+9)),0,0]) cutXSlot(slotWidth,slotLen,plateDim);
    //cut right and left Y slot
    //translate the slots to the end of the X slots (plus 9mm)
    translate([(plateDim[0]/2)-slotLen-9,0,0]) cutYSlot(slotWidth,slotLen+15,plateDim);
    translate([-((plateDim[0]/2)-slotLen-9),0,0]) cutYSlot(slotWidth,slotLen+15,plateDim);
    
    //cut a hole for the pogo pins
    cutPinHole(pinHole,offset);  
    }
}

module dock(){
  rotate([0,180,0]) translate([0,0,-plateDim[2]/2]) drawDock();
}
cutSize = 10; //size of cut

yCut1=[-25,0,25]; 
yCut2=yCut1; 
yCut3=yCut1;

kerf=-0.1;

module yCuts() { 
//yMaleCut(offset = -47, cut = yCut1) dock();

//yFemaleCut(offset = -47, cut = yCut1) yMaleCut(offset = 20, cut = yCut1) dock();

yFemaleCut(offset = 20, cut = yCut1) dock(); 
}

yCuts();

//dock();

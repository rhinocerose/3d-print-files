//  Test Probe Rack for hanging tets probes and other cables
//	Designed by Z System Designs
//		Revision 1 -- added slant capability so that wires slide back not off
//

num = 9;		//  Number of slots -- should be > 1
wide = 20;		//  Spacing between slots
slot = 5;			//  Width of a slot
support = 2;		//  Width of support beween slots
deep = 50;		//  Depth of the rack
thick = 5;		//  Thickness of the rack top
tall = 25;		//  Height of the rack
wall = 3;		//  Thickness of the walls
//holes = 2;		// number of screw holes -- either 2 or 3
screw = .170*25.4;	//Screw size, clearance
slant = 5;



//  Calculate the screw hole locations
odd = num - floor(num/2) * 2;
echo("Extents (L, D, H): ", num*wide, deep, tall);
	
rotate([0,0,90])translate([deep/2-tall*sin(slant)/2, 0, 0])rotate([0, slant, 0])difference()  {
	translate([0, (num-3)*wide/2, 0])
	union()  {
		if(num >= 2) for(i = [1 : num-1])  {
		//	echo("Loop Count = ", i);
			translate([0, -wide* i+wide, 0])ProbeHang();
			}

		translate([0, -wide*num+wide, 0])  ProbeRt();
		translate([0, wide, 0]) ProbeLt();
	}
	if(num > 7)  {
		translate([-wall-1, ((num-3)/2)* wide, tall/2]) rotate([0, 90, 0]) cylinder(r= screw/2, h= wall+2, $fn=60);
		translate([-wall-1, (-(num-3)/2)* wide, tall/2]) rotate([0, 90, 0]) cylinder(r= screw/2, h= wall+2, $fn=60);
	}  else  {
		translate([-wall-1, ((num-1)/2)* wide, tall/2]) rotate([0, 90, 0]) cylinder(r= screw/2, h= wall+2, $fn=60);
		translate([-wall-1, (-(num-1)/2)* wide, tall/2]) rotate([0, 90, 0]) cylinder(r= screw/2, h= wall+2, $fn=60);
	}


	if(odd == 1)
		translate([-wall-1, 0, tall/2]) rotate([0, 90, 0]) cylinder(r= screw/2, h= wall+5, $fn=60);

}

//ProbeLt();     //for testing only
//ProbeRt();


module ProbeHang()  {
	rotate([0, -slant, 0])translate([-deep, 0, 0])difference()  {
		hull()  {
			translate([2, 0, 0])cube([deep-2, wide, 2]);
			translate([1, 0, 1])rotate([-90,0, 0])cylinder(r = 1, h = wide, $fn = 60);
			translate([deep-1+tall*sin(slant), 0, tall-1])rotate([-90,0, 0])cylinder(r = 1, h = wide, $fn = 60);
		}
		translate([0, -1, thick]) cube([deep-wall, wide/2-support/2+1, tall]);
		translate([deep-wall, -1, thick]) rotate([0,slant, 0])translate([-wall,0,0])cube([wall, wide/2-support/2+1, tall]);

		translate([0, wide/2+support/2, thick]) cube([deep-wall, wide/2, tall]);
		translate([deep-wall, wide/2+support/2, thick]) rotate([0,slant,0])translate([-wall,0,0])cube([wall, wide/2, tall]);
//
		translate([deep-slot/2-wall, 0, 0])cylinder(r=slot/2, h = thick, $fn = 60);
		translate([deep-slot/2-wall, wide, 0])cylinder(r=slot/2, h = thick, $fn = 60);
		translate([-slot/2-wall, -1, 0])cube([deep, slot/2+1, thick]);
		translate([-slot/2-wall, wide - slot/2, 0])cube([deep, slot/2+1, thick]);

		}
}

module ProbeRt()  {
	rotate([0, -slant, 0])translate([-deep, 0, 0])difference()  {
		hull()  {
			translate([2, 0, 0])cube([deep-2, wide, 2]);
			translate([1, 0, 1])rotate([-90,0, 0])cylinder(r = 1, h = wide, $fn = 60);
			translate([deep-1+tall*sin(slant), 0, tall-1])rotate([-90,0, 0])cylinder(r = 1, h = wide, $fn = 60);
		}

		translate([0, wide/2+support/2, thick]) cube([deep-wall, wide/2+support/2+1, tall]);
		translate([deep-wall, wide/2+support/2, thick]) rotate([0,slant,0])translate([-wall,0,0])cube([wall, wide/2, tall]);
		translate([deep-slot/2-wall, wide, 0])cylinder(r=slot/2, h = thick, $fn = 60);
		translate([0, -1, 0])cube([deep+1+tall*sin(slant), wide/2-wall+support/2+1, tall+1]);
		translate([0, wide-slot/2, 0])cube([deep-slot/2-wall, slot/2+1, thick+1]);
		
		}
}

module ProbeLt()  {
	rotate([0, -slant, 0])translate([-deep, 0, 0])difference()  {
		hull()  {
			translate([2, 0, 0])cube([deep-2, wide, 2]);
			translate([1, 0, 1])rotate([-90,0, 0])cylinder(r = 1, h = wide, $fn = 60);
			translate([deep-1+tall*sin(slant), 0, tall-1])rotate([-90,0, 0])cylinder(r = 1, h = wide, $fn = 60);
		}


		translate([0, -1, thick]) cube([deep-wall, wide/2-support/2+1, tall]);
		translate([deep-wall, -1, thick]) rotate([0,slant, 0])translate([-wall,0,0])cube([wall, wide/2-support/2+1, tall]);

		translate([deep-slot/2-wall, 0, 0])cylinder(r=slot/2, h = thick+1, $fn = 60);
		translate([0, -1, 0])cube([deep-slot/2-wall, slot/2+1, thick+1]);
		translate([0, wide/2+wall-support/2, 0])cube([deep+1+tall*sin(slant), wide/2, tall+1]);
		
		}
}
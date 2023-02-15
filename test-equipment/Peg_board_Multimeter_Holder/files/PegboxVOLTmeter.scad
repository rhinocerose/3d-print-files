// ----------------------------------------------------------
//         Pegboard box for DT-830 Digital Multimeter
//                 by Jan-Willem
//
//                   08.01.2017  
//
//         License CC BY-NC-SA 3.0
// ----------------------------------------------------------


//   07.01.2017 first version printed
//   08.01.2017 release on thingiverse

//    infill  = 50 %
//    shell = 0.8    (2 x 0.4)
//    Support type = Everywhere

//    Cura and Ultimaker original


$fn=30;
inch = 25.4; 

wall = 1.5;   // nice fit for 2 x double wall 0.4 print head 

// dimension of the box in inch units (peg board units)
Xdim = 4;    // width
Ydim = 2;    // depth
Zdim = 3;    // height of box

// adjust depth (not a multiple of inch sizes)
YYdim = 28 + 2*wall;    // internal size 28 mm (for multimeter)

XXdim = Xdim*inch;    // width = standard inch size

// lower pin dimensions
pegx = 3;
pegy = 7;   // depth of pin
pegz = 4;



// make the pegboard box
// ---------------------
//           centre box around pegs

Xwindow = (XXdim-inch)+pegx-10-10;   // 10 = flap size

difference()
 { translate([-(XXdim-Xdim*inch)/2,-YYdim,0]) EmptyBox(XXdim+pegx,YYdim,Zdim*inch+pegz,wall,6);
    translate([10+inch,-YYdim-2,wall+5
     ]) cube([Xwindow,5,100]);     
 }   

// add wall between voltmeter and probe area
 translate([inch,-YYdim,0]) cube([wall,YYdim,Zdim*inch+pegz]);


LowerPeg(0,0,0);
LowerPeg(Xdim*inch,0,0);

UpperPeg(0,0,Zdim*inch);
UpperPeg(Xdim*inch,0,Zdim*inch);




// Lower peg pin
module LowerPeg(xx,yy,zz)
{ translate([xx,yy-wall,zz]) cube([pegx, pegy+wall, pegz]);
}


// Upper curved peg pin
module UpperPeg(xx,yy,zz)
{ translate([xx,yy-wall,zz]) cube([pegx, pegy+wall,pegz]);
translate([xx,yy-wall+pegy+pegz/2,zz+pegz/2]) rotate([0,90,0]) cylinder(r=pegz/2, h=pegx);
translate([xx,yy-wall+pegy+pegz,zz+pegz/2]) rotate([75,0,0]) cube([pegx,pegy,pegz]);
}




// ------------------------------------------------------
// EmptyBox, JWW, x,y,z,wall  r=riadius of rounding
// ------------------------------------------------------
module EmptyBox(xx,yy,zz,wall,rr)
{ difference()
   { HalfRoundedBox(xx,yy,zz,rr);                                 
     translate([wall,wall,wall]) RoundedBox(xx-2*wall,yy-2*wall,zz,rr-wall);
   }
}


// ------------------------------------------------------
// Rounded box, JWW, x,y,z  r=riadius of rounding
// ------------------------------------------------------
module RoundedBox(xx,yy,zz,rr)
{ hull()
	{translate([rr,rr,0])       cylinder(r=rr,h=zz);
	 translate([rr,yy-rr,0])    cylinder(r=rr,h=zz);
	 translate([xx-rr,rr,0])    cylinder(r=rr,h=zz);
	 translate([xx-rr,yy-rr,0]) cylinder(r=rr,h=zz);
     }
}


module HalfRoundedBox(xx,yy,zz,rr)
{ hull()
	{translate([rr,rr,0])       cylinder(r=rr,h=zz);
	 translate([0,yy-1,0])      cube([1,1,zz]);
	 translate([xx-rr,rr,0])    cylinder(r=rr,h=zz);
	 translate([xx-1,yy-1,0])   cube([1,1,zz]);
     }
}

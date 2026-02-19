// Forked from:
// https://www.thingiverse.com/thing:189264 by @Arvin

// Also inspired by:
// https://makerworld.com/en/models/14225 by @MadMax3D

// License: CC-Attribution

/* [Box Variables] */
itemsShown="both"; // [both,box,lid]

boxLength=80; // [10:0.1:200]
boxWidth=150; // [10:0.1:200]
boxHeight=50; // [10:0.1:200]

lidColor = "#FFFFFF"; // color
lidContentColor = "#FFFFFF"; // color
boxColor = "#FFFFFF"; // color
lidContent = "text"; // [text,png,svg]
rotateLidContent = true; // true;
// Notch in the lid
withNotch=true;//true;//[true:false]

/* [ Other Dimensions ] */
cornerRadius=5; // [0:0.1:10]
wallThickness=2; // [0.8:0.05:10]
bottomThickness=2; // [0.8:0.05:10]
lidThickness=2; // [0.8:0.05:10]

/* [ Text Options ] */
text="Tool Box";
textSize=15; // [5:1:50]
textThickness=1; // [0.4:0.05:10]

/* [ PNG Options] */
// !Avoid using complicating image!
pngFile = "default.png";
pngScale = [0.15, 0.15, 0.02]; //[0:0.01:1]

/* [ SVG Options] */
svgFile = "default.svg";
svgThickness=2; // [0.4:0.05:10]
svgScale = 0.3; //[0.01:0.1:50]


/* [Others] */
lidEdgeThickness=0.5;
topClearance=0.2;


/* [Global] */
if (itemsShown=="box") showBox();
if (itemsShown=="lid") showLid();
if (itemsShown=="both"){showBox();showLid();}


module showLid(){
	translateX = (boxLength>boxWidth)?-boxLength/2:(-2*wallThickness);
	translateY = (boxLength>boxWidth)?(-2*wallThickness):wallThickness-boxWidth/2;
	
	translate ([translateX, translateY, 0]) 
	roundBoxLid(l=boxLength-wallThickness-topClearance,
				w=boxWidth-2*wallThickness-2*topClearance,
				h=lidThickness,
				et=lidEdgeThickness,
				r=cornerRadius-wallThickness,
				dynamicPos=true, showContent=true);
}

module showBox(){
	color(boxColor) {
		translateX = (boxLength>boxWidth)?-boxLength/2:0;
		translateY = (boxLength>boxWidth)?0:-boxWidth/2;

		translate([translateX , translateY, 0])
		round_box(l=boxLength,
				w=boxWidth,
				h=boxHeight,
				bt=bottomThickness,
				wt=wallThickness,
				lt=lidThickness,
				r=cornerRadius);
	}
}

module round_box(l=40,w=30,h=30,bt=2,wt=2,tc=0.2,lt=2,r=5){
	difference() { 
		round_cube(l=l,w=w,h=h-lt,r=r);
		translate ([wt, wt, bt]) 
		round_cube(l=l-wt*2,w=w-wt*2,h=h,r=r-wt);
	}
	//use a second box rim to support the lid
	roundBoxRim();
	translate ([0, 0, -wt]) roundBoxRim();
}

module roundBoxRim(l=boxLength,
				   w=boxWidth,
				   h=boxHeight,
				   et=lidEdgeThickness,
				   r=cornerRadius,
				   wt=wallThickness,
				   lt=lidThickness)
{
	difference() { 
		translate ([0, 0, h-lt]) 
		round_cube(l=l,w=w,h=lt,r=r);
		translate ([wt+lt,wt+lt-et*2,h-lt-0.1]) 
		round_cube(l=l*2,w=w-2*(wt+lt)+4*et,h=lt+0.2,r=r-wt+lt);

		//subtract out a lid to make the ledge
		translate ([wt, w-wt, h-lt-0.1])
		roundBoxLid(l=l*2,w=w-2*wt,h=lt+0.1,tc=0.0,et=lidEdgeThickness,r=r-wt,notch=false, showContent=false);
	}                       
}

module generateLidContent() {
	if (lidContent=="text")
		linear_extrude(height = textThickness)
				text(text, size = textSize, font = "HarmonyOS Sans SC:style=Black", halign = "center", valign = "center");
	else if (lidContent=="png")
		scale([pngScale[0], pngScale[1], pngScale[2]])
				surface(file = pngFile, center = true, invert = false);
	else
		scale(svgScale, svgScale, svgScale)
				linear_extrude(height = svgThickness / svgScale) import(file = svgFile, center = true);
}

module roundBoxLid(l=40,w=30,h=3,et=0.5,r=5,notch=withNotch, dynamicPos=false, showContent=true){
	translateX = dynamicPos ? (boxLength > boxWidth ? l : 0) : l;
	translateY = dynamicPos ? (boxLength > boxWidth ? 0 : w) : 0;

	translate ([translateX, translateY, 0]) 
	rotate (a = [0, 0, 180]){ 
		color(lidColor)
			difference(){
				round_cube(l=l,w=w,h=h,r=r);
				//slice angled edges off but leave an edge greater than zero
				translate ([-1, 0, et]) rotate (a = [45, 0, 0])  cube (size = [l+2, h*2, h*2]); 
				translate ([-1, w, et]) rotate (a = [45, 0, 0])  cube (size = [l+2, h*2, h*2]); 
				translate ([l, -1, et]) rotate (a = [45, 0, 90]) cube (size = [w+2, h*2, h*2]); 
				if (notch==true){
					translate([2,w/2,h+0.001]) thumbNotch(notchHeight=h-0.5);
				}
			}
		color(lidContentColor)
			translate([ l / 2, w / 2, h ]) {
			if (rotateLidContent)
				rotate([ 0, 0, -90 ])
				generateLidContent();
			else
				generateLidContent();
			}
	}
}

//thumbNotch(thumbR=12/2,angle=72,notchHeight=1.5);
module thumbNotch(
	thumbR=12/2,
	angle=72,
	notchHeight=2)
{
	size=10*thumbR;

	rotate([0,0,90])
	difference(){
		translate([0,
				  (thumbR*sin(angle)-notchHeight)/tan(angle),
				   thumbR*sin(angle)-notchHeight])
		rotate([angle,0,0])
		cylinder(r=thumbR,h=size,$fn=30);

		translate([-size,-size,0])
		cube(size*2);
	}
}

//round_cube();
module round_cube(l=40,w=30,h=20,r=5, $fn=30){
	hull () { 
		translate ([r, r, 0]) cylinder (h = h, r=r);
		translate ([r, w-r, 0]) cylinder (h = h, r=r);
		translate ([l-r,w-r, 0]) cylinder (h = h, r=r);
		translate ([l-r, r, 0]) cylinder (h = h, r=r);
	}
}

                   .:                     :,                                          
,:::::::: ::`      :::                   :::                                          
,:::::::: ::`      :::                   :::                                          
.,,:::,,, ::`.:,   ... .. .:,     .:. ..`... ..`   ..   .:,    .. ::  .::,     .:,`   
   ,::    :::::::  ::, :::::::  `:::::::.,:: :::  ::: .::::::  ::::: ::::::  .::::::  
   ,::    :::::::: ::, :::::::: ::::::::.,:: :::  ::: :::,:::, ::::: ::::::, :::::::: 
   ,::    :::  ::: ::, :::  :::`::.  :::.,::  ::,`::`:::   ::: :::  `::,`   :::   ::: 
   ,::    ::.  ::: ::, ::`  :::.::    ::.,::  :::::: ::::::::: ::`   :::::: ::::::::: 
   ,::    ::.  ::: ::, ::`  :::.::    ::.,::  .::::: ::::::::: ::`    ::::::::::::::: 
   ,::    ::.  ::: ::, ::`  ::: ::: `:::.,::   ::::  :::`  ,,, ::`  .::  :::.::.  ,,, 
   ,::    ::.  ::: ::, ::`  ::: ::::::::.,::   ::::   :::::::` ::`   ::::::: :::::::. 
   ,::    ::.  ::: ::, ::`  :::  :::::::`,::    ::.    :::::`  ::`   ::::::   :::::.  
                                ::,  ,::                               ``             
                                ::::::::                                              
                                 ::::::                                               
                                  `,,`


https://www.thingiverse.com/thing:1134586
Parametric Probe Holder by billgertz is licensed under the Creative Commons - Attribution license.
http://creativecommons.org/licenses/by/3.0/

# Summary

<b>This object features Open in Customizer</b>

So you have DMM, Oscope and other equipment probes or cables, but they seem to "walk away"? Why not corral them with this parametric probe holder! 

This thing has been used for drafting pens, white board markers and trimming tools. But that's not all; this holder can hold any cylindrical thing. It can easily manage test cables, tools, syringes, and even test tubes (by changing the clasp arc to a closed ring). 

Just download, or better yet open in customizer, and edit. Simply enter in number of probes, the shaft diameter and guard dimensions. You can leave the rest at the defaults if you really want to get in and get making.

You can optionally change the mount hole diameter, fastener (screw or bolt) type, and if you want a countersunk mount. Even add a center tab on a long holder.

You can also edit some advanced options for even finer control over the holder, but it's strictly not necessary.

Lastly you can make a tailored or bespoke holder to collect different kinds of probes in one holder. We show you how by editing the OpenSCAD file as outlined in instructions below.

# Print Settings

Printer: Felix 3.1
Rafts: No
Supports: Yes
Resolution: 0.20 to 0.25 mm
Infill: 20 to 40%

Notes: 
Print at higher resolutions for a better looking part. But let's be honest, this is probe holder - nobody is going to care what it looks like. It just has to work; use the lowest resolution that still gives you a sturdy part. At typical probe sizes only solid fill is created by slicers, so the percentage won't matter.

Suggest you print this thing on its side (rotate x-axis 90 degrees) with supports, so the mount holes and tabs print cleanly.

# Tailored or Bespoke Holder

## Step 1: Find build_vector

So if you want to make a tailored or bespoke holder, you will need to download and edit the  .scad file for this object. You will find a vector (OpenSCAD for Array) commented out in the file (see lines 76 to 81 in the screenshot below). Locate all the lines for declaration of <i>build_vector</i> to the very end of the declaration. This includes the line that contains <i>];</i> by itself.

![Alt text](https://thingiverse-production-new.s3.amazonaws.com/assets/4d/dd/2e/70/93/Build_Vector_Commented_Out.png)
Commented out build_vector

## Step 2: Activate build_vector

Now simply remove the double slash <i>//</i> at the beginning of each of these lines (like the screenshot below).

![Alt text](https://thingiverse-production-new.s3.amazonaws.com/assets/13/ff/1c/b3/1f/Build_Vector_Activated.png)
Activated build_vector

## Step 3: Edit build_vector

Now edit the vector for your probes. For example you have two pair of probes:

- 2 DMM Probes: 8.4 mm in diameter with a circular guard 12.5 mm in diameter
- 2 Oscope Probes: 11.2 mm in diameter with a circular guard 14.6 mm in diameter 

The edited vector would look like the screenshot below.

![Alt text](https://thingiverse-production-new.s3.amazonaws.com/assets/8f/17/ad/43/58/Build_Vector_Example.png)
Example build_vector

## Step 4: Generate

Now generate the GCAL and export the STL. If this is your first time using OpenSCAD; it's easy! Just hit the GCAL generate button (highlighted in red) and then the STL export button (highlighted in green) from the edit window (shown below).

![Alt text](https://thingiverse-production-new.s3.amazonaws.com/assets/7a/2b/ba/f3/6d/Object_Generate.png)
Button locations

# Instructions

## Customizer Parameters

Edit the parameters to make the probe holder as needed. In Customizer the OpenSCAD code generates a holder that will hold many probes of the same type.   

The customizer and variables in the source are divided into only general, mount tabs and advanced sections:   

* <b>General</b>  
    - Count
Number of probes for this holder
    - Probe Diameter (mm)
 Diameter of the probe shaft or handle
    - Guard Width (mm)
Diameter of guard along the width
    - Guard Depth (mm)
Diameter of the guard perpendicular to the mounting plate
 
* <b>Mount Tabs</b>
    - Center Tab (auto/ yes/ no)
Add center tab (yes = add tab, auto = automatically add tab on 'long' flexible holder)
    - Mount Hole (yes/ no)
Make holes in mounting tabs (yes = make holes)
    - Mount Hole Diameter (mm)
Width of screw used to mount holder to cabinet or wall
    - Fastener Type
Type of bolt or screw head
    - Countersink (yes/ no)
Countersink the mounting hole (yes = countersink)

* <b>Advanced</b>  
Normally just go with the defaults but alter at your own risk. Changes here may make unprintable parts.  

    - Holder Height (mm)  
    - Mount Thickness (mm)
    - Clasp Arc (degrees)
Set arc width for the maw of the probe clasp (360 = closed ring)
    - Clasp Thickness (mm)
Wall thickness of the clasp
    - Clasp Clearance (mm)
Space between neighboring clasps
    - Resolution  
Line segments used to make a circle. Note the higher the number the longer the render will grind making your part. At "Insane" it may take longer than 30 minutes before customizer coughs up your part.  
    - Oversize (mm)  
How much larger to make the clasp diameter for a good fit  

## Revison History

This is the fifteenth revision (v0.8.13) that has implemented the following fixes since the original:  

- Migration from previous project 
- Added guard depth and build vector 
- Beta code release
- Added oversize for better clasp fit   
- Changed to clearance rather than proportional object modeling   
- Removed edge filleting 
- Fixed clasp attachment calculation and clarified wording
- Fixed right tab placement (thanks to <i>furicks</i>)
- Smallest probe diameter improved to 4mm
- Smallest probe diameter further improved to less than 1mm
- Tweaked clasp attachment to work better with smaller probe diameters
- Fixed clasp build modules for cleaner clasps
- Added option to create without holes in mounting tabs (thanks to <i>RobinSwa</i>)
- Modified guard width and depth limits to up 20mm guards in Customizer
- Add center tab and altered customizer oversize parameter to 1/10 of mm
- Set center tab to autogenerate on long probe holder and set oversize default to .1 mm
- Fixed right tab placement gap between probe body and tab
- Fixed oversize adjustment calculation

Seems the design is (mostly) stable but evolving.
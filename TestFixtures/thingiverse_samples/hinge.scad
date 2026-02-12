// Simple Print-in-Place Hinge

/* [Dimensions] */
width = 30;           // [15:60]
length = 40;          // [20:80]
thickness = 3;        // [2:5]
pin_diameter = 4;     // [3:6]
clearance = 0.3;      // [0.2:0.1:0.5]

hinge_radius = pin_diameter/2 + thickness;

// Left plate
cube([length, width/2, thickness]);
translate([length, width/4, hinge_radius])
    rotate([-90, 0, 0])
        cylinder(h=width/2, r=hinge_radius, $fn=32);

// Right plate
translate([0, width/2, 0])
    cube([length, width/2, thickness]);
translate([length, width/4, hinge_radius])
    rotate([-90, 0, 0])
        difference() {
            cylinder(h=width/2, r=hinge_radius - clearance, $fn=32);
            translate([0, 0, -1])
                cylinder(h=width/2 + 2, r=pin_diameter/2, $fn=32);
        }

// Pin
translate([length, width/4 - 2, hinge_radius])
    rotate([-90, 0, 0])
        cylinder(h=width + 4, r=pin_diameter/2 - clearance, $fn=32);

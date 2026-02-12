// Parametric Phone Stand

/* [Dimensions] */
base_width = 80;      // [50:120]
base_depth = 60;      // [40:80]
base_height = 5;      // [3:10]
back_height = 100;    // [60:150]
back_thickness = 4;   // [2:8]
angle = 75;           // [60:85] Stand angle

/* [Phone Slot] */
slot_width = 15;      // [10:20]
slot_depth = 3;       // [2:5]

// Base
cube([base_width, base_depth, base_height]);

// Back support
translate([0, base_depth - back_thickness, base_height])
    rotate([90 - angle, 0, 0])
        cube([base_width, back_height, back_thickness]);

// Phone slot
translate([(base_width - slot_width)/2, 10, base_height])
    cube([slot_width, slot_depth, 15]);

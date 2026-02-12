// Cable Clip - Simple utility print

/* [Clip Dimensions] */
cable_diameter = 6;   // [3:1:12] Cable diameter
wall = 2;             // [1.5:0.5:4] Wall thickness
base_width = 15;      // [10:25]
base_height = 3;      // [2:5]
screw_hole = 3.5;     // [2:5] Screw hole diameter

clip_radius = cable_diameter/2 + wall;
clip_height = clip_radius * 2;
gap = cable_diameter * 0.6;

// Base plate
cube([base_width, base_width, base_height], center=true);

// Clip
translate([0, 0, base_height/2])
    difference() {
        cylinder(h=clip_height, r=clip_radius, $fn=32);
        // Cable channel
        translate([0, 0, -1])
            cylinder(h=clip_height+2, r=cable_diameter/2, $fn=32);
        // Entry gap
        translate([0, clip_radius/2, -1])
            cube([gap, clip_radius, clip_height+2], center=true);
    }

// Screw hole
translate([0, 0, -1])
    cylinder(h=base_height+2, d=screw_hole, center=true, $fn=16);

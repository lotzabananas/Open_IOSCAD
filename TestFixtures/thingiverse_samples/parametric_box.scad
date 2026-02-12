// Parametric Box with Lid
// A simple parametric box from Thingiverse

/* [Box Dimensions] */
width = 40;           // [10:100] Box width
depth = 30;           // [10:80] Box depth
height = 25;          // [10:50] Box height
wall = 2;             // [1:5] Wall thickness

/* [Options] */
show_lid = true;      //
lid_height = 5;       // [3:15] Lid height
rounded = false;      //

// Box body
difference() {
    cube([width, depth, height]);
    translate([wall, wall, wall])
        cube([width - 2*wall, depth - 2*wall, height]);
}

// Lid
if (show_lid) {
    translate([0, 0, height + 2])
        difference() {
            cube([width, depth, lid_height]);
            translate([wall, wall, -1])
                cube([width - 2*wall, depth - 2*wall, lid_height]);
        }
}

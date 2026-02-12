// Parametric Electronics Enclosure

/* [Enclosure Size] */
inner_width = 60;     // [30:120]
inner_depth = 40;     // [20:80]
inner_height = 25;    // [15:50]
wall = 2;             // [1.5:0.5:4]
corner_radius = 3;    // [0:8]

/* [Features] */
vent_holes = true;    //
mounting_posts = true; //
post_diameter = 6;    // [4:10]
post_height = 8;      // [4:15]
screw_diameter = 2.5; // [2:4]

outer_width = inner_width + 2*wall;
outer_depth = inner_depth + 2*wall;
outer_height = inner_height + wall;

// Main body
difference() {
    // Outer shell
    cube([outer_width, outer_depth, outer_height]);

    // Inner cavity
    translate([wall, wall, wall])
        cube([inner_width, inner_depth, inner_height + 1]);

    // Vent holes on side
    if (vent_holes) {
        for (i = [0:4]) {
            translate([-1, 10 + i*6, wall + 5])
                rotate([0, 90, 0])
                    cylinder(h=outer_width+2, d=2, $fn=8);
        }
    }
}

// Mounting posts
if (mounting_posts) {
    for (x = [wall + post_diameter/2, outer_width - wall - post_diameter/2]) {
        for (y = [wall + post_diameter/2, outer_depth - wall - post_diameter/2]) {
            translate([x, y, wall])
                difference() {
                    cylinder(h=post_height, d=post_diameter, $fn=16);
                    translate([0, 0, -1])
                        cylinder(h=post_height+2, d=screw_diameter, $fn=8);
                }
        }
    }
}

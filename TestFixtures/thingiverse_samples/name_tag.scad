// Name Tag (text() will fail gracefully until v2.0)

/* [Tag Settings] */
tag_width = 70;       // [40:100]
tag_height = 25;      // [15:40]
tag_depth = 3;        // [2:5]
corner_r = 3;         // [0:8]
hole_diameter = 3;    // [2:5]

// Base plate
difference() {
    cube([tag_width, tag_height, tag_depth]);

    // Lanyard hole
    translate([5, tag_height/2, -1])
        cylinder(h=tag_depth+2, d=hole_diameter, $fn=16);
}

// Note: text() not yet supported in v1.0
// text("OpenSCAD", size=10);

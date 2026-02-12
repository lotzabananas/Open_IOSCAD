// Simple Gear Generator

/* [Gear Parameters] */
teeth = 20;           // [8:1:60] Number of teeth
module_val = 2;       // [1:0.5:5] Module (tooth size)
thickness = 5;        // [2:20] Gear thickness
bore = 5;             // [0:15] Center bore diameter

// Calculated values
pitch_radius = teeth * module_val / 2;
outer_radius = pitch_radius + module_val;
root_radius = pitch_radius - 1.25 * module_val;
tooth_angle = 360 / teeth;

// Gear body
difference() {
    // Gear profile
    linear_extrude(height=thickness) {
        // Simple approximation using circles at tooth positions
        circle(r=pitch_radius, $fn=teeth*4);
    }

    // Center bore
    if (bore > 0) {
        translate([0, 0, -1])
            cylinder(h=thickness+2, d=bore, $fn=32);
    }
}

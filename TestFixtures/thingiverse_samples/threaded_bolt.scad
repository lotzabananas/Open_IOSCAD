// Threaded Bolt (simplified thread approximation)

/* [Bolt Parameters] */
bolt_diameter = 8;    // [4:1:16]
bolt_length = 25;     // [10:50]
head_diameter = 14;   // [8:24]
head_height = 5;      // [3:8]
thread_pitch = 1.25;  // [0.5:0.25:3]
$fn = 32;

// Head
cylinder(h=head_height, d=head_diameter);

// Shaft with thread approximation
translate([0, 0, head_height])
    difference() {
        cylinder(h=bolt_length, d=bolt_diameter);

        // Thread grooves (simplified)
        for (i = [0:thread_pitch:bolt_length]) {
            translate([0, 0, i])
                rotate_extrude()
                    translate([bolt_diameter/2 - 0.3, 0, 0])
                        polygon(points=[
                            [0, 0],
                            [0.6, thread_pitch/4],
                            [0, thread_pitch/2]
                        ]);
        }
    }

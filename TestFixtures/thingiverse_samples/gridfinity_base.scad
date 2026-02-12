// Gridfinity Base Plate (simplified)

/* [Grid Settings] */
grid_x = 3;           // [1:1:8] Grid units X
grid_y = 2;           // [1:1:6] Grid units Y
unit_size = 42;       // [42] Unit size (mm)
height = 5;           // [3:10] Base height

/* [Options] */
magnet_holes = true;  //
magnet_diameter = 6.5; // [6:8]
magnet_depth = 2.4;   // [2:3]

base_width = grid_x * unit_size;
base_depth = grid_y * unit_size;

difference() {
    cube([base_width, base_depth, height]);

    // Grid pattern
    for (x = [0:grid_x-1]) {
        for (y = [0:grid_y-1]) {
            translate([x * unit_size + 0.5, y * unit_size + 0.5, 1])
                cube([unit_size - 1, unit_size - 1, height]);
        }
    }

    // Magnet holes
    if (magnet_holes) {
        for (x = [0:grid_x-1]) {
            for (y = [0:grid_y-1]) {
                // Four corners per cell
                for (cx = [x * unit_size + 4, (x+1) * unit_size - 4]) {
                    for (cy = [y * unit_size + 4, (y+1) * unit_size - 4]) {
                        translate([cx, cy, -0.01])
                            cylinder(h=magnet_depth+0.01, d=magnet_diameter, $fn=24);
                    }
                }
            }
        }
    }
}

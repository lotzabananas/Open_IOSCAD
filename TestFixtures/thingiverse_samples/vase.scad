// Simple Vase using rotate_extrude

/* [Vase Shape] */
height = 80;          // [40:150]
bottom_radius = 15;   // [10:30]
top_radius = 25;      // [15:50]
wall_thickness = 2;   // [1:4]
$fn = 64;

// Outer profile points
profile = [
    [bottom_radius, 0],
    [bottom_radius - 2, 10],
    [bottom_radius, 20],
    [top_radius - 5, 50],
    [top_radius, height - 10],
    [top_radius - 1, height],
    [top_radius - wall_thickness - 1, height],
    [top_radius - wall_thickness, height - 10],
    [top_radius - wall_thickness - 5, 50],
    [bottom_radius - wall_thickness, 20],
    [bottom_radius - wall_thickness - 2, 10],
    [bottom_radius - wall_thickness, 3],
    [0, 3],
    [0, 0]
];

rotate_extrude($fn=$fn)
    polygon(points=profile);

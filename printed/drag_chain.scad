//
// NopSCADlib Copyright Chris Palmer 2020
// nop.head@gmail.com
// hydraraptor.blogspot.com
//
// This file is part of NopSCADlib.
//
// NopSCADlib is free software: you can redistribute it and/or modify it under the terms of the
// GNU General Public License as published by the Free Software Foundation, either version 3 of
// the License, or (at your option) any later version.
//
// NopSCADlib is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
// without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
// See the GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License along with NopSCADlib.
// If not, see <https://www.gnu.org/licenses/>.
//

//
//! Parametric cable drag chain to limit the bend radius of a cable run.
//!
//! Each link has a maximum bend angle, so the mininium radius is proportional to the link length.
//!
//! The travel prpoery is how far it can move in each direction, i.e. half the maximum travel if the chain is mounted in the middle of the travel.
//

include <../core.scad>
use <../utils/horiholes.scad>
use <../utils/maths.scad>

function drag_chain_name(type)  = type[0]; //! The name to allow more than one in a project
function drag_chain_size(type)  = type[1]; //! The internal size and link length
function drag_chain_travel(type)= type[2]; //! X travel
function drag_chain_wall(type)  = type[3]; //! Side wall thickness
function drag_chain_bwall(type) = type[4]; //! Bottom wall
function drag_chain_twall(type) = type[5]; //! Top wall

function drag_chain_radius(type) = //! The bend radius at the pivot centres
    let(s = drag_chain_size(type))
        s.x / 2 / sin(360 / 16);

function drag_chain_z(type) = //! Outside dimension of a 180 bend
    let(os = drag_chain_outer_size(type), s = drag_chain_size(type))
        2 * drag_chain_radius(type) + os.z;

function drag_chain(name, size, travel, wall = 1.6, bwall = 1.5, twall = 1.5) = //! Constructor
    [name, size, travel, wall, bwall, twall];

clearance = 0.1;

function drag_chain_outer_size(type) =     //! Link outer dimensions
    let(s = drag_chain_size(type), z = s.z + drag_chain_bwall(type) + drag_chain_twall(type))
        [s.x + z, s.y + 4 * drag_chain_wall(type) + 2 * clearance, z];


module drag_chain_link(type, start = false, end = false) {
    stl(str(drag_chain_name(type), "_drag_chain_link", start ? "_start" : end ? "_end" : ""));

    s = drag_chain_size(type);
    wall = drag_chain_wall(type);
    bwall = drag_chain_bwall(type);
    twall = drag_chain_twall(type);
    os = drag_chain_outer_size(type);
    r = os.z / 2;
    pin_r = r / 2;
    inner_x_normal = s.x - wall;
    inner_x = start ? 0 : s.x - inner_x_normal;
    roof_x_normal = 2 * r - twall;
    roof_x = start ? 0 : roof_x_normal;
    floor_x = start ? 0 : 2 * r;
    cam_r = inner_x_normal - clearance - r;
    cam_x = min(sqrt(max(sqr(cam_r) - sqr(r - twall), 0)), r);
    outer_end_x = end ? os.x : s.x - clearance;

    for(side = [-1, 1])
        rotate([90, 0, 0]) {
            // Outer cheeks
            translate_z(side * (os.y / 2 - wall / 2))
                linear_extrude(wall, center = true)
                    difference() {
                        hull() {
                            if(start)
                                translate([floor_x, 0])
                                    square([eps, os.z]);
                            else
                                translate([r, r])
                                    rotate(180)
                                        teardrop(r = r, h = 0);

                            translate([outer_end_x - eps, 0])
                                square([eps, os.z]);
                        }
                        if(!start)
                            translate([r, r])
                                horihole(pin_r, r);
                    }
            // Inner cheeks
            translate_z(side * (s.y / 2 + wall / 2))
                linear_extrude(wall, center = true)
                    difference() {
                        union() {
                            hull() {
                                if(!end) {
                                    translate([s.x + r, r])
                                        rotate(180)
                                            teardrop(r = r, h = 0);

                                    translate([s.x + r, twall])
                                        square([cam_x, eps]);
                                }
                                else
                                    translate([s.x + 2 * r - eps, 0])
                                        square([eps, os.z]);

                                translate([inner_x, 0])
                                    square([eps, os.z]);
                            }
                        }
                        // Cutout for top wall
                        if(!end)
                            intersection() {
                                translate([s.x, 0])
                                    square([3 * r, twall]);  // When straight

                                translate([s.x + r, r])
                                     rotate(-45)
                                        translate([-r + roof_x_normal, -r - twall]) // When bent fully
                                            square(os.z);
                            }
                    }
            // Pin
            if(!end)
                translate([s.x + r, r, side * (s.y / 2 + wall + clearance)])
                    horicylinder(r = pin_r, z = r, h = 2 * wall);

            // Cheek joint
            translate([inner_x, 0, side * (s.y / 2 + wall) - 0.5])
                cube([outer_end_x - inner_x, os.z, 1]);
        }

    // Roof, actually the floor when printed
    roof_end = end ? s.x + 2 * r : s.x + r - twall - clearance;
    translate([roof_x, -s.y / 2 - wall])
        cube([roof_end - roof_x , s.y + 2 * wall, twall]);

    translate([roof_x, -os.y / 2 + 0.5])
        cube([s.x - clearance - roof_x, os.y - 1, twall]);

    // Base, actually the roof when printed
    floor_end = end ? s.x + 2 * r : s.x + r;
    translate([floor_x, -s.y / 2 - wall, os.z - bwall])
        cube([floor_end - floor_x, s.y + 2 * wall, bwall]);

    translate([floor_x, -os.y / 2 + 0.5,  os.z - bwall])
        cube([s.x - floor_x - clearance, os.y -1, bwall]);

    if(show_supports() && !end) {
        for(side = [-1, 1]) {
            w = 2.1 * extrusion_width;
            translate([s.x + r + cam_x - w / 2, side * (s.y / 2 + wall / 2), twall / 2])
                cube([w, wall, twall], center = true);

            h = round_to_layer(r - pin_r / sqrt(2));
            y = s.y / 2  + max(wall + w / 2 + clearance, 2 * wall + clearance - w / 2);
            translate([s.x + r, side * y, h / 2])
                cube([pin_r * sqrt(2), w, h], center = true);

            gap = cam_x - pin_r / sqrt(2) + extrusion_width;
            translate([s.x + r + cam_x - gap / 2, side * (s.y / 2 + wall + clearance / 2), layer_height / 2])
                cube([gap, 2 * wall + clearance, layer_height], center = true);
        }
    }
}

module drag_chain_assembly(type, pos = 0) { //! Drag chain assembly
    s = drag_chain_size(type);
    r = drag_chain_radius(type);
    travel = drag_chain_travel(type);
    links = ceil(travel / s.x);
    actual_travel = links * s.x;
    z = drag_chain_outer_size(type).z;

    zb = z / 2;                                     // z of bottom track
    c = [actual_travel / 2 + pos / 2, 0, r + zb];   // centre of bend

    points = [                                      // Calculate list of hinge points
        for(i = 0, p = [0, 0, z / 2 + 2 * r]; i < links + 5;
            i = i + 1,
            dx = p.z > c.z ? s.x : -s.x,
            p = max(p.x + dx, p.x) <= c.x ? p + [dx, 0, 0]      // Straight sections
                  : let(q = circle_intersect(p, s.x, c, r))
                        q.x <= c.x ? [p.x - sqrt(sqr(s.x) - sqr(p.z - zb)), 0, zb] // Transition back to straight
                                   : q) // Circular section
        p
    ];
    npoints = len(points);

    module link(n)                                  // Position and colour link with origin at the hinge hole
        translate([-z / 2, 0, -z / 2])
            stl_colour(n % 2 ? pp1_colour : pp2_colour)
                drag_chain_link(type, start = n == -1, end = n == npoints - 1);

    assembly(str(drag_chain_name(type), "_drag_chain")) {
        for(i = [0 : npoints - 2]) let(v = points[i+1] - points[i])
            translate(points[i])
                rotate([0, -atan2(v.z, v.x), 0])
                    link(i);

        translate(points[0] - [s.x, 0, 0])
            link(-1);

        translate(points[npoints - 1])
            hflip()
                link(npoints - 1);
    }
}
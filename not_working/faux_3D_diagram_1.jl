#!/usr/bin/env julia
# faux_3D_fixed_terminal2.jl
# Terminal-safe faux-3D Trenberth (CairoMakie).
# Fix: avoid strokecolor = nothing (use transparent RGBA instead).

using CairoMakie
CairoMakie.activate!()   # force non-GL backend

using Colors
using Dates

# 3D->2D perspective helper
function persp(x,y,z; scale=0.6, offset=(350.0,160.0))
    dx, dy = -0.25, -0.45
    sx = x + z*dx
    sy = y + z*dy
    return Point2f(offset[1] + sx*scale, offset[2] + sy*scale)
end

# transparent stroke color to use instead of `nothing`
const TRANSPARENT = RGBA(0,0,0,0)

# robust arrow drawer
function draw_3d_arrow!(ax, tail::Tuple{Float64,Float64,Float64},
                             tip::Tuple{Float64,Float64,Float64},
                             width::Float64; color = RGBA(0.95,0.78,0.20,0.95), arrowsize=18.0)
    tx, ty, tz = tail
    px, py, pz = tip

    vx, vy = px - tx, py - ty
    ppx, ppy = -vy, vx
    plen = sqrt(ppx^2 + ppy^2)
    if plen == 0.0
        ppx, ppy = 0.0, 1.0
        plen = 1.0
    end
    ux, uy = ppx / plen, ppy / plen
    ox, oy = ux * (width/2), uy * (width/2)

    pts = [
        persp(tx - ox, ty - oy, tz),
        persp(px - 0.6*ox, py - 0.6*oy, pz - 0.6*(pz - tz)),
        persp(px - ox, py - oy, pz),
        persp(px + ox, py + oy, pz),
        persp(px + 0.6*ox, py + 0.6*oy, pz - 0.6*(pz - tz)),
        persp(tx + ox, ty + oy, tz)
    ]
    # use explicit transparent stroke instead of `nothing`
    poly!(ax, pts; color = color, strokecolor = TRANSPARENT)

    ah = [
        persp(px - 0.8*ox, py - 0.8*oy, pz + 0.12),
        persp(px, py, pz + 0.35),
        persp(px + 0.8*ox, py + 0.8*oy, pz + 0.12)
    ]
    poly!(ax, ah; color = color, strokecolor = TRANSPARENT)
    return nothing
end

# Canvas
W, H = 900, 600
fig = Figure(; size=(W,H))
ax = Axis(fig[1,1])
hidexdecorations!(ax); hideydecorations!(ax)

# Example fluxes (replace with real outputs as needed)
SW_down = 341.0
SW_ref  = 101.0
SW_abs  = SW_down - SW_ref
LW_up   = 396.0
LW_down = 339.0
OLR     = 239.0
H_flux  = 17.0
LE_flux = 80.0
stroke_for_flux(f) = 1.5 + 10 * clamp(f/420, 0.0, 1.0)

# Draw top faces (atmosphere and surface)
atm_pts = [
    persp(-5.0, -3.0, 2.6),
    persp(5.0, -3.0, 2.6),
    persp(5.0, 3.0, 2.6),
    persp(-5.0, 3.0, 2.6)
]
# use explicit strokecolor (gray) for box outline
poly!(ax, atm_pts; color = RGBA(0.85,0.92,0.98,1.0), strokecolor = RGBA(0.6,0.6,0.6,1.0))

surf_pts = [
    persp(-5.0, -3.0, -1.2),
    persp(5.0, -3.0, -1.2),
    persp(5.0, 3.0, -1.2),
    persp(-5.0, 3.0, -1.2)
]
poly!(ax, surf_pts; color = RGBA(0.96,0.99,0.97,1.0), strokecolor = RGBA(0.6,0.6,0.6,1.0))

# Draw arrows (use keyword args)
draw_3d_arrow!(ax, (0.0, -12.0, 4.0), (0.0, 0.0, -1.2), stroke_for_flux(SW_down);
               color = RGBA(0.95,0.78,0.20,0.95), arrowsize = 30.0)
draw_3d_arrow!(ax, (4.0, 0.6, -0.4), (4.6, -6.0, 3.0), stroke_for_flux(SW_ref);
               color = RGBA(0.95,0.78,0.20,0.95), arrowsize = 22.0)
draw_3d_arrow!(ax, (-3.0, 0.0, -1.2), (-3.0, 0.0, 2.0), stroke_for_flux(LW_up);
               color = RGBA(0.88,0.18,0.18,0.95), arrowsize = 28.0)
draw_3d_arrow!(ax, (-1.8, 0.0, 2.0), (-1.8, 0.0, -1.2), stroke_for_flux(LW_down);
               color = RGBA(0.88,0.18,0.18,0.95), arrowsize = 28.0)
draw_3d_arrow!(ax, (-6.0, 1.2, 2.2), (-6.0, -8.0, 5.5), stroke_for_flux(OLR);
               color = RGBA(0.88,0.18,0.18,0.95), arrowsize = 24.0)
draw_3d_arrow!(ax, (5.0, -1.4, -1.2), (5.0, -3.6, 1.8), stroke_for_flux(H_flux);
               color = RGBA(0.12,0.12,0.12,0.9), arrowsize = 14.0)
draw_3d_arrow!(ax, (7.6, -1.4, -1.2), (7.6, -3.6, 1.8), stroke_for_flux(LE_flux);
               color = RGBA(0.12,0.12,0.12,0.9), arrowsize = 14.0)

# Fixed-style text calls (array positions + array texts)
#text!(ax, [Point2f(440, 36)], ["SW ↓ $(round(SW_down; digits=1)) W/m²"]; align = (:center, :top), fontsize = 14)
#text!(ax, [Point2f(540,110)], ["Reflected $(round(SW_ref; digits=1))"]; align = (:left, :center), fontsize = 12)
#text!(ax, [Point2f(200,200)], ["LW ↑ $(round(LW_up; digits=1))"]; align = (:right, :center), fontsize = 12)
#text!(ax, [Point2f(260,320)], ["LW ↓ $(round(LW_down; digits=1))"]; align = (:right, :center), fontsize = 12)
#text!(ax, [Point2f(120,50)],  ["OLR $(round(OLR; digits=1))"]; align = (:left, :center), fontsize = 12)
#text!(ax, [Point2f(700,360)], ["Sensible $(round(H_flux; digits=1))"]; align = (:left, :center), fontsize = 10)
#text!(ax, [Point2f(750,360)], ["Latent $(round(LE_flux; digits=1))"]; align = (:left, :center), fontsize = 10)

#text!(ax, [Point2f(W/2, 12)], ["Faux-3D Trenberth diagram (CairoMakie, static)"]; align = (:center, :bottom), fontsize = 14)

# Save outputs
out_png = "trenberth_faux3d_fixed_final2.png"
out_svg = "trenberth_faux3d_fixed_final2.svg"
save(out_png, fig)
save(out_svg, fig)
println("Saved: ", out_png, " (", stat(out_png).size, " bytes) and ", out_svg)

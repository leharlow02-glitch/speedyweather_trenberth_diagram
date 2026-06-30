#!/usr/bin/env julia
# trenberth_cairo_2d.jl
# Polished 2D Trenberth (CairoMakie). Terminal safe.
# Run:
# julia trenberth_cairo_2d.jl
# Produces trenberth_cairo.png and trenberth_cairo.svg

using CairoMakie
CairoMakie.activate!()

using Colors
using Dates

# Canvas
W, H = 1200, 800
fig = Figure(; size=(W,H))
ax = Axis(fig[1,1])
hidexdecorations!(ax); hideydecorations!(ax)

# Fluxes (replace with real values)
SW_down = 341.0
SW_ref  = 101.0
LW_up   = 396.0
LW_down = 339.0
OLR     = 239.0
H_flux  = 17.0
LE_flux = 80.0

# arrow width scaling
function arrow_width(f)
    return 1.5 + 12 * clamp(f/420, 0, 1)
end

# draw a nice thick arrow poly in 2D (from tail->tip)
function draw_arrow2d!(ax, tail::Tuple{Float64,Float64}, tip::Tuple{Float64,Float64}, width::Float64; color=RGBAf0(0.9,0.7,0.1,0.95))
    tx, ty = tail
    px, py = tip
    vx, vy = px - tx, py - ty
    L = hypot(vx, vy)
    if L == 0
        return
    end
    ux, uy = vx/L, vy/L
    # perpendicular
    nx, ny = -uy, ux
    ox, oy = nx*(width/2), ny*(width/2)
    # polygon body
    body = [
        Point2f(tx - ox, ty - oy),
        Point2f(px - 0.15*ox, py - 0.15*oy),  # taper
        Point2f(px - ox, py - oy),
        Point2f(px + ox, py + oy),
        Point2f(px + 0.15*ox, py + 0.15*oy),
        Point2f(tx + ox, ty + oy)
    ]
    poly!(ax, body; color = color, strokecolor = RGBA(0,0,0,0.12))
    # arrowhead triangle
    head = [
        Point2f(px - 0.6*ox, py - 0.6*oy),
        Point2f(px, py),
        Point2f(px + 0.6*ox, py + 0.6*oy)
    ]
    poly!(ax, head; color = color, strokecolor = RGBA(0,0,0,0.12))
end

# layout: surface box bottom, atmosphere box above
# coordinates in canvas pixels
surf_center = (W*0.5, H*0.18)
atm_center  = (W*0.5, H*0.40)
surf_w, surf_h = W*0.5, H*0.12
atm_w, atm_h   = W*0.6, H*0.20

# draw boxes (rounded rectangles for style)
rect!(ax, Point2f(surf_center[1]-surf_w/2, surf_center[2]-surf_h/2), surf_w, surf_h;
      color = RGBA(0.96,0.99,0.97,1.0), strokecolor=RGBA(0.4,0.4,0.4,0.9))
rect!(ax, Point2f(atm_center[1]-atm_w/2, atm_center[2]-atm_h/2), atm_w, atm_h;
      color = RGBA(0.88,0.95,0.98,1.0), strokecolor=RGBA(0.4,0.6,0.8,0.9))

# arrow positions (nice layout)
# SW down: from top center down to surface
draw_arrow2d!(ax, (W*0.5, H*0.98), (W*0.5, surf_center[2]+surf_h/2), arrow_width(SW_down); color = RGBA(0.95,0.78,0.20,0.95))
# reflected
draw_arrow2d!(ax, (W*0.6, surf_center[2]+surf_h/2), (W*0.82, H*0.92), arrow_width(SW_ref); color = RGBA(0.95,0.78,0.20,0.9))
# LW up from surface to atmosphere
draw_arrow2d!(ax, (W*0.36, surf_center[2]+surf_h/2), (W*0.36, atm_center[2]-atm_h/2), arrow_width(LW_up); color = RGBA(0.88,0.18,0.18,0.95))
# LW down from atmosphere to surface
draw_arrow2d!(ax, (W*0.46, atm_center[2]-atm_h/2), (W*0.46, surf_center[2]+surf_h/2), arrow_width(LW_down); color = RGBA(0.88,0.18,0.18,0.95))
# OLR out to space
draw_arrow2d!(ax, (W*0.22, atm_center[2]+atm_h/2), (W*0.06, H*0.98), arrow_width(OLR); color = RGBA(0.88,0.18,0.18,0.95))
# sensible / latent (smaller, to the right)
draw_arrow2d!(ax, (W*0.72, surf_center[2]+surf_h/2), (W*0.82, surf_center[2]+surf_h/2 + H*0.06), arrow_width(H_flux); color = RGBA(0.12,0.12,0.12,0.95))
draw_arrow2d!(ax, (W*0.82, surf_center[2]+surf_h/2), (W*0.92, surf_center[2]+surf_h/2 + H*0.07), arrow_width(LE_flux); color = RGBA(0.12,0.12,0.12,0.95))

# labels near arrows
label(x,y,t; fs=16) = text!(ax, [Point2f(x,y)], [t]; align = (:left,:center), fontsize=fs)
label(W*0.5, surf_center[2]+surf_h/2 + 8, "Surface"; fs=14)
label(W*0.5, atm_center[2]+atm_h/2 + 8, "Atmosphere"; fs=14)
label(W*0.5, H*0.98 - 18, "Incoming solar (S0)"; fs=14)
label(W*0.82, H*0.92 - 18, "Reflected SW"; fs=12)
label(W*0.36 - 80, (surf_center[2]+atm_center[2])/2, "LW ↑ $(round(LW_up;digits=1)) W/m²"; fs=12)
label(W*0.46 + 10, (surf_center[2]+atm_center[2])/2, "LW ↓ $(round(LW_down;digits=1)) W/m²"; fs=12)
label(W*0.06 + 10, H*0.98 - 18, "OLR $(round(OLR;digits=1))"; fs=12)
label(W*0.82 + 10, surf_center[2]+surf_h/2 + H*0.06 + 6, "Sensible $(round(H_flux;digits=1))"; fs=11)
label(W*0.92 + 10, surf_center[2]+surf_h/2 + H*0.07 + 6, "Latent $(round(LE_flux;digits=1))"; fs=11)

# Title/footer
label(W*0.5, H - 36, "Trenberth-style energy budget (static, CairoMakie)"; fs=18)

# tidy up and save
hidexdecorations!(ax); hideydecorations!(ax)
out_png = "trenberth_cairo.png"
out_svg = "trenberth_cairo.svg"
save(out_png, fig)
save(out_svg, fig)
println("Saved ", out_png, " and ", out_svg)

#!/usr/bin/env julia
# pretty_trenberth_atmos.jl
# Enhanced Trenberth-style diagram: bigger atmosphere, tropopause dashed line,
# lapse-rate guide, and a tiny sun where SW Down originates.
# Run: julia pretty_trenberth_atmos.jl

using Random, Dates, Printf

Random.seed!(1234)

# Helper to perturb base values
perturb(base; frac=0.08) = base * (1 + (rand() - 0.5) * 2 * frac)

# Base values (W/m^2)
sw_down_base = 340.0
sw_ref_base  = 100.0
lw_up_base   = 396.0
lw_down_base = 340.0
olr_base     = 239.0
h_base       = 17.0
le_base      = 80.0

# Randomized plausible numbers
sw_down = perturb(sw_down_base, frac=0.03)
sw_ref  = clamp(perturb(sw_ref_base, frac=0.12), 0.0, sw_down*0.95)
sw_abs  = sw_down - sw_ref

lw_up   = perturb(lw_up_base, frac=0.02)
lw_down = clamp(perturb(lw_down_base, frac=0.03), 0.0, lw_up)
olr     = clamp(perturb(olr_base, frac=0.08), 0.0, lw_up)
h_val   = clamp(perturb(h_base, frac=0.3), 0.0, 500.0)
le_val  = clamp(perturb(le_base, frac=0.2), 0.0, 500.0)

surface_net = (sw_abs + lw_down) - (lw_up + h_val + le_val)
atm_net     = (lw_up + sw_ref) - (olr + lw_down)

fmt(x) = @sprintf("%.1f W/m²", x)

# SVG canvas
W = 1200
H = 820

pad = 80

# Atmosphere: larger height to emphasize vertical structure
atm_x = 120
atm_y = 80
atm_w = W - 2*atm_x
atm_h = 260   # increased

# Split point (approx tropopause)
tropopause_frac = 0.55
split_y = atm_y + atm_h * tropopause_frac

# Surface box lower on canvas (unchanged-ish)
surf_x = atm_x
surf_y = atm_y + atm_h + 80
surf_w = atm_w
surf_h = 240

# Colors
sw_color = "#F2C94C"  # gold
lw_color = "#E94B3C"  # red
atm_lower = "#DDEFF7"
atm_upper = "#EAF6FF"
surf_fill = "#F2FBFF"
text_color = "#08121A"
arrow_stroke = "#333333"

# Stroke mapping
function stroke_for(val; vmin=0.0, vmax=450.0, wmin=2.0, wmax=20.0)
    t = clamp((val - vmin) / (vmax - vmin), 0.0, 1.0)
    return round(wmin + (wmax - wmin)*t, digits=2)
end

# Simple cubic bezier path helper
bezier_path(x1,y1, cx1,cy1, cx2,cy2, x2,y2) = "M $x1 $y1 C $cx1 $cy1, $cx2 $cy2, $x2 $y2"

# Start composing SVG
svg = IOBuffer()
println(svg, """<?xml version="1.0" encoding="UTF-8" standalone="no"?>""")
println(svg, """<svg xmlns="http://www.w3.org/2000/svg" width="$W" height="$H" viewBox="0 0 $W $H">""")

# defs: gradients, markers (smaller), shadow
println(svg, """
<defs>
  <linearGradient id="atmGrad" x1="0" x2="0" y1="0" y2="1">
    <stop offset="0%" stop-color="$atm_upper" stop-opacity="1"/>
    <stop offset="100%" stop-color="$atm_lower" stop-opacity="1"/>
  </linearGradient>
  <linearGradient id="surfGrad" x1="0" x2="0" y1="0" y2="1">
    <stop offset="0%" stop-color="#FFFFFF" stop-opacity="1"/>
    <stop offset="100%" stop-color="$surf_fill" stop-opacity="1"/>
  </linearGradient>

  <filter id="softShadow" x="-20%" y="-20%" width="140%" height="140%">
    <feDropShadow dx="0" dy="6" stdDeviation="8" flood-color="#000000" flood-opacity="0.10"/>
  </filter>

  <!-- smaller arrowheads for less visual dominance -->
  <marker id="arrow_gold" viewBox="0 0 10 10" refX="6" refY="5" markerWidth="5" markerHeight="5" orient="auto">
    <path d="M 0 0 L 10 5 L 0 10 z" fill="$sw_color" />
  </marker>

  <marker id="arrow_red" viewBox="0 0 10 10" refX="6" refY="5" markerWidth="5" markerHeight="5" orient="auto">
    <path d="M 0 0 L 10 5 L 0 10 z" fill="$lw_color" />
  </marker>

  <marker id="arrow_gray" viewBox="0 0 10 10" refX="6" refY="5" markerWidth="5" markerHeight="5" orient="auto">
    <path d="M 0 0 L 10 5 L 0 10 z" fill="$arrow_stroke" />
  </marker>
</defs>
""")

# background white
println(svg, """<rect width="100%" height="100%" fill="#ffffff"/>""")

# Tiny sun at top center
sun_cx = W/2
sun_cy = 32
println(svg, """<g id="sun">""")
println(svg, """  <circle cx="$sun_cx" cy="$sun_cy" r="18" fill="#FFD54A" stroke="#FFB300" stroke-width="2"/>""")
# simple rays
for i in 0:7
    ang = i * 2pi / 8
    x1 = sun_cx + 22*cos(ang)
    y1 = sun_cy + 22*sin(ang)
    x2 = sun_cx + 36*cos(ang)
    y2 = sun_cy + 36*sin(ang)
    println(svg, """  <line x1="$x1" y1="$y1" x2="$x2" y2="$y2" stroke="#FFB300" stroke-width="2" stroke-linecap="round"/>""")
end
println(svg, """</g>""")

# Atmosphere group with soft shadow
println(svg, """<g filter="url(#softShadow)">""")
println(svg, """  <rect x="$atm_x" y="$atm_y" rx="12" ry="12" width="$atm_w" height="$(atm_h)" fill="url(#atmGrad)" stroke="#9fb7cf" stroke-width="1.4"/>""")
println(svg, """</g>""")

# Tropopause dashed line (approx)
println(svg, """<line x1="$(atm_x + 8)" y1="$split_y" x2="$(atm_x + atm_w - 8)" y2="$split_y" stroke="#2f556e" stroke-width="1.2" stroke-dasharray="6,6" opacity="0.7"/>""")
println(svg, """<text x="$(atm_x + 18)" y="$(split_y - 8)" font-family="Verdana, Arial, sans-serif" font-size="12" fill="#2f556e">Tropopause </text>""")

# Lapse rate guide (diagonal dashed line on left side), ticks
lr_x = atm_x + 18
lr_top_y = atm_y + 18
lr_bottom_y = atm_y + atm_h - 18
println(svg, """<g opacity="0.9">""")
println(svg, """  <line x1="$lr_x" y1="$lr_top_y" x2="$(lr_x + 36)" y2="$lr_bottom_y" stroke="#2d4758" stroke-width="1.2" stroke-dasharray="4,6" opacity="0.9"/>""")
# ticks and small labels along diag to suggest "altitude"
nticks = 6
for i in 0:nticks
    t = i/(nticks)
    x_tick = lr_x + 36 * t
    y_tick = lr_top_y + (lr_bottom_y - lr_top_y) * t
    # small perpendicular short tick (approx)
    println(svg, """  <line x1="$x_tick" y1="$y_tick" x2="$(x_tick - 8)" y2="$(y_tick - 6)" stroke="#2d4758" stroke-width="1.0"/>""")
end
println(svg, """  <text x="$(lr_x + 6)" y="$(lr_top_y + 18)" font-family="Verdana, Arial, sans-serif" font-size="12" fill="#2d4758">Altitude ↑</text>""")
println(svg, """</g>""")

# Atmosphere label (top-left inside)
println(svg, """<text x="$(atm_x + 18)" y="$(atm_y + 30)" font-family="Verdana, Arial, sans-serif" font-size="18" fill="$text_color">Atmosphere</text>""")
println(svg, """<text x="$(atm_x + atm_w - 18)" y="$(atm_y + 30)" font-family="Verdana, Arial, sans-serif" font-size="12" fill="#2f556e" text-anchor="end">Stratosphere | Troposphere</text>""")

# Surface box
println(svg, """<g filter="url(#softShadow)">""")
println(svg, """  <rect x="$surf_x" y="$surf_y" rx="12" ry="12" width="$surf_w" height="$surf_h" fill="url(#surfGrad)" stroke="#7fb0d8" stroke-width="1.5"/>""")
println(svg, """</g>""")
println(svg, """<text x="$(surf_x + 18)" y="$(surf_y + 28)" font-family="Verdana, Arial, sans-serif" font-size="18" fill="$text_color">Surface</text>""")

# central x coords for arrows (shifted so they don't overlap weirdly)
cx = W/2

# SW Down: start from tiny sun; curved bezier to surface
sw_stroke = stroke_for(sw_down)
path_sw = bezier_path(sun_cx, sun_cy + 34, sun_cx + 10, 140, cx - 20, surf_y - 80, cx, surf_y + 12)
println(svg, """<path d="$path_sw" fill="none" stroke="$sw_color" stroke-width="$sw_stroke" stroke-linecap="round" stroke-linejoin="round" marker-end="url(#arrow_gold)"/>""")
println(svg, """<text x="$cx" y="54" font-family="Verdana, Arial, sans-serif" font-size="14" fill="$text_color" text-anchor="middle">SW Down $(fmt(sw_down))</text>""")
println(svg, """<text x="$cx" y="$(surf_y - 12)" font-family="Verdana, Arial, sans-serif" font-size="13" fill="$text_color" text-anchor="middle">SW Absorbed $(fmt(sw_abs))</text>""")

# SW Reflected (right side, upwards)
swref_stroke = stroke_for(sw_ref; vmax=240, wmin=2, wmax=12)
rx = atm_x + atm_w*0.82
path_swref = bezier_path(rx, atm_y + 34, rx+40, 10, rx+10, 5, rx+10, 20)
println(svg, """<path d="$path_swref" fill="none" stroke="$sw_color" stroke-width="$swref_stroke" stroke-linecap="round" marker-end="url(#arrow_gold)"/>""")
println(svg, """<text x="$(rx + 64)" y="44" font-family="Verdana, Arial, sans-serif" font-size="13" fill="$text_color">Reflected $(fmt(sw_ref))</text>""")

# LW Up (smaller arrowheads, stroke scaled)
lwup_stroke = stroke_for(lw_up)
lx = surf_x + surf_w*0.44
path_lwup = bezier_path(lx, surf_y + 26, lx-50, surf_y - 40, lx-30, atm_y + atm_h*0.72, lx, atm_y + atm_h - 16)
println(svg, """<path d="$path_lwup" fill="none" stroke="$lw_color" stroke-width="$lwup_stroke" stroke-linecap="round" marker-end="url(#arrow_red)"/>""")
println(svg, """<text x="$(lx - 18)" y="$((surf_y + (atm_y + atm_h))/2 - 8)" font-family="Verdana, Arial, sans-serif" font-size="13" fill="$text_color" text-anchor="end">LW Up $(fmt(lw_up))</text>""")

# LW Down
lwdn_stroke = stroke_for(lw_down)
lx2 = surf_x + surf_w*0.34
path_lwdn = bezier_path(lx2, atm_y + atm_h - 12, lx2+20, atm_y + atm_h + 30, lx2-6, surf_y - 40, lx2, surf_y + 8)
println(svg, """<path d="$path_lwdn" fill="none" stroke="$lw_color" stroke-width="$lwdn_stroke" stroke-linecap="round" marker-end="url(#arrow_red)"/>""")
println(svg, """<text x="$(lx2 - 18)" y="$((atm_y + atm_h + surf_y)/2 - 4)" font-family="Verdana, Arial, sans-serif" font-size="13" fill="$text_color" text-anchor="end">LW Down $(fmt(lw_down))</text>""")

# OLR top-left (less intrusive curvature)
olr_stroke = stroke_for(olr; wmin=2, wmax=12)
olx = atm_x + atm_w*0.12
path_olr = bezier_path(olx, atm_y + 20, olx-34, 42, olx-20, 12, olx-6, 18)
println(svg, """<path d="$path_olr" fill="none" stroke="$lw_color" stroke-width="$olr_stroke" stroke-linecap="round" marker-end="url(#arrow_red)"/>""")
println(svg, """<text x="$(olx - 14)" y="36" font-family="Verdana, Arial, sans-serif" font-size="13" fill="$text_color" text-anchor="end">OLR $(fmt(olr))</text>""")

# Sensible & Latent (dashed curved arrows)
sy_surf = surf_y + 30
sy_atm = atm_y + atm_h - 12
sx1 = surf_x + surf_w*0.68
sens_stroke = stroke_for(h_val; vmax=60)
println(svg, """<path d="$(bezier_path(sx1, sy_surf, sx1+36, sy_surf-80, sx1+36, sy_atm+80, sx1, sy_atm))" fill="none" stroke="#4a4a4a" stroke-width="$sens_stroke" stroke-dasharray="8,6" stroke-linecap="round" marker-end="url(#arrow_gray)"/>""")
println(svg, """<text x="$(sx1 + 46)" y="$((sy_surf+sy_atm)/2 - 8)" font-family="Verdana, Arial, sans-serif" font-size="13" fill="$text_color">Sensible $(fmt(h_val))</text>""")

sx2 = surf_x + surf_w*0.84
le_stroke = stroke_for(le_val; vmax=200)
println(svg, """<path d="$(bezier_path(sx2, sy_surf, sx2+36, sy_surf-80, sx2+36, sy_atm+80, sx2, sy_atm))" fill="none" stroke="#4a4a4a" stroke-width="$le_stroke" stroke-dasharray="8,6" stroke-linecap="round" marker-end="url(#arrow_gray)"/>""")
println(svg, """<text x="$(sx2 + 46)" y="$((sy_surf+sy_atm)/2 + 10)" font-family="Verdana, Arial, sans-serif" font-size="13" fill="$text_color">Latent $(fmt(le_val))</text>""")

# Net labels
println(svg, """<text x="$(W/2)" y="$(H - 52)" font-family="Verdana, Arial, sans-serif" font-size="16" fill="$text_color" text-anchor="middle">Surface net = $(fmt(surface_net))</text>""")
println(svg, """<text x="$(W/2)" y="56" font-family="Verdana, Arial, sans-serif" font-size="16" fill="$text_color" text-anchor="middle">Atmosphere net = $(fmt(atm_net))</text>""")

# Legend
leg_x = W - 280; leg_y = H - 170
println(svg, """<g>""")
println(svg, """  <rect x="$leg_x" y="$leg_y" rx="8" ry="8" width="240" height="140" fill="#ffffff" stroke="#e6eef5" />""")
println(svg, """  <text x="$(leg_x + 18)" y="$(leg_y + 28)" font-family="Verdana, Arial, sans-serif" font-size="13" fill="$text_color">Legend</text>""")
println(svg, """  <line x1="$(leg_x + 18)" y1="$(leg_y + 54)" x2="$(leg_x + 68)" y2="$(leg_y + 54)" stroke="$sw_color" stroke-width="8" stroke-linecap="round"/><text x="$(leg_x + 86)" y="$(leg_y + 58)" font-family="Verdana, Arial, sans-serif" font-size="12" fill="$text_color">Shortwave</text>""")
println(svg, """  <line x1="$(leg_x + 18)" y1="$(leg_y + 84)" x2="$(leg_x + 68)" y2="$(leg_y + 84)" stroke="$lw_color" stroke-width="8" stroke-linecap="round"/><text x="$(leg_x + 86)" y="$(leg_y + 88)" font-family="Verdana, Arial, sans-serif" font-size="12" fill="$text_color">Longwave</text>""")
println(svg, """  <line x1="$(leg_x + 18)" y1="$(leg_y + 114)" x2="$(leg_x + 68)" y2="$(leg_y + 114)" stroke="#4a4a4a" stroke-width="6" stroke-dasharray="8,6" stroke-linecap="round"/><text x="$(leg_x + 86)" y="$(leg_y + 118)" font-family="Verdana, Arial, sans-serif" font-size="12" fill="$text_color">Turbulent (Sensible/Latent)</text>""")
println(svg, """</g>""")

# Footer timestamp
nowstr = Dates.format(now(), "yyyy-mm-dd HH:MM")
println(svg, """<text x="14" y="$(H - 18)" font-family="Verdana, Arial, sans-serif" font-size="12" fill="#666666">Generated: $nowstr — pretty_trenberth_atmos (random example)</text>""")

println(svg, "</svg>")

# Write file
outname = "pretty_trenberth_atmos.svg"
open(outname, "w") do io
    write(io, String(take!(svg)))
end

println("Wrote $outname")

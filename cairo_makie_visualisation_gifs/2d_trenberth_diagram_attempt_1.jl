#!/usr/bin/env julia
# pretty_trenberth_svg.jl
# Enhanced Trenberth-style diagram as SVG (no plotting libraries required).
# Run: julia pretty_trenberth_svg.jl

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

# SVG canvas size (px)
W = 1100
H = 760

# Layout
pad = 80
atm_x, atm_y, atm_w, atm_h = 120, 120, W - 2pad, 180   # atmosphere envelope
surf_x, surf_y, surf_w, surf_h = 120, 420, W - 2pad, 200

# Colors
sw_color = "#F2C94C"  # gold
lw_color = "#E94B3C"  # red
atm_lower = "#DDEFF7"
atm_upper = "#EAF6FF"
surf_fill = "#F2FBFF"
text_color = "#08121A"
arrow_stroke = "#333333"

# Map flux magnitude to stroke width for visual weight (min,max)
function stroke_for(val; vmin=0.0, vmax=400.0, wmin=3.0, wmax=20.0)
    t = clamp((val - vmin) / (vmax - vmin), 0.0, 1.0)
    return round(wmin + (wmax - wmin)*t, digits=2)
end

# Bezier utility: simple cubic path builder (x1,y1 -> cx1,cy1 -> cx2,cy2 -> x2,y2)
bezier_path(x1,y1, cx1,cy1, cx2,cy2, x2,y2) = "M $x1 $y1 C $cx1 $cy1, $cx2 $cy2, $x2 $y2"

# Compose SVG
svg = IOBuffer()
println(svg, """<?xml version="1.0" encoding="UTF-8" standalone="no"?>""")
println(svg, """<svg xmlns="http://www.w3.org/2000/svg" width="$W" height="$H" viewBox="0 0 $W $H">""")

# defs: gradients, arrow markers, shadow, fonts
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
    <feDropShadow dx="0" dy="6" stdDeviation="8" flood-color="#000000" flood-opacity="0.12"/>
  </filter>

  <marker id="arrow_gold" viewBox="0 0 10 10" refX="7" refY="5" markerWidth="7" markerHeight="7" orient="auto">
    <path d="M 0 0 L 10 5 L 0 10 z" fill="$sw_color" />
  </marker>

  <marker id="arrow_red" viewBox="0 0 10 10" refX="7" refY="5" markerWidth="7" markerHeight="7" orient="auto">
    <path d="M 0 0 L 10 5 L 0 10 z" fill="$lw_color" />
  </marker>

  <marker id="arrow_gray" viewBox="0 0 10 10" refX="7" refY="5" markerWidth="7" markerHeight="7" orient="auto">
    <path d="M 0 0 L 10 5 L 0 10 z" fill="$arrow_stroke" />
  </marker>
</defs>
""")

# background
println(svg, """<rect width="100%" height="100%" fill="#ffffff"/>""")

# Atmosphere with two layers (lower troposphere, upper stratosphere-ish)
split_y = atm_y + atm_h*0.55
println(svg, """<g filter="url(#softShadow)">""")
println(svg, """  <rect x="$atm_x" y="$atm_y" rx="14" ry="14" width="$atm_w" height="$(atm_h*0.55)" fill="url(#atmGrad)" stroke="#9fb7cf" stroke-width="1.5"/>""")
println(svg, """  <rect x="$atm_x" y="$split_y" rx="12" ry="12" width="$atm_w" height="$(atm_h*0.45)" fill="$atm_upper" stroke="#9fb7cf" stroke-width="1.0"/>""")
println(svg, """</g>""")
println(svg, """<text x="$(atm_x + 18)" y="$(atm_y + 32)" font-family="Verdana, Arial, sans-serif" font-size="18" fill="$text_color">Atmosphere</text>""")
println(svg, """<text x="$(atm_x + atm_w - 18)" y="$(atm_y + 32)" font-family="Verdana, Arial, sans-serif" font-size="12" fill="#2f556e" text-anchor="end">Upper | Lower</text>""")

# Surface box
println(svg, """<g filter="url(#softShadow)">""")
println(svg, """  <rect x="$surf_x" y="$surf_y" rx="14" ry="14" width="$surf_w" height="$surf_h" fill="url(#surfGrad)" stroke="#7fb0d8" stroke-width="1.5"/>""")
println(svg, """</g>""")
println(svg, """<text x="$(surf_x + 18)" y="$(surf_y + 32)" font-family="Verdana, Arial, sans-serif" font-size="18" fill="$text_color">Surface</text>""")

# central x coords for arrows
cx = W/2

# SW Down (curved, from top to surface) - long, thin -> stroke scaled
sw_stroke = stroke_for(sw_down; vmin=0, vmax=400)
path_sw = bezier_path(cx, 40, cx+40, 140, cx-40, surf_y-40, cx, surf_y+10)
println(svg, """<path d="$path_sw" fill="none" stroke="$sw_color" stroke-width="$sw_stroke" stroke-linecap="round" stroke-linejoin="round" marker-end="url(#arrow_gold)"/>""")
println(svg, """<text x="$cx" y="32" font-family="Verdana, Arial, sans-serif" font-size="14" fill="$text_color" text-anchor="middle">SW Down $(fmt(sw_down))</text>""")
println(svg, """<text x="$cx" y="$(surf_y - 12)" font-family="Verdana, Arial, sans-serif" font-size="13" fill="$text_color" text-anchor="middle">SW Absorbed $(fmt(sw_abs))</text>""")

# SW Reflected (upwards on right) - slightly curved
swref_stroke = stroke_for(sw_ref; vmin=0, vmax=200, wmin=2, wmax=12)
rx = atm_x + atm_w*0.82
path_swref = bezier_path(rx, atm_y + 28, rx+40, 10, rx+10, 5, rx+10, 20)
println(svg, """<path d="$path_swref" fill="none" stroke="$sw_color" stroke-width="$swref_stroke" stroke-linecap="round" marker-end="url(#arrow_gold)"/>""")
println(svg, """<text x="$(rx + 60)" y="36" font-family="Verdana, Arial, sans-serif" font-size="13" fill="$text_color">Reflected $(fmt(sw_ref))</text>""")

# LW Up (from surface up into lower atm)
lwup_stroke = stroke_for(lw_up; vmin=0, vmax=450)
lx = surf_x + surf_w*0.42
path_lwup = bezier_path(lx, surf_y + 24, lx-60, surf_y - 20, lx-60, atm_y + atm_h*0.7, lx, atm_y + atm_h - 12)
println(svg, """<path d="$path_lwup" fill="none" stroke="$lw_color" stroke-width="$lwup_stroke" stroke-linecap="round" marker-end="url(#arrow_red)"/>""")
println(svg, """<text x="$(lx - 14)" y="$((surf_y + (atm_y + atm_h))/2 - 10)" font-family="Verdana, Arial, sans-serif" font-size="13" fill="$text_color" text-anchor="end">LW Up $(fmt(lw_up))</text>""")

# LW Down (from atmosphere to surface)
lwdn_stroke = stroke_for(lw_down; vmin=0, vmax=450)
lx2 = surf_x + surf_w*0.34
path_lwdn = bezier_path(lx2, atm_y + atm_h - 8, lx2+20, atm_y + atm_h + 40, lx2-10, surf_y - 30, lx2, surf_y + 10)
println(svg, """<path d="$path_lwdn" fill="none" stroke="$lw_color" stroke-width="$lwdn_stroke" stroke-linecap="round" marker-end="url(#arrow_red)"/>""")
println(svg, """<text x="$(lx2 - 14)" y="$((atm_y + atm_h + surf_y)/2 - 6)" font-family="Verdana, Arial, sans-serif" font-size="13" fill="$text_color" text-anchor="end">LW Down $(fmt(lw_down))</text>""")

# OLR (top-left)
olr_stroke = stroke_for(olr; vmin=0, vmax=400, wmin=2, wmax=12)
olx = atm_x + atm_w*0.14
path_olr = bezier_path(olx, atm_y + 18, olx-40, 40, olx-24, 12, olx-6, 18)
println(svg, """<path d="$path_olr" fill="none" stroke="$lw_color" stroke-width="$olr_stroke" stroke-linecap="round" marker-end="url(#arrow_red)"/>""")
println(svg, """<text x="$(olx - 12)" y="32" font-family="Verdana, Arial, sans-serif" font-size="13" fill="$text_color" text-anchor="end">OLR $(fmt(olr))</text>""")

# Sensible & Latent (dashed, with arrow heads)
sy_surf = surf_y + 28; sy_atm = atm_y + atm_h - 8
sx1 = surf_x + surf_w*0.68
sens_stroke = stroke_for(h_val; vmin=0, vmax=100, wmin=2, wmax=12)
println(svg, """<path d="$(bezier_path(sx1, sy_surf, sx1+30, sy_surf-60, sx1+30, sy_atm+60, sx1, sy_atm))" fill="none" stroke="#4a4a4a" stroke-width="$sens_stroke" stroke-dasharray="8,6" stroke-linecap="round" marker-end="url(#arrow_gray)"/>""")
println(svg, """<text x="$(sx1 + 36)" y="$((sy_surf+sy_atm)/2 - 6)" font-family="Verdana, Arial, sans-serif" font-size="13" fill="$text_color">Sensible $(fmt(h_val))</text>""")

sx2 = surf_x + surf_w*0.84
le_stroke = stroke_for(le_val; vmin=0, vmax=200, wmin=2, wmax=14)
println(svg, """<path d="$(bezier_path(sx2, sy_surf, sx2+30, sy_surf-60, sx2+20, sy_atm+40, sx2, sy_atm))" fill="none" stroke="#4a4a4a" stroke-width="$le_stroke" stroke-dasharray="8,6" stroke-linecap="round" marker-end="url(#arrow_gray)"/>""")
println(svg, """<text x="$(sx2 + 36)" y="$((sy_surf+sy_atm)/2 + 12)" font-family="Verdana, Arial, sans-serif" font-size="13" fill="$text_color">Latent $(fmt(le_val))</text>""")

# Net labels at bottom / top
println(svg, """<text x="$(W/2)" y="$(H - 40)" font-family="Verdana, Arial, sans-serif" font-size="16" fill="$text_color" text-anchor="middle">Surface net = $(fmt(surface_net))</text>""")
println(svg, """<text x="$(W/2)" y="38" font-family="Verdana, Arial, sans-serif" font-size="16" fill="$text_color" text-anchor="middle">Atmosphere net = $(fmt(atm_net))</text>""")

# legend (mini)
leg_x = W - 250; leg_y = H - 150
println(svg, """<g>""")
println(svg, """  <rect x="$leg_x" y="$leg_y" rx="8" ry="8" width="220" height="120" fill="#ffffff" stroke="#e6eef5" />""")
println(svg, """  <text x="$(leg_x + 14)" y="$(leg_y + 22)" font-family="Verdana, Arial, sans-serif" font-size="13" fill="$text_color">Legend</text>""")
println(svg, """  <line x1="$(leg_x + 18)" y1="$(leg_y + 44)" x2="$(leg_x + 68)" y2="$(leg_y + 44)" stroke="$sw_color" stroke-width="8" stroke-linecap="round"/><text x="$(leg_x + 82)" y="$(leg_y + 48)" font-family="Verdana, Arial, sans-serif" font-size="12" fill="$text_color">Shortwave</text>""")
println(svg, """  <line x1="$(leg_x + 18)" y1="$(leg_y + 70)" x2="$(leg_x + 68)" y2="$(leg_y + 70)" stroke="$lw_color" stroke-width="8" stroke-linecap="round"/><text x="$(leg_x + 82)" y="$(leg_y + 74)" font-family="Verdana, Arial, sans-serif" font-size="12" fill="$text_color">Longwave</text>""")
println(svg, """  <line x1="$(leg_x + 18)" y1="$(leg_y + 96)" x2="$(leg_x + 68)" y2="$(leg_y + 96)" stroke="#4a4a4a" stroke-width="6" stroke-dasharray="8,6" stroke-linecap="round"/><text x="$(leg_x + 82)" y="$(leg_y + 100)" font-family="Verdana, Arial, sans-serif" font-size="12" fill="$text_color">Turbulent (Sensible/Latent)</text>""")
println(svg, """</g>""")

# Footer timestamp
nowstr = Dates.format(now(), "yyyy-mm-dd HH:MM")
println(svg, """<text x="14" y="$(H - 18)" font-family="Verdana, Arial, sans-serif" font-size="12" fill="#666666">Generated: $nowstr — pretty_trenberth (random example)</text>""")

println(svg, "</svg>")

# Write file
outname = "pretty_trenberth.svg"
open(outname, "w") do io
    write(io, String(take!(svg)))
end

println("Wrote $outname")

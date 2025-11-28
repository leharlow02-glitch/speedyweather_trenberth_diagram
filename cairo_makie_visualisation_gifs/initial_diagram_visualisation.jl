#!/usr/bin/env julia
# random_trenberth_svg.jl
# Produce a simple Trenberth-style diagram as an SVG (no plotting libraries required).
# Run: julia random_trenberth_svg.jl

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
W = 1000
H = 700

# Coordinates helper: simple coordinate system where x,y in px
# We'll place Atmosphere box near top, Surface box near bottom.
atm_x, atm_y, atm_w, atm_h = 100, 110, 800, 160   # rectangle for atmosphere
surf_x, surf_y, surf_w, surf_h = 100, 420, 800, 160

# Colors (simple hex)
sw_color = "#F2C94C"  # gold
lw_color = "#E94B3C"  # red
atm_fill = "#DDEFF7"
surf_fill = "#D6EEF9"
text_color = "#08121A"
arrow_stroke = "#333333"

# Small helper to make arrow marker for SVG
arrow_marker = """
<defs>
  <marker id="arrow" viewBox="0 0 10 10" refX="6" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
    <path d="M 0 0 L 10 5 L 0 10 z" fill="$arrow_stroke" />
  </marker>
  <marker id="arrow_gold" viewBox="0 0 10 10" refX="6" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
    <path d="M 0 0 L 10 5 L 0 10 z" fill="$sw_color" />
  </marker>
  <marker id="arrow_red" viewBox="0 0 10 10" refX="6" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
    <path d="M 0 0 L 10 5 L 0 10 z" fill="$lw_color" />
  </marker>
</defs>
"""

# Compose SVG content
svg = IOBuffer()
println(svg, """<?xml version="1.0" encoding="UTF-8" standalone="no"?>""")
println(svg, """<svg xmlns="http://www.w3.org/2000/svg" width="$W" height="$H" viewBox="0 0 $W $H">""")
println(svg, arrow_marker)

# background
println(svg, """<rect width="100%" height="100%" fill="white"/>""")

# Atmosphere box
println(svg,
    """<rect x="$atm_x" y="$atm_y" width="$atm_w" height="$atm_h" fill="$atm_fill" stroke="#9fb7cf" stroke-width="2"/>""")
# Atmosphere label
println(svg, """<text x="$(atm_x + atm_w/2)" y="$(atm_y + atm_h/2)" font-family="Arial" font-size="28" fill="$text_color" text-anchor="middle" alignment-baseline="middle">Atmosphere</text>""")

# Surface box
println(svg,
    """<rect x="$surf_x" y="$surf_y" width="$surf_w" height="$surf_h" fill="$surf_fill" stroke="#7fb0d8" stroke-width="2"/>""")
println(svg, """<text x="$(surf_x + surf_w/2)" y="$(surf_y + surf_h/2)" font-family="Arial" font-size="28" fill="$text_color" text-anchor="middle" alignment-baseline="middle">Surface</text>""")

# SW Down (gold) - top to surface
sx = W/2; sy1 = 40; sy2 = atm_y + 10
println(svg,
    """<line x1="$sx" y1="$sy1" x2="$sx" y2="$sy2" stroke="$sw_color" stroke-width="10" marker-end="url(#arrow_gold)"/>""")
println(svg,
    """<text x="$sx" y="$sy1" font-family="Arial" font-size="16" fill="$text_color" text-anchor="middle" dominant-baseline="central">SW Down\n$(fmt(sw_down))</text>""")

# SW Reflected (upwards) near right
rx = atm_x + atm_w*0.8; ry1 = atm_y + 30; ry2 = 20
println(svg,
    """<line x1="$rx" y1="$ry1" x2="$rx" y2="$ry2" stroke="$sw_color" stroke-width="8" marker-end="url(#arrow_gold)"/>""")
println(svg,
    """<text x="$(rx + 10)" y="$(ry2 + 10)" font-family="Arial" font-size="14" fill="$text_color" >SW Reflected $(fmt(sw_ref))</text>""")

# SW absorbed label near surface center
println(svg, """<text x="$(sx)" y="$(surf_y - 10)" font-family="Arial" font-size="14" fill="$text_color" text-anchor="middle">SW Absorbed $(fmt(sw_abs))</text>""")

# LW Up from surface into atmosphere
lx = surf_x + surf_w*0.4; ly1 = surf_y + 30; ly2 = atm_y + atm_h - 10
println(svg,
    """<line x1="$lx" y1="$ly1" x2="$lx" y2="$ly2" stroke="$lw_color" stroke-width="10" marker-end="url(#arrow_red)"/>""")
println(svg, """<text x="$(lx - 10)" y="$((ly1+ly2)/2)" font-family="Arial" font-size="14" fill="$text_color" text-anchor="end">LW Up $(fmt(lw_up))</text>""")

# LW Down from atmosphere to surface
lx2 = surf_x + surf_w*0.3; ly3 = atm_y + atm_h - 5; ly4 = surf_y + 30
println(svg,
    """<line x1="$lx2" y1="$ly3" x2="$lx2" y2="$ly4" stroke="$lw_color" stroke-width="10" marker-end="url(#arrow_red)"/>""")
println(svg, """<text x="$(lx2 - 10)" y="$((ly3+ly4)/2)" font-family="Arial" font-size="14" fill="$text_color" text-anchor="end">LW Down $(fmt(lw_down))</text>""")

# OLR arrow top-left
olx = atm_x + atm_w*0.12; oly1 = atm_y + 20; oly2 = 18
println(svg,
    """<line x1="$olx" y1="$oly1" x2="$olx" y2="$oly2" stroke="$lw_color" stroke-width="8" marker-end="url(#arrow_red)"/>""")
println(svg, """<text x="$(olx - 6)" y="$(oly2 + 12)" font-family="Arial" font-size="14" fill="$text_color" text-anchor="end">OLR $(fmt(olr))</text>""")

# Sensible and latent fluxes (dashed arrows)
sx1 = surf_x + surf_w*0.65; sy_surf = surf_y + 30; sy_atm = atm_y + atm_h - 10
println(svg, """<line x1="$sx1" y1="$sy_surf" x2="$sx1" y2="$sy_atm" stroke="#333333" stroke-width="6" stroke-dasharray="6,5" marker-end="url(#arrow)"/>""")
println(svg, """<text x="$(sx1 + 12)" y="$((sy_surf+sy_atm)/2)" font-family="Arial" font-size="14" fill="$text_color">Sensible $(fmt(h_val))</text>""")
sx2 = surf_x + surf_w*0.83
println(svg, """<line x1="$sx2" y1="$sy_surf" x2="$sx2" y2="$sy_atm" stroke="#333333" stroke-width="6" stroke-dasharray="6,5" marker-end="url(#arrow)"/>""")
println(svg, """<text x="$(sx2 + 12)" y="$((sy_surf+sy_atm)/2)" font-family="Arial" font-size="14" fill="$text_color">Latent $(fmt(le_val))</text>""")

# Net labels
println(svg, """<text x="$(W/2)" y="$(H - 20)" font-family="Arial" font-size="16" fill="$text_color" text-anchor="middle">Surface net = $(fmt(surface_net))</text>""")
println(svg, """<text x="$(W/2)" y="30" font-family="Arial" font-size="16" fill="$text_color" text-anchor="middle">Atmosphere net = $(fmt(atm_net))</text>""")

# Footer note
nowstr = Dates.format(now(), "yyyy-mm-dd HH:MM")
println(svg, """<text x="12" y="$(H - 10)" font-family="Arial" font-size="12" fill="#666666">Generated: $nowstr — random example</text>""")

println(svg, "</svg>")

# Write file
outname = "test_trenberth.svg"
open(outname, "w") do io
    write(io, String(take!(svg)))
end

println("Wrote $outname")

# Optional: try to convert to PNG if rsvg-convert is available (common on Linux)
pngname = "random_trenberth.png"
try
    run(`rsvg-convert -o $pngname $outname`)
    println("Also wrote $pngname (via rsvg-convert)")
catch e
    println("rsvg-convert not available or failed — SVG is produced; open the SVG in a browser.")
end

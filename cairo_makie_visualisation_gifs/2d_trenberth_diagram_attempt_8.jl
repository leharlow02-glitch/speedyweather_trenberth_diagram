#!/usr/bin/env julia
# trenberth_columns_v3.jl
# Trenberth with angled columns, convex-up surface, straight arrows aligned to column centers,
# corrected directions for sensible/latent & LW, and label nudging.
# Run: julia trenberth_columns_v3.jl

using Random, Dates, Printf

Random.seed!(1234)

# -----------------------
# Randomized plausible fluxes
# -----------------------
perturb(base; frac=0.08) = base * (1 + (rand() - 0.5) * 2 * frac)

sw_down_base = 340.0; sw_ref_base = 100.0
lw_up_base = 396.0; lw_down_base = 340.0; olr_base = 239.0
h_base = 17.0; le_base = 80.0

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

# -----------------------
# Canvas & layout
# -----------------------
W = 1280
H = 920
pad = 56

# Atmosphere box
atm_x = pad
atm_y = 40
atm_w = W - 2*pad
atm_h = 520

# Surface (touching atmosphere) - convex-up top (bulging into atmosphere)
surf_x = atm_x
surf_y = atm_y + atm_h
surf_w = atm_w
surf_h = 120

# Columns - we'll make four angled columns (trapezoids) by specifying top & bottom x offsets
col_w = atm_w * 0.18
gap = (atm_w - 4*col_w) / 5.0

# bottom x positions (where they meet surface)
col_bottom_x = [
    atm_x + gap,                           # Longwave column (LW up/down)
    atm_x + gap*2 + col_w,                 # Shortwave down
    atm_x + gap*3 + col_w*2,               # Turbulent
    atm_x + gap*4 + col_w*3                # Reflected shortwave up
]

# top x offsets (slant towards center slightly)
slant = 28   # how much top is offset towards center (positive moves right)
col_top_x = [
    col_bottom_x[1] + slant, 
    col_bottom_x[2] - slant,
    col_bottom_x[3] - slant,
    col_bottom_x[4] + slant
]

# compute column polygons (top-left/top-right/bottom-right/bottom-left)
function col_polygon_coords(i)
    bx = col_bottom_x[i]
    tx = col_top_x[i]
    x1 = tx
    x2 = tx + col_w
    x3 = bx + col_w
    x4 = bx
    y_top = atm_y + 12
    y_bottom = atm_y + atm_h - 12
    return (x1,y_top,x2,y_top,x3,y_bottom,x4,y_bottom)
end

# centreline x for each column (for placing arrows)
col_center_x = [(col_top_x[i] + col_bottom_x[i] + col_w)/2 for i in 1:4]

# Colours & fonts
sw_color = "#F2C94C"
lw_color = "#E94B3C"
sens_color = "#0F6B6B"
lat_color  = "#1F4FA3"
atm_grad_top = "#EAF6FF"
atm_grad_bot = "#DDEFF7"
surf_fill = "#E8F6EA"
surf_stroke = "#58A05A"
text_color = "#08121A"

title_fs = 22
flux_fs  = 15
legend_fs = 13
small_fs = 10

# stroke mapping for visual thickness
function stroke_for(val; vmin=0.0, vmax=450.0, wmin=3.0, wmax=22.0)
    t = clamp((val - vmin) / (vmax - vmin), 0.0, 1.0)
    return round(wmin + (wmax - wmin)*t, digits=2)
end

# arrow vertical endpoints (fractions)
y_top = atm_y + 18
y_surface_pen = surf_y + 12

# set arrow heights (corrected):
# - SW Down: top -> surface (down)
# - SW Reflected: surface -> top (up)
# - LW Up: surface -> ~60% (up)
# - LW Down: ~92% -> surface (down)
# - Sensible: surface -> ~30% (up) (short)
# - Latent: surface -> ~45% (up) (shorter than before)
y_sw_top = y_top
y_sw_end = y_surface_pen

y_lw_up_start = y_surface_pen
y_lw_up_end   = atm_y + atm_h * 0.60

y_lw_down_start = atm_y + atm_h * 0.92
y_lw_down_end   = y_surface_pen

y_sens_start = y_surface_pen
y_sens_end   = atm_y + atm_h * 0.30

y_lat_start  = y_surface_pen
y_lat_end    = atm_y + atm_h * 0.45

y_ref_start = y_surface_pen
y_ref_end   = y_top

# OLR: short upward diagonal at top-left
olr_x = atm_x + 18
olr_y_start = atm_y + atm_h * 0.14
olr_y_end = atm_y - 12

# -----------------------
# Compose SVG
# -----------------------
svg = IOBuffer()
println(svg, "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>")
println(svg, "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"$W\" height=\"$H\" viewBox=\"0 0 $W $H\">")

# defs (markers / gradients)
println(svg, """
<defs>
  <linearGradient id="atmGrad" x1="0" x2="0" y1="0" y2="1">
    <stop offset="0%" stop-color="$atm_grad_top" stop-opacity="1"/>
    <stop offset="100%" stop-color="$atm_grad_bot" stop-opacity="1"/>
  </linearGradient>
  <linearGradient id="surfGrad" x1="0" x2="0" y1="0" y2="1">
    <stop offset="0%" stop-color="#FFFFFF" stop-opacity="1"/>
    <stop offset="100%" stop-color="$surf_fill" stop-opacity="1"/>
  </linearGradient>
  <filter id="softShadow" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="8" stdDeviation="10" flood-color=\"#000\" flood-opacity=\"0.10\"/></filter>

  <marker id="m_sw" viewBox="0 0 10 10" refX="5" refY="5" markerWidth="6" markerHeight="6" orient="auto">
    <path d="M 0 0 L 10 5 L 0 10 z" fill="$sw_color" />
  </marker>
  <marker id="m_lw" viewBox="0 0 10 10" refX="5" refY="5" markerWidth="6" markerHeight="6" orient="auto">
    <path d="M 0 0 L 10 5 L 0 10 z" fill="$lw_color" />
  </marker>
  <marker id="m_sens" viewBox="0 0 10 10" refX="5" refY="5" markerWidth="6" markerHeight="6" orient="auto">
    <path d="M 0 0 L 10 5 L 0 10 z" fill="$sens_color" />
  </marker>
  <marker id="m_lat" viewBox="0 0 10 10" refX="5" refY="5" markerWidth="6" markerHeight="6" orient="auto">
    <path d="M 0 0 L 10 5 L 0 10 z" fill="$lat_color" />
  </marker>
  <marker id="m_olr" viewBox="0 0 10 10" refX="5" refY="5" markerWidth="6" markerHeight="6" orient="auto">
    <path d="M 0 0 L 10 5 L 0 10 z" fill="$lw_color" />
  </marker>
</defs>
""")

# background
println(svg, "<rect width='100%' height='100%' fill='#ffffff'/>")

# atmosphere rectangle (base)
println(svg, "<g filter='url(#softShadow)'>")
println(svg, "  <rect x=\"$atm_x\" y=\"$atm_y\" rx=\"12\" ry=\"12\" width=\"$atm_w\" height=\"$atm_h\" fill='url(#atmGrad)' stroke='#9fb7cf' stroke-width='1.4' />")
println(svg, "</g>")

# draw angled column polygons (subtle translucent fill)
for i in 1:4
    coords = col_polygon_coords(i)
    println(svg, "<polygon points=\"$(coords[1]) $(coords[2]), $(coords[3]) $(coords[4]), $(coords[5]) $(coords[6]), $(coords[7]) $(coords[8])\" fill=\"#123456\" fill-opacity=\"0.06\" stroke=\"none\"/>")
end

# surface convex-up top (bulge into atmosphere)
top_arc_depth = 44   # how far the surface bulges upward
left_top_x = surf_x
left_top_y = surf_y
right_top_x = surf_x + surf_w
right_top_y = surf_y
# control points above the top (so convex up)
cx1 = surf_x + surf_w*0.25
cy1 = surf_y - top_arc_depth
cx2 = surf_x + surf_w*0.75
cy2 = surf_y - top_arc_depth
bottom_y = surf_y + surf_h
path_surface = "M $left_top_x $left_top_y C $cx1 $cy1, $cx2 $cy2, $right_top_x $right_top_y L $right_top_x $bottom_y L $left_top_x $bottom_y Z"
println(svg, "<g filter='url(#softShadow)'>")
println(svg, "  <path d=\"$path_surface\" fill='url(#surfGrad)' stroke='$surf_stroke' stroke-width='1.4'/>")
println(svg, "</g>")
println(svg, "<text x='$(surf_x + 16)' y='$(surf_y + 36)' font-family='Verdana, Arial, sans-serif' font-size='$title_fs' fill='$text_color'>Surface</text>")
println(svg, "<text x='$(atm_x + 16)' y='$(atm_y + 34)' font-family='Verdana, Arial, sans-serif' font-size='$title_fs' fill='$text_color'>Atmosphere</text>")

# helper to draw a straight arrow along a column centerline (vertical)
function col_arrow(buf, cx, y1, y2, color, strokew, marker_id, label; label_dx=14, anchor="start", label_dy=-4)
    # draw from y1 -> y2 direction; if y2 < y1 it's upward (marker-end)
    if y2 < y1
        # bottom -> top: draw from y1 to y2 and use marker-end
        println(buf, "<line x1=\"$cx\" y1=\"$y1\" x2=\"$cx\" y2=\"$y2\" stroke=\"$color\" stroke-width=\"$strokew\" stroke-linecap='round' marker-end='url(#$marker_id)'/>")
    else
        println(buf, "<line x1=\"$cx\" y1=\"$y1\" x2=\"$cx\" y2=\"$y2\" stroke=\"$color\" stroke-width=\"$strokew\" stroke-linecap='round' marker-end='url(#$marker_id)'/>")
    end
    ym = (y1 + y2)/2
    println(buf, "<text x=\"$(cx + label_dx)\" y=\"$(ym + label_dy)\" font-family='Verdana, Arial, sans-serif' font-size='$flux_fs' fill='$text_color' text-anchor='$anchor'>$label</text>")
end

# ---- Longwave column (col 1 center)
lx = col_center_x[1]
# LW Up: from surface up
col_arrow(svg, lx, y_lw_up_start, y_lw_up_end, lw_color, stroke_for(lw_up), "m_lw", "LW Up $(fmt(lw_up))"; label_dx=-18, anchor="end")
# LW Down: from high atm down to surface (draw as downward: start y smaller -> end y larger)
col_arrow(svg, lx + 18, y_lw_down_start, y_lw_down_end, lw_color, stroke_for(lw_down), "m_lw", "LW Down $(fmt(lw_down))"; label_dx=-18, anchor="end", label_dy=10)

# ---- Shortwave column (col 2 center): SW Down
sx = col_center_x[2]
col_arrow(svg, sx, y_sw_top, y_sw_end, sw_color, stroke_for(sw_down), "m_sw", "SW Down $(fmt(sw_down))"; label_dx=12, anchor="start")
# SW Absorbed label left so it doesn't collide with LW Down
println(svg, "<text x='$(sx - 46)' y='$(y_sw_end + 12)' font-family='Verdana, Arial, sans-serif' font-size='$flux_fs' fill='$text_color' text-anchor='end'>SW Absorbed $(fmt(sw_abs))</text>")

# ---- Turbulent column (col 3 center): Sensible & Latent (short)
tx = col_center_x[3]
col_arrow(svg, tx, y_sens_start, y_sens_end, sens_color, stroke_for(h_val; vmax=60), "m_sens", "Sensible $(fmt(h_val))"; label_dx=12, anchor="start")
col_arrow(svg, tx + 14, y_lat_start, y_lat_end, lat_color, stroke_for(le_val; vmax=240), "m_lat", "Latent $(fmt(le_val))"; label_dx=12, anchor="start", label_dy=10)

# ---- Reflected SW column (col 4 center)
rx = col_center_x[4]
col_arrow(svg, rx, y_ref_start, y_ref_end, sw_color, stroke_for(sw_ref; vmax=280), "m_sw", "Reflected $(fmt(sw_ref))"; label_dx=12, anchor="start")

# ---- OLR (top-left diagonal)
println(svg, "<line x1='$(atm_x + 10)' y1='$(olr_y_start)' x2='$(atm_x - 18)' y2='$(olr_y_end)' stroke='$lw_color' stroke-width='$(stroke_for(olr))' stroke-linecap='round' marker-end='url(#m_olr)'/>")
println(svg, "<text x='$(atm_x - 22)' y='$(olr_y_end - 4)' font-family='Verdana, Arial, sans-serif' font-size='$flux_fs' fill='$text_color' text-anchor='end'>OLR $(fmt(olr))</text>")

# Atmosphere & surface net labels (tightened spacing)
println(svg, "<text x='$(W/2)' y='$(atm_y + 52)' font-family='Verdana, Arial, sans-serif' font-size='$title_fs' fill='$text_color' text-anchor='middle'>Atmosphere net = $(fmt(atm_net))</text>")
println(svg, "<text x='$(W/2)' y='$(H - 44)' font-family='Verdana, Arial, sans-serif' font-size='$title_fs' fill='$text_color' text-anchor='middle'>Surface net = $(fmt(surface_net))</text>")

# legend bottom-right compact
leg_x = W - 300; leg_y = H - 200
println(svg, "<g>")
println(svg, "  <rect x=\"$leg_x\" y=\"$leg_y\" rx='8' ry='8' width='260' height='160' fill='#ffffff' stroke='#e6eef5' />")
println(svg, "  <text x='$(leg_x + 18)' y='$(leg_y + 34)' font-family='Verdana, Arial, sans-serif' font-size='$legend_fs' fill='$text_color'>Legend</text>")
println(svg, "  <line x1='$(leg_x + 18)' y1='$(leg_y + 66)' x2='$(leg_x + 88)' y2='$(leg_y + 66)' stroke='$sw_color' stroke-width='10' stroke-linecap='round'/>")
println(svg, "  <text x='$(leg_x + 104)' y='$(leg_y + 70)' font-family='Verdana, Arial, sans-serif' font-size='$legend_fs' fill='$text_color'>Shortwave</text>")
println(svg, "  <line x1='$(leg_x + 18)' y1='$(leg_y + 98)' x2='$(leg_x + 88)' y2='$(leg_y + 98)' stroke='$lw_color' stroke-width='10' stroke-linecap='round'/>")
println(svg, "  <text x='$(leg_x + 104)' y='$(leg_y + 102)' font-family='Verdana, Arial, sans-serif' font-size='$legend_fs' fill='$text_color'>Longwave</text>")
println(svg, "  <line x1='$(leg_x + 18)' y1='$(leg_y + 130)' x2='$(leg_x + 88)' y2='$(leg_y + 130)' stroke='$sens_color' stroke-width='8' stroke-dasharray='8,6' stroke-linecap='round'/>")
println(svg, "  <text x='$(leg_x + 104)' y='$(leg_y + 134)' font-family='Verdana, Arial, sans-serif' font-size='$legend_fs' fill='$text_color'>Sensible (teal)</text>")
println(svg, "  <line x1='$(leg_x + 18)' y1='$(leg_y + 158)' x2='$(leg_x + 88)' y2='$(leg_y + 158)' stroke='$lat_color' stroke-width='8' stroke-dasharray='8,6' stroke-linecap='round'/>")
println(svg, "  <text x='$(leg_x + 104)' y='$(leg_y + 162)' font-family='Verdana, Arial, sans-serif' font-size='$legend_fs' fill='$text_color'>Latent (blue)</text>")
println(svg, "</g>")

# timestamp small
nowstr = Dates.format(now(), "yyyy-mm-dd HH:MM")
println(svg, "<text x='12' y='$(H - 12)' font-family='Verdana, Arial, sans-serif' font-size='$small_fs' fill='#666666'>Generated: $nowstr — trenberth_columns_v3 (random example)</text>")

println(svg, "</svg>")

# write files
outname = "trenberth_columns_v3.svg"
open(outname, "w") do io
    write(io, String(take!(svg)))
end
println("Wrote $outname")

pngname = "trenberth_columns_v3.png"
try
    run(`rsvg-convert -o $pngname $outname`)
    println("Also wrote $pngname (via rsvg-convert)")
catch e
    println("rsvg-convert not available or failed — SVG is produced; open the SVG in a browser.")
end

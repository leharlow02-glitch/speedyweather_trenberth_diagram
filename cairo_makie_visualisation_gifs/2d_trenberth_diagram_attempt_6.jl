#!/usr/bin/env julia
# trenberth_tidy2.jl
# Trenberth-style: minimized whitespace, gentler OLR, lapse-rate ticks,
# separate sensible/latent colours, concave surface top, improved labels.
# Run: julia trenberth_tidy2.jl

using Random, Dates, Printf

Random.seed!(1234)

# -----------------------
# Numeric fluxes (plausible randomized)
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
# Canvas and layout: compact vertical packing
# -----------------------
W = 1280
H = 980                  # reduced white-space but tall enough
pad_h = 48               # small horizontal pad
pad_v = 36

# Atmosphere (tall, plenty of room)
atm_x = 72
atm_y = 60
atm_w = W - 2*atm_x
atm_h = 480

# Surface touches atmosphere (concave top)
surf_x = atm_x
surf_y = atm_y + atm_h    # top of surface = bottom of atmosphere
surf_w = atm_w
surf_h = 140               # relatively thin but visible

# lanes (fixed x positions)
lanes = Dict(
    :olr      => atm_x + atm_w*0.10,
    :lw_up    => atm_x + atm_w*0.26,
    :lw_down  => atm_x + atm_w*0.36,
    :sw_down  => W/2,
    :sens     => atm_x + atm_w*0.68,
    :latent   => atm_x + atm_w*0.82,
    :sw_ref   => atm_x + atm_w*0.94
)

# Colors & fonts
sw_color = "#F2C94C"
lw_color = "#E94B3C"
sens_color = "#0F6B6B"      # distinct teal
lat_color  = "#1F4FA3"      # distinct blue
atm_upper = "#EAF6FF"
atm_lower = "#DDEFF7"
surf_fill = "#E8F6EA"
surf_stroke = "#58A05A"
text_color = "#08121A"
arrow_gray = "#4a4a4a"

title_fs = 22
flux_fs  = 16
legend_fs = 14
small_fs = 12

# stroke mapping function
function stroke_for(val; vmin=0.0, vmax=450.0, wmin=3.0, wmax=22.0)
    t = clamp((val - vmin) / (vmax - vmin), 0.0, 1.0)
    return round(wmin + (wmax - wmin)*t, digits=2)
end

# bezier helpers
bezier_path(x1,y1, cx1,cy1, cx2,cy2, x2,y2) = "M $x1 $y1 C $cx1 $cy1, $cx2 $cy2, $x2 $y2"
function bezier_midpoint(x1,y1, cx1,cy1, cx2,cy2, x2,y2)
    x12 = (x1 + cx1)/2; y12 = (y1 + cy1)/2
    x23 = (cx1 + cx2)/2; y23 = (cy1 + cy2)/2
    x34 = (cx2 + x2)/2; y34 = (cy2 + y2)/2
    x123 = (x12 + x23)/2; y123 = (y12 + y23)/2
    x234 = (x23 + x34)/2; y234 = (y23 + y34)/2
    xmid = (x123 + x234)/2; ymid = (y123 + y234)/2
    return xmid, ymid
end

# helper to compute y at fraction of atmosphere
y_at_frac(frac) = atm_y + atm_h * clamp(frac, 0.0, 1.0)

# -----------------------
# Compose SVG
# -----------------------
svg = IOBuffer()
println(svg, "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>")
println(svg, "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"$W\" height=\"$H\" viewBox=\"0 0 $W $H\">")

# defs (gradients, markers, shadow)
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
    <feDropShadow dx="0" dy="8" stdDeviation="10" flood-color="#000000" flood-opacity="0.10"/>
  </filter>

  <marker id="arrow_gold" viewBox="0 0 10 10" refX="6" refY="5" markerWidth="7" markerHeight="7" orient="auto">
    <path d="M 0 0 L 10 5 L 0 10 z" fill="$sw_color" />
  </marker>
  <marker id="arrow_red" viewBox="0 0 10 10" refX="6" refY="5" markerWidth="7" markerHeight="7" orient="auto">
    <path d="M 0 0 L 10 5 L 0 10 z" fill="$lw_color" />
  </marker>
  <marker id="arrow_teal" viewBox="0 0 10 10" refX="6" refY="5" markerWidth="7" markerHeight="7" orient="auto">
    <path d="M 0 0 L 10 5 L 0 10 z" fill="$sens_color" />
  </marker>
  <marker id="arrow_blue" viewBox="0 0 10 10" refX="6" refY="5" markerWidth="7" markerHeight="7" orient="auto">
    <path d="M 0 0 L 10 5 L 0 10 z" fill="$lat_color" />
  </marker>
  <marker id="arrow_gray" viewBox="0 0 10 10" refX="6" refY="5" markerWidth="7" markerHeight="7" orient="auto">
    <path d="M 0 0 L 10 5 L 0 10 z" fill="$arrow_gray" />
  </marker>
</defs>
""")

# background
println(svg, "<rect width=\"100%\" height=\"100%\" fill=\"#ffffff\"/>")

# sun (compact, higher so SW arrow starts higher)
sun_cx = W/2; sun_cy = 28
println(svg, "<g id=\"sun\">")
println(svg, "  <circle cx=\"$sun_cx\" cy=\"$sun_cy\" r=\"20\" fill=\"#FFD54A\" stroke=\"#FFB300\" stroke-width=\"2\"/>")
for i in 0:7
    ang = i * 2pi / 8
    x1 = sun_cx + 26*cos(ang); y1 = sun_cy + 26*sin(ang)
    x2 = sun_cx + 36*cos(ang); y2 = sun_cy + 36*sin(ang)
    println(svg, "  <line x1=\"$x1\" y1=\"$y1\" x2=\"$x2\" y2=\"$y2\" stroke=\"#FFB300\" stroke-width=\"1.8\" stroke-linecap=\"round\"/>")
end
println(svg, "</g>")

# atmosphere rectangle
println(svg, "<g filter=\"url(#softShadow)\">")
println(svg, "  <rect x=\"$atm_x\" y=\"$atm_y\" rx=\"14\" ry=\"14\" width=\"$atm_w\" height=\"$atm_h\" fill=\"url(#atmGrad)\" stroke=\"#9fb7cf\" stroke-width=\"1.6\"/>")
println(svg, "</g>")

# lapse-rate ticks on left side (subtle)
tick_x = atm_x + 14
nticks = 6
for i in 0:nticks
    t = i/nticks
    ytick = atm_y + 30 + (atm_h - 60) * t
    # small short tick
    println(svg, "<line x1=\"$(tick_x)\" y1=\"$ytick\" x2=\"$(tick_x + 18)\" y2=\"$ytick\" stroke=\"#2d4758\" stroke-width=\"1.0\" stroke-dasharray=\"3,3\" opacity=\"0.7\"/>")
end
println(svg, "<text x=\"$(tick_x + 4)\" y=\"$(atm_y + 30)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"$small_fs\" fill=\"#2d4758\">Altitude ↑</text>")

# atmosphere title (left)
println(svg, "<text x=\"$(atm_x + 18)\" y=\"$(atm_y + 40)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"$title_fs\" fill=\"$text_color\">Atmosphere</text>")

# Surface with concave top: draw as path with a downward arc for top, then rectangle bottom
# We'll make a smooth concave top using a cubic bezier from left to right
top_arc_depth = 46   # depth of concavity
left_top_x = surf_x
left_top_y = surf_y
right_top_x = surf_x + surf_w
right_top_y = surf_y
cx1 = surf_x + surf_w*0.25
cy1 = surf_y + top_arc_depth
cx2 = surf_x + surf_w*0.75
cy2 = surf_y + top_arc_depth
bottom_y = surf_y + surf_h
# build path: move to left_top, cubic to right_top, then down/right/back/close
path_surface = "M $left_top_x $left_top_y C $cx1 $cy1, $cx2 $cy2, $right_top_x $right_top_y L $right_top_x $bottom_y L $left_top_x $bottom_y Z"
println(svg, "<g filter=\"url(#softShadow)\">")
println(svg, "  <path d=\"$path_surface\" fill=\"url(#surfGrad)\" stroke=\"$surf_stroke\" stroke-width=\"1.6\" rx=\"8\" ry=\"8\"/>")
println(svg, "</g>")
println(svg, "<text x=\"$(surf_x + 18)\" y=\"$(surf_y + 34)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"$title_fs\" fill=\"$text_color\">Surface</text>")

# -----------------------
# Arrows drawn last (so they cross)
# -----------------------
# lane x positions
lx_olr     = lanes[:olr]
lx_lw_up   = lanes[:lw_up]
lx_lw_down = lanes[:lw_down]
lx_sw      = lanes[:sw_down]
lx_sens    = lanes[:sens]
lx_lat     = lanes[:latent]
lx_swref   = lanes[:sw_ref]

# helper to place text safely near an arrow midpoint with optional nudges
function place_label(svgbuf, x, y, txt; dx=0, dy=0, anchor="start")
    println(svgbuf, "<text x=\"$((x+dx))\" y=\"$((y+dy))\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"$flux_fs\" fill=\"$text_color\" text-anchor=\"$anchor\">$txt</text>")
end

# SW Down (center): long graceful curve into concave surface
sw_st = stroke_for(sw_down)
sw_start_y = sun_cy + 36
sw_end_y   = surf_y + 18   # small penetration into surface top
path_sw = bezier_path(lx_sw, sw_start_y, lx_sw + 8, 260, lx_sw - 20, sw_end_y - 120, lx_sw, sw_end_y)
println(svg, "<path d=\"$path_sw\" fill=\"none\" stroke=\"$sw_color\" stroke-width=\"$sw_st\" stroke-linecap=\"round\" stroke-linejoin=\"round\" marker-end=\"url(#arrow_gold)\"/>")
mx_sw, my_sw = bezier_midpoint(lx_sw, sw_start_y, lx_sw + 8, 260, lx_sw - 20, sw_end_y - 120, lx_sw, sw_end_y)
place_label(svg, mx_sw, my_sw - 64, "SW Down $(fmt(sw_down))"; dx=0, dy=0, anchor="middle")
# SW absorbed label offset left so it doesn't overlap arrowheads
place_label(svg, lx_sw - 48, sw_end_y + 8, "SW Absorbed $(fmt(sw_abs))"; anchor="end")

# SW Reflected (right, short upward)
swr_st = stroke_for(sw_ref; vmax=280, wmin=3.0, wmax=14.0)
path_swref = bezier_path(lx_swref, atm_y + 36, lx_swref + 44, 140, lx_swref + 18, 20, lx_swref + 12, 28)
println(svg, "<path d=\"$path_swref\" fill=\"none\" stroke=\"$sw_color\" stroke-width=\"$swr_st\" stroke-linecap=\"round\" marker-end=\"url(#arrow_gold)\"/>")
place_label(svg, lx_swref + 108, atm_y + 44, "Reflected $(fmt(sw_ref))"; anchor="start")

# LW Up (left): from surface into lower-mid atmosphere
lwup_st = stroke_for(lw_up)
lwup_start_y = surf_y + 16
lwup_end_y   = y_at_frac(0.62)
path_lwup = bezier_path(lx_lw_up, lwup_start_y, lx_lw_up - 86, surf_y - 60, lx_lw_up - 42, lwup_end_y - 40, lx_lw_up + 8, lwup_end_y)
println(svg, "<path d=\"$path_lwup\" fill=\"none\" stroke=\"$lw_color\" stroke-width=\"$lwup_st\" stroke-linecap=\"round\" marker-end=\"url(#arrow_red)\"/>")
mx_lwup, my_lwup = bezier_midpoint(lx_lw_up, lwup_start_y, lx_lw_up - 86, surf_y - 60, lx_lw_up - 42, lwup_end_y - 40, lx_lw_up + 8, lwup_end_y)
place_label(svg, mx_lwup - 24, my_lwup - 6, "LW Up $(fmt(lw_up))"; anchor="end")

# LW Down (left of centre): high -> surface
lwdn_st = stroke_for(lw_down)
lwdn_start_y = y_at_frac(0.94)
lwdn_end_y   = surf_y + 18
path_lwdn = bezier_path(lx_lw_down, lwdn_start_y, lx_lw_down + 32, lwdn_start_y + 90, lx_lw_down - 20, lwdn_end_y - 120, lx_lw_down + 8, lwdn_end_y)
println(svg, "<path d=\"$path_lwdn\" fill=\"none\" stroke=\"$lw_color\" stroke-width=\"$lwdn_st\" stroke-linecap=\"round\" marker-end=\"url(#arrow_red)\"/>")
mx_lwdn, my_lwdn = bezier_midpoint(lx_lw_down, lwdn_start_y, lx_lw_down + 32, lwdn_start_y + 90, lx_lw_down - 20, lwdn_end_y - 120, lx_lw_down + 8, lwdn_end_y)
place_label(svg, mx_lwdn - 18, my_lwdn + 18, "LW Down $(fmt(lw_down))"; anchor="end")

# OLR (top-left): gentler arc (less exaggerated curvature)
olr_st = stroke_for(olr; wmin=3.0, wmax=14.0)
olr_start_y = y_at_frac(0.12)
# smaller control handles give a straighter arc
path_olr = bezier_path(lx_olr, olr_start_y, lx_olr - 24, olr_start_y + 90, lx_olr - 12, 26, lx_olr - 6, 26)
println(svg, "<path d=\"$path_olr\" fill=\"none\" stroke=\"$lw_color\" stroke-width=\"$olr_st\" stroke-linecap=\"round\" marker-end=\"url(#arrow_red)\"/>")
place_label(svg, lx_olr - 18, 36, "OLR $(fmt(olr))"; anchor="end")

# Sensible (teal): short arrow (surface -> ~34% of atm)
sens_st = stroke_for(h_val; vmax=60)
sens_start_y = surf_y + 18
sens_end_y   = y_at_frac(0.34)
path_sens = bezier_path(lx_sens, sens_start_y, lx_sens + 36, sens_start_y - 120, lx_sens + 26, sens_end_y + 80, lx_sens + 8, sens_end_y)
println(svg, "<path d=\"$path_sens\" fill=\"none\" stroke=\"$sens_color\" stroke-width=\"$sens_st\" stroke-dasharray=\"10,6\" stroke-linecap=\"round\" marker-end=\"url(#arrow_teal)\"/>")
mx_sens, my_sens = bezier_midpoint(lx_sens, sens_start_y, lx_sens + 36, sens_start_y - 120, lx_sens + 26, sens_end_y + 80, lx_sens + 8, sens_end_y)
place_label(svg, mx_sens + 36, my_sens - 14, "Sensible $(fmt(h_val))"; anchor="start")

# Latent (blue): moderate arrow (surface -> ~52% of atm)
lat_st = stroke_for(le_val; vmax=240)
lat_start_y = surf_y + 18
lat_end_y   = y_at_frac(0.52)
path_lat = bezier_path(lx_lat, lat_start_y, lx_lat + 40, lat_start_y - 140, lx_lat + 32, lat_end_y + 60, lx_lat + 10, lat_end_y)
println(svg, "<path d=\"$path_lat\" fill=\"none\" stroke=\"$lat_color\" stroke-width=\"$lat_st\" stroke-dasharray=\"10,6\" stroke-linecap=\"round\" marker-end=\"url(#arrow_blue)\"/>")
mx_lat, my_lat = bezier_midpoint(lx_lat, lat_start_y, lx_lat + 40, lat_start_y - 140, lx_lat + 32, lat_end_y + 60, lx_lat + 10, lat_end_y)
place_label(svg, mx_lat + 36, my_lat + 10, "Latent $(fmt(le_val))"; anchor="start")

# -----------------------
# Net labels & compact legend (bottom-right)
# -----------------------
println(svg, "<text x=\"$(W/2)\" y=\"$(atm_y + 48)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"$title_fs\" fill=\"$text_color\" text-anchor=\"middle\">Atmosphere net = $(fmt(atm_net))</text>")
println(svg, "<text x=\"$(W/2)\" y=\"$(H - 48)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"$title_fs\" fill=\"$text_color\" text-anchor=\"middle\">Surface net = $(fmt(surface_net))</text>")

# legend: smaller and inside bottom-right to avoid pushing canvas
leg_x = W - 300; leg_y = H - 200
println(svg, "<g>")
println(svg, "  <rect x=\"$leg_x\" y=\"$leg_y\" rx=\"8\" ry=\"8\" width=\"240\" height=\"140\" fill=\"#ffffff\" stroke=\"#e6eef5\" />")
println(svg, "  <text x=\"$(leg_x + 18)\" y=\"$(leg_y + 30)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"$legend_fs\" fill=\"$text_color\">Legend</text>")
println(svg, "  <line x1=\"$(leg_x + 18)\" y1=\"$(leg_y + 58)\" x2=\"$(leg_x + 72)\" y2=\"$(leg_y + 58)\" stroke=\"$sw_color\" stroke-width=\"10\" stroke-linecap=\"round\"/>")
println(svg, "  <text x=\"$(leg_x + 92)\" y=\"$(leg_y + 62)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"$legend_fs\" fill=\"$text_color\">Shortwave</text>")
println(svg, "  <line x1=\"$(leg_x + 18)\" y1=\"$(leg_y + 88)\" x2=\"$(leg_x + 72)\" y2=\"$(leg_y + 88)\" stroke=\"$lw_color\" stroke-width=\"10\" stroke-linecap=\"round\"/>")
println(svg, "  <text x=\"$(leg_x + 92)\" y=\"$(leg_y + 92)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"$legend_fs\" fill=\"$text_color\">Longwave</text>")
println(svg, "  <line x1=\"$(leg_x + 18)\" y1=\"$(leg_y + 118)\" x2=\"$(leg_x + 72)\" y2=\"$(leg_y + 118)\" stroke=\"$sens_color\" stroke-width=\"8\" stroke-dasharray=\"8,6\" stroke-linecap=\"round\"/>")
println(svg, "  <text x=\"$(leg_x + 92)\" y=\"$(leg_y + 122)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"$legend_fs\" fill=\"$text_color\">Sensible (teal)</text>")
println(svg, "  <line x1=\"$(leg_x + 18)\" y1=\"$(leg_y + 148)\" x2=\"$(leg_x + 72)\" y2=\"$(leg_y + 148)\" stroke=\"$lat_color\" stroke-width=\"8\" stroke-dasharray=\"8,6\" stroke-linecap=\"round\"/>")
println(svg, "  <text x=\"$(leg_x + 92)\" y=\"$(leg_y + 152)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"$legend_fs\" fill=\"$text_color\">Latent (blue)</text>")
println(svg, "</g>")

# timestamp
nowstr = Dates.format(now(), "yyyy-mm-dd HH:MM")
println(svg, "<text x=\"12\" y=\"$(H - 12)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"$small_fs\" fill=\"#666666\">Generated: $nowstr — trenberth_tidy2 (random example)</text>")

println(svg, "</svg>")

# Write SVG
outname = "trenberth_tidy2.svg"
open(outname, "w") do io
    write(io, String(take!(svg)))
end
println("Wrote $outname")

# Try PNG (rsvg-convert) if available
pngname = "trenberth_tidy2.png"
try
    run(`rsvg-convert -o $pngname $outname`)
    println("Also wrote $pngname (via rsvg-convert)")
catch e
    println("rsvg-convert not available or failed — SVG is produced; open the SVG in a browser.")
end

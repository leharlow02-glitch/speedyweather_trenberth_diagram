#!/usr/bin/env julia
# trenberth_optionA.jl
# Trenberth-style diagram (Option A): taller atmosphere, touching surface,
# spaced lanes for arrows, flux-dependent arrow heights, larger fonts.
# Run: julia trenberth_optionA.jl

using Random, Dates, Printf

Random.seed!(1234)

# -----------------------
# Numeric: plausible fluxes
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
# Canvas and layout
# -----------------------
W = 1250
H = 880
pad = 72

# Atmosphere: taller (Option A)
atm_x = 96
atm_y = 72
atm_w = W - 2*atm_x
atm_h = 320   # taller atmosphere

# Tropopause: keep small-ish (visual)
tropopause_frac = 0.35
split_y = atm_y + atm_h * tropopause_frac

# Surface sitting immediately below atmosphere (touching)
surf_x = atm_x
surf_y = atm_y + atm_h    # surface top matches atmosphere bottom
surf_w = atm_w
surf_h = 160               # relatively thin surface box

# Pre-defined lanes (x positions) left -> right for arrows (good for time series)
lanes = Dict(
    :lw_up    => atm_x + atm_w*0.30,
    :lw_down  => atm_x + atm_w*0.38,
    :sw_down  => W/2,
    :sens     => atm_x + atm_w*0.70,
    :latent   => atm_x + atm_w*0.84,
    :sw_ref   => atm_x + atm_w*0.90,
    :olr      => atm_x + atm_w*0.12
)

# Colors and styles
sw_color = "#F2C94C"
lw_color = "#E94B3C"
atm_upper = "#EAF6FF"
atm_lower = "#DDEFF7"
surf_fill = "#E6F7E6"
surf_stroke = "#6FA36F"
text_color = "#08121A"
arrow_gray = "#4a4a4a"

# Font sizes (bigger as requested)
title_fs = 22
flux_fs  = 16
legend_fs = 14
small_fs = 12

# stroke mapping: flux magnitude -> stroke width
function stroke_for(val; vmin=0.0, vmax=450.0, wmin=2.5, wmax=20.0)
    t = clamp((val - vmin) / (vmax - vmin), 0.0, 1.0)
    return round(wmin + (wmax - wmin)*t, digits=2)
end

# cubic bezier path helper
bezier_path(x1,y1, cx1,cy1, cx2,cy2, x2,y2) = "M $x1 $y1 C $cx1 $cy1, $cx2 $cy2, $x2 $y2"

# midpoint along cubic bezier (t=0.5) for label placement
function bezier_midpoint(x1,y1, cx1,cy1, cx2,cy2, x2,y2)
    x12 = (x1 + cx1)/2; y12 = (y1 + cy1)/2
    x23 = (cx1 + cx2)/2; y23 = (cy1 + cy2)/2
    x34 = (cx2 + x2)/2; y34 = (cy2 + y2)/2
    x123 = (x12 + x23)/2; y123 = (y12 + y23)/2
    x234 = (x23 + x34)/2; y234 = (y23 + y34)/2
    xmid = (x123 + x234)/2; ymid = (y123 + y234)/2
    return xmid, ymid
end

# -----------------------
# Compose SVG
# -----------------------
svg = IOBuffer()
println(svg, "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>")
println(svg, "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"$W\" height=\"$H\" viewBox=\"0 0 $W $H\">")

# defs: gradients, markers, shadow
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
    <feDropShadow dx="0" dy="6" stdDeviation="10" flood-color="#000000" flood-opacity="0.10"/>
  </filter>

  <marker id="arrow_gold" viewBox="0 0 10 10" refX="6" refY="5" markerWidth="6" markerHeight="6" orient="auto">
    <path d="M 0 0 L 10 5 L 0 10 z" fill="$sw_color" />
  </marker>
  <marker id="arrow_red" viewBox="0 0 10 10" refX="6" refY="5" markerWidth="6" markerHeight="6" orient="auto">
    <path d="M 0 0 L 10 5 L 0 10 z" fill="$lw_color" />
  </marker>
  <marker id="arrow_gray" viewBox="0 0 10 10" refX="6" refY="5" markerWidth="6" markerHeight="6" orient="auto">
    <path d="M 0 0 L 10 5 L 0 10 z" fill="$arrow_gray" />
  </marker>
</defs>
""")

# background
println(svg, "<rect width=\"100%\" height=\"100%\" fill=\"#ffffff\"/>")

# tiny sun at very top center
sun_cx = W/2; sun_cy = 44
println(svg, "<g id=\"sun\">")
println(svg, "  <circle cx=\"$sun_cx\" cy=\"$sun_cy\" r=\"20\" fill=\"#FFD54A\" stroke=\"#FFB300\" stroke-width=\"2\"/>")
for i in 0:7
    ang = i * 2pi / 8
    x1 = sun_cx + 26*cos(ang); y1 = sun_cy + 26*sin(ang)
    x2 = sun_cx + 40*cos(ang); y2 = sun_cy + 40*sin(ang)
    println(svg, "  <line x1=\"$x1\" y1=\"$y1\" x2=\"$x2\" y2=\"$y2\" stroke=\"#FFB300\" stroke-width=\"2\" stroke-linecap=\"round\"/>")
end
println(svg, "</g>")

# draw atmosphere rectangle (draw boxes first, arrows later so they cross)
println(svg, "<g filter=\"url(#softShadow)\">")
println(svg, "  <rect x=\"$atm_x\" y=\"$atm_y\" rx=\"12\" ry=\"12\" width=\"$atm_w\" height=\"$atm_h\" fill=\"url(#atmGrad)\" stroke=\"#9fb7cf\" stroke-width=\"1.6\"/>")
println(svg, "</g>")

# tropopause dashed line
println(svg, "<line x1=\"$(atm_x + 10)\" y1=\"$split_y\" x2=\"$(atm_x + atm_w - 10)\" y2=\"$split_y\" stroke=\"#2f556e\" stroke-width=\"1.2\" stroke-dasharray=\"6,6\" opacity=\"0.8\"/>")
println(svg, "<text x=\"$(atm_x + 16)\" y=\"$(split_y - 8)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"$small_fs\" fill=\"#2f556e\">Tropopause (guide)</text>")

# atmosphere title
println(svg, "<text x=\"$(atm_x + 16)\" y=\"$(atm_y + 32)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"$title_fs\" fill=\"$text_color\">Atmosphere</text>")

# draw surface rectangle immediately below atmosphere (touching)
println(svg, "<g filter=\"url(#softShadow)\">")
println(svg, "  <rect x=\"$surf_x\" y=\"$surf_y\" rx=\"12\" ry=\"12\" width=\"$surf_w\" height=\"$surf_h\" fill=\"url(#surfGrad)\" stroke=\"$surf_stroke\" stroke-width=\"1.6\"/>")
println(svg, "</g>")
println(svg, "<text x=\"$(surf_x + 16)\" y=\"$(surf_y + 28)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"$title_fs\" fill=\"$text_color\">Surface</text>")

# -----------------------
# Arrows: drawn on top so they cross boxes
# -----------------------

# utility to compute y positions based on fraction of atmosphere height
function y_at_frac(frac)
    return atm_y + atm_h * frac
end

# lane x positions
lx_lw_up   = lanes[:lw_up]
lx_lw_down = lanes[:lw_down]
lx_sw      = lanes[:sw_down]
lx_sens    = lanes[:sens]
lx_lat     = lanes[:latent]
lx_swref   = lanes[:sw_ref]
lx_olr     = lanes[:olr]

# SW Down: from sun -> surface center (full height)
sw_st = stroke_for(sw_down)
sw_start_y = sun_cy + 34
sw_end_y   = surf_y + surf_h*0.32  # arrow points into surface region (a bit above bottom)
path_sw = bezier_path(lx_sw, sw_start_y, lx_sw + 8, 180, lx_sw - 22, sw_end_y - 80, lx_sw, sw_end_y)
println(svg, "<path d=\"$path_sw\" fill=\"none\" stroke=\"$sw_color\" stroke-width=\"$sw_st\" stroke-linecap=\"round\" stroke-linejoin=\"round\" marker-end=\"url(#arrow_gold)\"/>")
mx_sw, my_sw = bezier_midpoint(lx_sw, sw_start_y, lx_sw + 8, 180, lx_sw - 22, sw_end_y - 80, lx_sw, sw_end_y)
println(svg, "<text x=\"$(mx_sw)\" y=\"$(my_sw - 44)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"$flux_fs\" fill=\"$text_color\" text-anchor=\"middle\">SW Down $(fmt(sw_down))</text>")
println(svg, "<text x=\"$(lx_sw - 40)\" y=\"$(sw_end_y + 6)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"$flux_fs\" fill=\"$text_color\" text-anchor=\"end\">SW Absorbed $(fmt(sw_abs))</text>")

# SW Reflected: short upward arrow at right
swr_st = stroke_for(sw_ref; vmax=260, wmin=2.5, wmax=12)
path_swref = bezier_path(lx_swref, atm_y + 34, lx_swref + 36, 120, lx_swref + 10, 12, lx_swref + 10, 22)
println(svg, "<path d=\"$path_swref\" fill=\"none\" stroke=\"$sw_color\" stroke-width=\"$swr_st\" stroke-linecap=\"round\" marker-end=\"url(#arrow_gold)\"/>")
println(svg, "<text x=\"$(lx_swref + 72)\" y=\"36\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"$flux_fs\" fill=\"$text_color\">Reflected $(fmt(sw_ref))</text>")

# LW Up: from surface into lower/medium atmosphere (doesn't reach top)
lwup_st = stroke_for(lw_up)
lwup_start_y = surf_y + 18
lwup_end_y   = y_at_frac(0.65)   # about 65% up the atmosphere
path_lwup = bezier_path(lx_lw_up, lwup_start_y, lx_lw_up - 60, surf_y - 40, lx_lw_up - 30, lwup_end_y - 30, lx_lw_up + 8, lwup_end_y)
println(svg, "<path d=\"$path_lwup\" fill=\"none\" stroke=\"$lw_color\" stroke-width=\"$lwup_st\" stroke-linecap=\"round\" marker-end=\"url(#arrow_red)\"/>")
mx_lwup, my_lwup = bezier_midpoint(lx_lw_up, lwup_start_y, lx_lw_up - 60, surf_y - 40, lx_lw_up - 30, lwup_end_y - 30, lx_lw_up + 8, lwup_end_y)
println(svg, "<text x=\"$(mx_lwup - 18)\" y=\"$(my_lwup - 8)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"$flux_fs\" fill=\"$text_color\" text-anchor=\"end\">LW Up $(fmt(lw_up))</text>")

# LW Down: from high atmosphere down to surface (longer)
lwdn_st = stroke_for(lw_down)
lwdn_start_y = y_at_frac(0.92)   # originates high in atmosphere but below very top
lwdn_end_y   = surf_y + surf_h*0.30
path_lwdn = bezier_path(lx_lw_down, lwdn_start_y, lx_lw_down + 12, lwdn_start_y + 60, lx_lw_down - 12, lwdn_end_y - 80, lx_lw_down + 6, lwdn_end_y)
println(svg, "<path d=\"$path_lwdn\" fill=\"none\" stroke=\"$lw_color\" stroke-width=\"$lwdn_st\" stroke-linecap=\"round\" marker-end=\"url(#arrow_red)\"/>")
mx_lwdn, my_lwdn = bezier_midpoint(lx_lw_down, lwdn_start_y, lx_lw_down + 12, lwdn_start_y + 60, lx_lw_down - 12, lwdn_end_y - 80, lx_lw_down + 6, lwdn_end_y)
println(svg, "<text x=\"$(mx_lwdn - 18)\" y=\"$(my_lwdn + 16)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"$flux_fs\" fill=\"$text_color\" text-anchor=\"end\">LW Down $(fmt(lw_down))</text>")

# OLR: from upper atmosphere off to the top-left
olr_st = stroke_for(olr; wmin=2.5, wmax=12)
olr_start_y = y_at_frac(0.12)
path_olr = bezier_path(lx_olr, olr_start_y, lx_olr - 40, olr_start_y + 80, lx_olr - 20, 18, lx_olr - 6, 18)
println(svg, "<path d=\"$path_olr\" fill=\"none\" stroke=\"$lw_color\" stroke-width=\"$olr_st\" stroke-linecap=\"round\" marker-end=\"url(#arrow_red)\"/>")
println(svg, "<text x=\"$(lx_olr - 16)\" y=\"36\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"$flux_fs\" fill=\"$text_color\" text-anchor=\"end\">OLR $(fmt(olr))</text>")

# Sensible: short arrow (surface -> ~30% atmosphere)
sens_st = stroke_for(h_val; vmax=60)
sens_start_y = surf_y + 18
sens_end_y   = y_at_frac(0.40)    # only goes partway up
path_sens = bezier_path(lx_sens, sens_start_y, lx_sens + 32, sens_start_y - 80, lx_sens + 24, sens_end_y + 40, lx_sens + 4, sens_end_y)
println(svg, "<path d=\"$path_sens\" fill=\"none\" stroke=\"$arrow_gray\" stroke-width=\"$sens_st\" stroke-dasharray=\"8,6\" stroke-linecap=\"round\" marker-end=\"url(#arrow_gray)\"/>")
mx_sens, my_sens = bezier_midpoint(lx_sens, sens_start_y, lx_sens + 32, sens_start_y - 80, lx_sens + 24, sens_end_y + 40, lx_sens + 4, sens_end_y)
println(svg, "<text x=\"$(mx_sens + 26)\" y=\"$(my_sens - 8)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"$flux_fs\" fill=\"$text_color\">Sensible $(fmt(h_val))</text>")

# Latent: moderate arrow (surface -> ~55% atmosphere)
lat_st = stroke_for(le_val; vmax=200)
lat_start_y = surf_y + 18
lat_end_y   = y_at_frac(0.55)
path_lat = bezier_path(lx_lat, lat_start_y, lx_lat + 36, lat_start_y - 90, lx_lat + 30, lat_end_y + 30, lx_lat + 8, lat_end_y)
println(svg, "<path d=\"$path_lat\" fill=\"none\" stroke=\"$arrow_gray\" stroke-width=\"$lat_st\" stroke-dasharray=\"8,6\" stroke-linecap=\"round\" marker-end=\"url(#arrow_gray)\"/>")
mx_lat, my_lat = bezier_midpoint(lx_lat, lat_start_y, lx_lat + 36, lat_start_y - 90, lx_lat + 30, lat_end_y + 30, lx_lat + 8, lat_end_y)
println(svg, "<text x=\"$(mx_lat + 30)\" y=\"$(my_lat + 12)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"$flux_fs\" fill=\"$text_color\">Latent $(fmt(le_val))</text>")

# -----------------------
# Net labels and legend
# -----------------------
println(svg, "<text x=\"$(W/2)\" y=\"$(atm_y + 44)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"$title_fs\" fill=\"$text_color\" text-anchor=\"middle\">Atmosphere net = $(fmt(atm_net))</text>")
println(svg, "<text x=\"$(W/2)\" y=\"$(H - 60)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"$title_fs\" fill=\"$text_color\" text-anchor=\"middle\">Surface net = $(fmt(surface_net))</text>")

# legend bottom-right
leg_x = W - 320; leg_y = H - 190
println(svg, "<g>")
println(svg, "  <rect x=\"$leg_x\" y=\"$leg_y\" rx=\"10\" ry=\"10\" width=\"260\" height=\"160\" fill=\"#ffffff\" stroke=\"#e6eef5\" />")
println(svg, "  <text x=\"$(leg_x + 20)\" y=\"$(leg_y + 36)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"$legend_fs\" fill=\"$text_color\">Legend</text>")
println(svg, "  <line x1=\"$(leg_x + 20)\" y1=\"$(leg_y + 72)\" x2=\"$(leg_x + 90)\" y2=\"$(leg_y + 72)\" stroke=\"$sw_color\" stroke-width=\"10\" stroke-linecap=\"round\"/>")
println(svg, "  <text x=\"$(leg_x + 110)\" y=\"$(leg_y + 76)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"$legend_fs\" fill=\"$text_color\">Shortwave</text>")
println(svg, "  <line x1=\"$(leg_x + 20)\" y1=\"$(leg_y + 106)\" x2=\"$(leg_x + 90)\" y2=\"$(leg_y + 106)\" stroke=\"$lw_color\" stroke-width=\"10\" stroke-linecap=\"round\"/>")
println(svg, "  <text x=\"$(leg_x + 110)\" y=\"$(leg_y + 110)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"$legend_fs\" fill=\"$text_color\">Longwave</text>")
println(svg, "  <line x1=\"$(leg_x + 20)\" y1=\"$(leg_y + 140)\" x2=\"$(leg_x + 90)\" y2=\"$(leg_y + 140)\" stroke=\"$arrow_gray\" stroke-width=\"8\" stroke-dasharray=\"8,6\" stroke-linecap=\"round\"/>")
println(svg, "  <text x=\"$(leg_x + 110)\" y=\"$(leg_y + 144)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"$legend_fs\" fill=\"$text_color\">Turbulent (Sensible/Latent)</text>")
println(svg, "</g>")

# timestamp
nowstr = Dates.format(now(), "yyyy-mm-dd HH:MM")
println(svg, "<text x=\"16\" y=\"$(H - 18)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"$small_fs\" fill=\"#666666\">Generated: $nowstr — trenberth_optionA (random example)</text>")

println(svg, "</svg>")

# Write SVG
outname = "trenberth_optionA.svg"
open(outname, "w") do io
    write(io, String(take!(svg)))
end
println("Wrote $outname")

# Try to make PNG with rsvg-convert if available
pngname = "trenberth_optionA.png"
try
    run(`rsvg-convert -o $pngname $outname`)
    println("Also wrote $pngname (via rsvg-convert)")
catch e
    println("rsvg-convert not available or failed — SVG is produced; open the SVG in a browser.")
end

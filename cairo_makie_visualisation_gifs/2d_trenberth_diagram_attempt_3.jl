#!/usr/bin/env julia
# pretty_trenberth_tidy.jl
# Tidied Trenberth-style SVG: label collision avoidance, smaller green surface box,
# reduced stratosphere, and arrows crossing the atmosphere box.
# Run: julia pretty_trenberth_tidy.jl

using Random, Dates, Printf

Random.seed!(1234)

# --- numeric generation -----------------------------------------------------
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

# --- canvas & layout -------------------------------------------------------
W = 1200; H = 820
pad = 80

# Atmosphere (larger for arrows but with smaller stratosphere)
atm_x = 120; atm_y = 80; atm_w = W - 2*atm_x; atm_h = 220
# make stratosphere small (upper ~30% of atm), troposphere larger
tropopause_frac = 0.30
split_y = atm_y + atm_h * tropopause_frac

# Surface: smaller, green, closer to bottom
surf_w = atm_w
surf_h = 160
surf_x = atm_x
surf_y = H - pad - surf_h - 10  # pushed near bottom

# colors / style
sw_color = "#F2C94C"
lw_color = "#E94B3C"
atm_lower = "#DDEFF7"; atm_upper = "#EAF6FF"
surf_fill = "#E6F7E6"   # soft green
surf_stroke = "#7AB07A"
text_color = "#08121A"
arrow_stroke = "#333333"

# map flux -> stroke width
function stroke_for(val; vmin=0.0, vmax=450.0, wmin=2.0, wmax=20.0)
    t = clamp((val - vmin) / (vmax - vmin), 0.0, 1.0)
    return round(wmin + (wmax - wmin)*t, digits=2)
end

# cubic bezier helper
bezier_path(x1,y1, cx1,cy1, cx2,cy2, x2,y2) = "M $x1 $y1 C $cx1 $cy1, $cx2 $cy2, $x2 $y2"

# small utility to compute approximate midpoint (use t=0.5 for cubic bezier)
function bezier_midpoint(x1,y1, cx1,cy1, cx2,cy2, x2,y2)
    # Use De Casteljau at t=0.5
    x12 = (x1 + cx1)/2; y12 = (y1 + cy1)/2
    x23 = (cx1 + cx2)/2; y23 = (cy1 + cy2)/2
    x34 = (cx2 + x2)/2; y34 = (cy2 + y2)/2
    x123 = (x12 + x23)/2; y123 = (y12 + y23)/2
    x234 = (x23 + x34)/2; y234 = (y23 + y34)/2
    xmid = (x123 + x234)/2; ymid = (y123 + y234)/2
    return xmid, ymid
end

# --- SVG composition -------------------------------------------------------
svg = IOBuffer()
println(svg, "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>")
println(svg, "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"$W\" height=\"$H\" viewBox=\"0 0 $W $H\">")

# defs: gradients, arrowheads, shadow
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

# background
println(svg, "<rect width=\"100%\" height=\"100%\" fill=\"#ffffff\"/>")

# tiny sun at top center (origin for SW Down)
sun_cx = W/2; sun_cy = 36
println(svg, "<g id=\"sun\">")
println(svg, "  <circle cx=\"$sun_cx\" cy=\"$sun_cy\" r=\"18\" fill=\"#FFD54A\" stroke=\"#FFB300\" stroke-width=\"2\"/>")
for i in 0:7
    ang = i * 2pi / 8
    x1 = sun_cx + 22*cos(ang); y1 = sun_cy + 22*sin(ang)
    x2 = sun_cx + 36*cos(ang); y2 = sun_cy + 36*sin(ang)
    println(svg, "  <line x1=\"$x1\" y1=\"$y1\" x2=\"$x2\" y2=\"$y2\" stroke=\"#FFB300\" stroke-width=\"2\" stroke-linecap=\"round\"/>")
end
println(svg, "</g>")

# Atmosphere rectangle (draw first; arrows will be drawn AFTER so they overlap the box)
println(svg, "<g filter=\"url(#softShadow)\">")
println(svg, "  <rect x=\"$atm_x\" y=\"$atm_y\" rx=\"12\" ry=\"12\" width=\"$atm_w\" height=\"$atm_h\" fill=\"url(#atmGrad)\" stroke=\"#9fb7cf\" stroke-width=\"1.4\"/>")
println(svg, "</g>")

# tropopause (dashed) and labels inside
println(svg, "<line x1=\"$(atm_x + 8)\" y1=\"$split_y\" x2=\"$(atm_x + atm_w - 8)\" y2=\"$split_y\" stroke=\"#2f556e\" stroke-width=\"1.2\" stroke-dasharray=\"6,6\" opacity=\"0.8\"/>")
println(svg, "<text x=\"$(atm_x + 18)\" y=\"$(split_y - 8)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"12\" fill=\"#2f556e\">Tropopause (guide)</text>")

# lapse rate guide (left) - unchanged visuals, but subtle
lr_x = atm_x + 18; lr_top_y = atm_y + 18; lr_bottom_y = atm_y + atm_h - 18
println(svg, "<g opacity=\"0.9\">")
println(svg, "  <line x1=\"$lr_x\" y1=\"$lr_top_y\" x2=\"$(lr_x + 30)\" y2=\"$lr_bottom_y\" stroke=\"#2d4758\" stroke-width=\"1.0\" stroke-dasharray=\"4,6\" opacity=\"0.9\"/>")
println(svg, "</g>")

# Atmosphere title
println(svg, "<text x=\"$(atm_x + 18)\" y=\"$(atm_y + 30)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"18\" fill=\"$text_color\">Atmosphere</text>")

# Surface box (smaller, green, near bottom)
println(svg, "<g filter=\"url(#softShadow)\">")
println(svg, "  <rect x=\"$surf_x\" y=\"$surf_y\" rx=\"12\" ry=\"12\" width=\"$surf_w\" height=\"$surf_h\" fill=\"url(#surfGrad)\" stroke=\"$surf_stroke\" stroke-width=\"1.5\"/>")
println(svg, "</g>")
println(svg, "<text x=\"$(surf_x + 18)\" y=\"$(surf_y + 28)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"18\" fill=\"$text_color\">Surface</text>")

# --- arrows (draw on top so they visibly cross boxes) ---------------------

cx = W/2

# SW Down: from sun to surface (curved). Label placed near top of arrow to avoid overlap.
sw_stroke = stroke_for(sw_down)
path_sw = bezier_path(sun_cx, sun_cy + 34,
                      sun_cx + 6, 140,
                      cx - 20, surf_y - 76,
                      cx, surf_y + 12)
println(svg, "<path d=\"$path_sw\" fill=\"none\" stroke=\"$sw_color\" stroke-width=\"$sw_stroke\" stroke-linecap=\"round\" stroke-linejoin=\"round\" marker-end=\"url(#arrow_gold)\"/>")
# label for SW Down: put it slightly above the top half of path
text_sw_x, text_sw_y = bezier_midpoint(sun_cx, sun_cy + 34, sun_cx + 6, 140, cx - 20, surf_y - 76, cx, surf_y + 12)
println(svg, "<text x=\"$(text_sw_x)\" y=\"$(text_sw_y - 46)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"14\" fill=\"$text_color\" text-anchor=\"middle\">SW Down $(fmt(sw_down))</text>")
# SW absorbed label near surface but offset left to avoid colliding with other arrows
println(svg, "<text x=\"$(cx - 40)\" y=\"$(surf_y - 12)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"13\" fill=\"$text_color\" text-anchor=\"end\">SW Absorbed $(fmt(sw_abs))</text>")

# SW Reflected (right-hand side): move label outward and above the top to avoid overlap
swref_stroke = stroke_for(sw_ref; vmax=240, wmin=2, wmax=12)
rx = atm_x + atm_w*0.82
path_swref = bezier_path(rx, atm_y + 34, rx+40, 12, rx+18, 6, rx+10, 18)
println(svg, "<path d=\"$path_swref\" fill=\"none\" stroke=\"$sw_color\" stroke-width=\"$swref_stroke\" stroke-linecap=\"round\" marker-end=\"url(#arrow_gold)\"/>")
println(svg, "<text x=\"$(rx + 80)\" y=\"36\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"13\" fill=\"$text_color\">Reflected $(fmt(sw_ref))</text>")

# LW Up: label placed to left & slightly above to avoid central overlap
lwup_stroke = stroke_for(lw_up)
lx = surf_x + surf_w*0.40
path_lwup = bezier_path(lx, surf_y + 22,
                        lx - 60, surf_y - 44,
                        lx - 30, atm_y + atm_h*0.72,
                        lx + 6, atm_y + atm_h - 12)
println(svg, "<path d=\"$path_lwup\" fill=\"none\" stroke=\"$lw_color\" stroke-width=\"$lwup_stroke\" stroke-linecap=\"round\" marker-end=\"url(#arrow_red)\"/>")
# place label near midpoint but nudged left/up
mx, my = bezier_midpoint(lx, surf_y + 22, lx - 60, surf_y - 44, lx - 30, atm_y + atm_h*0.72, lx + 6, atm_y + atm_h - 12)
println(svg, "<text x=\"$(mx - 28)\" y=\"$(my - 6)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"13\" fill=\"$text_color\" text-anchor=\"end\">LW Up $(fmt(lw_up))</text>")

# LW Down: label placed to left & slightly below to separate from LW Up
lwdn_stroke = stroke_for(lw_down)
lx2 = surf_x + surf_w*0.34
path_lwdn = bezier_path(lx2, atm_y + atm_h - 14,
                        lx2 + 18, atm_y + atm_h + 30,
                        lx2 - 6, surf_y - 36,
                        lx2 + 6, surf_y + 8)
println(svg, "<path d=\"$path_lwdn\" fill=\"none\" stroke=\"$lw_color\" stroke-width=\"$lwdn_stroke\" stroke-linecap=\"round\" marker-end=\"url(#arrow_red)\"/>")
mx2, my2 = bezier_midpoint(lx2, atm_y + atm_h - 14, lx2 + 18, atm_y + atm_h + 30, lx2 - 6, surf_y - 36, lx2 + 6, surf_y + 8)
println(svg, "<text x=\"$(mx2 - 18)\" y=\"$(my2 + 14)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"13\" fill=\"$text_color\" text-anchor=\"end\">LW Down $(fmt(lw_down))</text>")

# OLR (top-left): label nudged left so it doesn't collide with sun label
olr_stroke = stroke_for(olr; wmin=2, wmax=12)
olx = atm_x + atm_w*0.12
path_olr = bezier_path(olx, atm_y + 20, olx - 34, 44, olx - 18, 12, olx - 6, 18)
println(svg, "<path d=\"$path_olr\" fill=\"none\" stroke=\"$lw_color\" stroke-width=\"$olr_stroke\" stroke-linecap=\"round\" marker-end=\"url(#arrow_red)\"/>")
println(svg, "<text x=\"$(olx - 14)\" y=\"36\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"13\" fill=\"$text_color\" text-anchor=\"end\">OLR $(fmt(olr))</text>")

# Sensible & Latent: move labels outward and ensure vertical spacing to prevent overlap
sy_surf = surf_y + 28; sy_atm = atm_y + atm_h - 12
sx1 = surf_x + surf_w*0.68
sens_stroke = stroke_for(h_val; vmax=60)
path_sens = bezier_path(sx1, sy_surf, sx1 + 36, sy_surf - 80, sx1 + 36, sy_atm + 80, sx1 + 6, sy_atm)
println(svg, "<path d=\"$path_sens\" fill=\"none\" stroke=\"#4a4a4a\" stroke-width=\"$sens_stroke\" stroke-dasharray=\"8,6\" stroke-linecap=\"round\" marker-end=\"url(#arrow_gray)\"/>")
mxs, mys = bezier_midpoint(sx1, sy_surf, sx1 + 36, sy_surf - 80, sx1 + 36, sy_atm + 80, sx1 + 6, sy_atm)
println(svg, "<text x=\"$(sx1 + 56)\" y=\"$(mys - 18)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"13\" fill=\"$text_color\">Sensible $(fmt(h_val))</text>")

sx2 = surf_x + surf_w*0.84
le_stroke = stroke_for(le_val; vmax=200)
path_le = bezier_path(sx2, sy_surf, sx2 + 36, sy_surf - 80, sx2 + 36, sy_atm + 80, sx2 + 6, sy_atm)
println(svg, "<path d=\"$path_le\" fill=\"none\" stroke=\"#4a4a4a\" stroke-width=\"$le_stroke\" stroke-dasharray=\"8,6\" stroke-linecap=\"round\" marker-end=\"url(#arrow_gray)\"/>")
mxl, myl = bezier_midpoint(sx2, sy_surf, sx2 + 36, sy_surf - 80, sx2 + 36, sy_atm + 80, sx2 + 6, sy_atm)
println(svg, "<text x=\"$(sx2 + 56)\" y=\"$(myl + 8)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"13\" fill=\"$text_color\">Latent $(fmt(le_val))</text>")

# --- labels & legend ------------------------------------------------------
# Atmosphere net (center top), moved a bit down to avoid colliding with sun
println(svg, "<text x=\"$(W/2)\" y=\"66\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"16\" fill=\"$text_color\" text-anchor=\"middle\">Atmosphere net = $(fmt(atm_net))</text>")
# Surface net (bottom center)
println(svg, "<text x=\"$(W/2)\" y=\"$(H - 52)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"16\" fill=\"$text_color\" text-anchor=\"middle\">Surface net = $(fmt(surface_net))</text>")

# Legend (kept to bottom-right)
leg_x = W - 280; leg_y = H - 170
println(svg, "<g>")
println(svg, "  <rect x=\"$leg_x\" y=\"$leg_y\" rx=\"8\" ry=\"8\" width=\"240\" height=\"140\" fill=\"#ffffff\" stroke=\"#e6eef5\" />")
println(svg, "  <text x=\"$(leg_x + 18)\" y=\"$(leg_y + 28)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"13\" fill=\"$text_color\">Legend</text>")
println(svg, "  <line x1=\"$(leg_x + 18)\" y1=\"$(leg_y + 54)\" x2=\"$(leg_x + 68)\" y2=\"$(leg_y + 54)\" stroke=\"$sw_color\" stroke-width=\"8\" stroke-linecap=\"round\"/>")
println(svg, "  <text x=\"$(leg_x + 86)\" y=\"$(leg_y + 58)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"12\" fill=\"$text_color\">Shortwave</text>")
println(svg, "  <line x1=\"$(leg_x + 18)\" y1=\"$(leg_y + 84)\" x2=\"$(leg_x + 68)\" y2=\"$(leg_y + 84)\" stroke=\"$lw_color\" stroke-width=\"8\" stroke-linecap=\"round\"/>")
println(svg, "  <text x=\"$(leg_x + 86)\" y=\"$(leg_y + 88)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"12\" fill=\"$text_color\">Longwave</text>")
println(svg, "  <line x1=\"$(leg_x + 18)\" y1=\"$(leg_y + 114)\" x2=\"$(leg_x + 68)\" y2=\"$(leg_y + 114)\" stroke=\"#4a4a4a\" stroke-width=\"6\" stroke-dasharray=\"8,6\" stroke-linecap=\"round\"/>")
println(svg, "  <text x=\"$(leg_x + 86)\" y=\"$(leg_y + 118)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"12\" fill=\"$text_color\">Turbulent (Sensible/Latent)</text>")
println(svg, "</g>")

# timestamp
nowstr = Dates.format(now(), "yyyy-mm-dd HH:MM")
println(svg, "<text x=\"14\" y=\"$(H - 18)\" font-family=\"Verdana, Arial, sans-serif\" font-size=\"12\" fill=\"#666666\">Generated: $nowstr — pretty_trenberth_tidy (random example)</text>")

println(svg, "</svg>")

# write
outname = "3_trenberth.svg"
open(outname, "w") do io
    write(io, String(take!(svg)))
end

println("Wrote $outname")

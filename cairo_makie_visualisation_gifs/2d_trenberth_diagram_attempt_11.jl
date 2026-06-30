#!/usr/bin/env julia
# trenberth_columns_v8.jl
# Aggressive separation: LW stack left, SW stack moved far right,
# sensible & latent separated more widely in the centre, shorter heights retained.
# Run: julia trenberth_columns_v8.jl

using Random, Dates, Printf

Random.seed!(1234)

# -----------------------
# Flux numbers (random plausible)
# -----------------------
perturb(base; frac=0.08) = base * (1 + (rand() - 0.5) * 2 * frac)

sw_down_base = 340.0; sw_ref_base = 100.0
lw_up_base = 396.0; lw_down_base = 340.0
h_base = 17.0; le_base = 80.0

sw_down = perturb(sw_down_base, frac=0.03)
sw_ref  = clamp(perturb(sw_ref_base, frac=0.12), 0.0, sw_down*0.95)
sw_abs  = sw_down - sw_ref

lw_up   = perturb(lw_up_base, frac=0.02)
lw_down = clamp(perturb(lw_down_base, frac=0.03), 0.0, lw_up)
h_val   = clamp(perturb(h_base, frac=0.3), 0.0, 500.0)
le_val  = clamp(perturb(le_base, frac=0.2), 0.0, 500.0)

surface_net = (sw_abs + lw_down) - (lw_up + h_val + le_val)
atm_net     = (lw_up + sw_ref) - (lw_down + sw_ref)  # placeholder for display

fmt(x) = @sprintf("%.1f W/m²", x)

# -----------------------
# Canvas & layout
# -----------------------
W = 1280
H = 880
pad = 56

atm_x = pad
atm_y = 36
atm_w = W - 2*pad
atm_h = 520

# surface convex-up
surf_x = atm_x
surf_y = atm_y + atm_h
surf_w = atm_w
surf_h = 120

# thin columns and aggressive horizontal separation
thin_w = atm_w * 0.075    # narrow columns
# make LW pair on far left, SW pair on far right by using larger gap/multipliers
left_cluster_x = atm_x + 36
right_cluster_x = atm_x + atm_w - 36 - thin_w*2 - 10  # anchor for right cluster

# bottom positions for columns (we place LW pair near left_cluster_x and SW pair near right_cluster_x)
col_bottom_x = [
  left_cluster_x,                     # LW left bottom
  left_cluster_x + thin_w*0.9 + 8.0,  # LW right bottom (close to left LW)
  right_cluster_x,                    # SW left bottom (right cluster)
  right_cluster_x + thin_w*0.9 + 8.0  # SW right bottom (partner)
]

# LW V-shape slant stronger; SW slight inward slant
slant_px = 70
col_top_x = [
  col_bottom_x[1] - slant_px,
  col_bottom_x[2] + slant_px,
  col_bottom_x[3] - (slant_px/4),
  col_bottom_x[4] + (slant_px/4)
]

# polygon helper & centers
function col_polygon_coords(i)
  bx = col_bottom_x[i]; tx = col_top_x[i]; w = thin_w
  x1 = tx; y1 = atm_y + 12
  x2 = tx + w; y2 = atm_y + 12
  x3 = bx + w; y3 = atm_y + atm_h - 12
  x4 = bx; y4 = atm_y + atm_h - 12
  return (x1,y1,x2,y2,x3,y3,x4,y4)
end
col_centers = [(col_top_x[i] + col_bottom_x[i] + thin_w)/2 for i in 1:4]

# colours & fonts
sw_color = "#F2C94C"
lw_color = "#E94B3C"
sens_color = "#0F6B6B"
lat_color  = "#1F4FA3"
atm_grad_top = "#EAF6FF"
atm_grad_bot = "#DDEFF7"
surf_fill = "#F3FBF3"
surf_stroke = "#55a057"
text_color = "#08121A"

title_fs = 22
flux_fs  = 15
legend_fs = 13
small_fs = 10

# stroke mapping
function stroke_for(val; vmin=0.0, vmax=450.0, wmin=4.0, wmax=30.0)
  t = clamp((val - vmin)/(vmax - vmin), 0.0, 1.0)
  return round(wmin + (wmax - wmin)*t, digits=2)
end

# vertical positions
y_top = atm_y + 18
y_surface_pen = surf_y + 12

# arrow heights (keep sensible/latent short)
y_lw_up_start = y_surface_pen
y_lw_up_end   = atm_y + atm_h * 0.58

y_lw_down_start = atm_y + atm_h * 0.98
y_lw_down_end   = y_surface_pen

y_sw_top = y_top
y_sw_end = y_surface_pen

y_ref_start = y_surface_pen
y_ref_end   = y_top

# Sensible and latent much shorter and separated horizontally
y_sens_start = y_surface_pen
y_sens_end   = atm_y + atm_h * 0.12   # short
y_lat_start  = y_surface_pen
y_lat_end    = atm_y + atm_h * 0.18   # slightly higher than sensible but still short

# -----------------------
# Compose SVG
# -----------------------
svg = IOBuffer()
println(svg, "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>")
println(svg, "<svg xmlns='http://www.w3.org/2000/svg' width='$W' height='$H' viewBox='0 0 $W $H'>")

# defs
println(svg, """
<defs>
  <linearGradient id="atmGrad" x1="0" x2="0" y1="0" y2="1">
    <stop offset="0%" stop-color="$atm_grad_top"/>
    <stop offset="100%" stop-color="$atm_grad_bot"/>
  </linearGradient>
  <linearGradient id="surfGrad" x1="0" x2="0" y1="0" y2="1">
    <stop offset="0%" stop-color="#FFFFFF"/>
    <stop offset="100%" stop-color="$surf_fill"/>
  </linearGradient>
  <filter id="softShadow" x='-20%' y='-20%' width='140%' height='140%'><feDropShadow dx='0' dy='8' stdDeviation='10' flood-color='#000' flood-opacity='0.10'/></filter>

  <marker id='m_sw' viewBox='0 0 10 10' refX='5' refY='5' markerWidth='6' markerHeight='6' orient='auto'>
    <path d='M 0 0 L 10 5 L 0 10 z' fill='$sw_color' />
  </marker>
  <marker id='m_lw' viewBox='0 0 10 10' refX='5' refY='5' markerWidth='6' markerHeight='6' orient='auto'>
    <path d='M 0 0 L 10 5 L 0 10 z' fill='$lw_color' />
  </marker>
  <marker id='m_sens' viewBox='0 0 10 10' refX='5' refY='5' markerWidth='6' markerHeight='6' orient='auto'>
    <path d='M 0 0 L 10 5 L 0 10 z' fill='$sens_color' />
  </marker>
  <marker id='m_lat' viewBox='0 0 10 10' refX='5' refY='5' markerWidth='6' markerHeight='6' orient='auto'>
    <path d='M 0 0 L 10 5 L 0 10 z' fill='$lat_color' />
  </marker>
</defs>
""")

# background
println(svg, "<rect width='100%' height='100%' fill='#ffffff'/>")

# atmosphere box
println(svg, "<g filter='url(#softShadow)'>")
println(svg, "  <rect x='$atm_x' y='$atm_y' rx='12' ry='12' width='$atm_w' height='$atm_h' fill='url(#atmGrad)' stroke='#9fb7cf' stroke-width='1.4'/>")
println(svg, "</g>")

# angled thin columns (subtle)
for i in 1:4
  c = col_polygon_coords(i)
  println(svg, "<polygon points='$(c[1]) $(c[2]), $(c[3]) $(c[4]), $(c[5]) $(c[6]), $(c[7]) $(c[8])' fill='#2f6c8a' fill-opacity='0.06' stroke='none'/>")
end

# convex-up surface
top_arc_depth = 40
left_top_x = surf_x; left_top_y = surf_y
right_top_x = surf_x + surf_w; right_top_y = surf_y
cx1 = surf_x + surf_w*0.25; cy1 = surf_y - top_arc_depth
cx2 = surf_x + surf_w*0.75; cy2 = surf_y - top_arc_depth
bottom_y = surf_y + surf_h
surface_path = "M $left_top_x $left_top_y C $cx1 $cy1, $cx2 $cy2, $right_top_x $right_top_y L $right_top_x $bottom_y L $left_top_x $bottom_y Z"
println(svg, "<g filter='url(#softShadow)'>")
println(svg, "  <path d=\"$surface_path\" fill='url(#surfGrad)' stroke='$surf_stroke' stroke-width='1.4'/>")
println(svg, "</g>")

# titles
println(svg, "<text x='$(atm_x + 16)' y='$(atm_y + 34)' font-family='Verdana, Arial, sans-serif' font-size='$title_fs' fill='$text_color'>Atmosphere</text>")
println(svg, "<text x='$(surf_x + 16)' y='$(surf_y + 36)' font-family='Verdana, Arial, sans-serif' font-size='$title_fs' fill='$text_color'>Surface</text>")

# arrow helper (vertical)
function vertical_arrow(buf, cx, y1, y2, col, w, markerid, label; dx=12, dy=-4, anchor="start")
  println(buf, "<line x1='$cx' y1='$y1' x2='$cx' y2='$y2' stroke='$col' stroke-width='$w' stroke-linecap='round' marker-end='url(#$markerid)'/>")
  ym = (y1 + y2)/2
  println(buf, "<text x='$(cx + dx)' y='$(ym + dy)' font-family='Verdana, Arial, sans-serif' font-size='$flux_fs' fill='$text_color' text-anchor='$anchor'>$label</text>")
end

# ---- Longwave pair (V-shaped) - left cluster (unchanged)
cx_lw_up = col_centers[1]
cx_lw_down = col_centers[2]
vertical_arrow(svg, cx_lw_up, y_lw_up_start, y_lw_up_end, lw_color, stroke_for(lw_up), "m_lw", "LW Up $(fmt(lw_up))"; dx=-14, anchor="end")
vertical_arrow(svg, cx_lw_down, y_lw_down_start, y_lw_down_end, lw_color, stroke_for(lw_down), "m_lw", "LW Down $(fmt(lw_down))"; dx=-14, anchor="end", dy=10)

# ---- Shortwave pair (moved far right; stronger surface overlap)
cx_sw_down = col_centers[3]
cx_sw_up   = col_centers[4]
vertical_arrow(svg, cx_sw_down, y_sw_top, y_sw_end, sw_color, stroke_for(sw_down), "m_sw", "SW Down $(fmt(sw_down))"; dx=12)
vertical_arrow(svg, cx_sw_up, y_ref_start, y_ref_end, sw_color, stroke_for(sw_ref; vmax=280), "m_sw", "Reflected $(fmt(sw_ref))"; dx=12)

# SW Absorbed label centered over stronger overlap region
mid_sw = (cx_sw_down + cx_sw_up)/2
println(svg, "<text x='$(mid_sw - 28)' y='$(y_sw_end + 14)' font-family='Verdana, Arial, sans-serif' font-size='$flux_fs' fill='$text_color' text-anchor='end'>SW Absorbed $(fmt(sw_abs))</text>")

# ---- Sensible & Latent: separated widely, short
# place sensible left-of-center, latent right-of-center but between clusters
sens_x = (col_centers[1] + col_centers[3]) * 0.48   # move slight left
lat_x  = (col_centers[1] + col_centers[3]) * 0.58   # move slight right
vertical_arrow(svg, sens_x, y_sens_start, y_sens_end, sens_color, stroke_for(h_val; vmax=60), "m_sens", "Sensible $(fmt(h_val))"; dx=12)
vertical_arrow(svg, lat_x + 12, y_lat_start, y_lat_end, lat_color, stroke_for(le_val; vmax=240), "m_lat", "Latent $(fmt(le_val))"; dx=12, dy=8)

# nets
println(svg, "<text x='$(W/2)' y='$(atm_y + 52)' font-family='Verdana, Arial, sans-serif' font-size='$title_fs' fill='$text_color' text-anchor='middle'>Atmosphere net = $(fmt(atm_net))</text>")
println(svg, "<text x='$(W/2)' y='$(H - 40)' font-family='Verdana, Arial, sans-serif' font-size='$title_fs' fill='$text_color' text-anchor='middle'>Surface net = $(fmt(surface_net))</text>")

# legend
leg_x = W - 300; leg_y = H - 200
println(svg, "<g>")
println(svg, "  <rect x='$leg_x' y='$leg_y' rx='8' ry='8' width='260' height='160' fill='#ffffff' stroke='#e6eef5'/>")
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

# timestamp
nowstr = Dates.format(now(), "yyyy-mm-dd HH:MM")
println(svg, "<text x='12' y='$(H - 12)' font-family='Verdana, Arial, sans-serif' font-size='$small_fs' fill='#666666'>Generated: $nowstr — trenberth_columns_v8 (random example)</text>")

println(svg, "</svg>")

# write
outname = "trenberth_columns_v8.svg"
open(outname,"w") do io
  write(io, String(take!(svg)))
end
println("Wrote $outname")

# try PNG
pngname = "trenberth_columns_v8.png"
try
  run(`rsvg-convert -o $pngname $outname`)
  println("Also wrote $pngname (via rsvg-convert)")
catch e
  println("rsvg-convert not available; SVG produced.")
end

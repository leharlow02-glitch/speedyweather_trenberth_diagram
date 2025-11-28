#!/usr/bin/env julia
# trenberth_columns_v16.jl
# Angled arrows, non-overlapping labels, OLR added, columns recoloured/bolder.
# Run: julia trenberth_columns_v16.jl

using Random, Dates, Printf

Random.seed!(1234)

perturb(base; frac=0.08) = base * (1 + (rand() - 0.5) * 2 * frac)

# fluxes
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
atm_net     = (lw_up + sw_ref) - (lw_down + sw_ref)  # visual placeholder

fmt(x) = @sprintf("%.1f W/m²", x)

# canvas/layout
W = 1400; H = 980; pad = 92
atm_x = pad; atm_y = 60; atm_w = W - 2*pad; atm_h = 560

# surface
surf_x = atm_x; surf_y = atm_y + atm_h; surf_w = atm_w; surf_h = 150

# columns (positions from last working layout)
thin_w = atm_w * 0.065
left_cluster_x = atm_x + 80 + 80 + 24
right_cluster_x = atm_x + atm_w - 80 - thin_w*2 - 10

col_bottom_x = [
  left_cluster_x,
  left_cluster_x + thin_w*0.9 + 6.0,
  right_cluster_x - 30.0,
  right_cluster_x + thin_w*0.9 + 6.0
]

slant_px = 84
col_top_x = [
  col_bottom_x[1] - slant_px,
  col_bottom_x[2] + slant_px,
  col_bottom_x[3] - (slant_px/6),
  col_bottom_x[4] + (slant_px/6)
]

function col_polygon_coords(i)
  bx = col_bottom_x[i]; tx = col_top_x[i]; w = thin_w
  x1 = tx; y1 = atm_y + 14
  x2 = tx + w; y2 = atm_y + 14
  x3 = bx + w; y3 = atm_y + atm_h - 14
  x4 = bx; y4 = atm_y + atm_h - 14
  return (x1,y1,x2,y2,x3,y3,x4,y4)
end
col_centers = [(col_top_x[i] + col_bottom_x[i] + thin_w)/2 for i in 1:4]

# colours
sw_color = "#D6A91E"   # darker yellow
sw_col_fill = "#F7E9B7"
lw_color = "#D94536"
lw_col_fill = "#FADBD7"
col_a_fill = "#E8F3EF" # for middle column backgrounds (sensible/latent column tone)
col_b_fill = "#E7F0FA"

sens_color = "#0F6B6B"
lat_color  = "#1F4FA3"
atm_grad_top = "#EAF6FF"; atm_grad_bot = "#DDEFF7"
surf_fill = "#F3FBF3"; surf_stroke = "#2E8A3B"
text_color = "#08121A"

title_fs = 24; flux_fs = 14; legend_fs = 14; small_fs = 11

# stroke helpers
function stroke_thin(val; vmin=0.0, vmax=450.0, wmin=2.0, wmax=12.0)
  t = clamp((val - vmin)/(vmax - vmin), 0.0, 1.0)
  return round(wmin + (wmax - wmin)*t, digits=2)
end

function stroke_med(val; vmin=0.0, vmax=450.0, wmin=6.0, wmax=20.0)
  t = clamp((val - vmin)/(vmax - vmin), 0.0, 1.0)
  return round(wmin + (wmax - wmin)*t, digits=2)
end

# vertical anchors
y_top = atm_y + 24
y_surface_pen = surf_y + 14

# arrow extents (SW/LW long, sensible/latent half height)
y_sw_top = y_top; y_sw_end = y_surface_pen
y_ref_start = y_surface_pen; y_ref_end = y_top

y_lw_down_start = y_top; y_lw_down_end = y_surface_pen
y_lw_up_start   = y_surface_pen; y_lw_up_end = y_top

# sensible/latent go upward to ~50% of atmosphere (slanted, shorter than LW/SW)
y_sens_start = y_surface_pen; y_sens_end = atm_y + atm_h * 0.50
y_lat_start  = y_surface_pen; y_lat_end  = atm_y + atm_h * 0.50

# build svg
svg = IOBuffer()
println(svg, "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>")
println(svg, "<svg xmlns='http://www.w3.org/2000/svg' width='$W' height='$H' viewBox='0 0 $W $H'>")

# defs: markers & gradients
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

  <!-- smaller arrowheads (thin shafts) -->
  <marker id='m_sw' viewBox='0 0 10 10' refX='5' refY='5' markerWidth='5' markerHeight='5' orient='auto'>
    <path d='M 0 0 L 10 5 L 0 10 z' fill='$sw_color' />
  </marker>

  <marker id='m_lw' viewBox='0 0 10 10' refX='5' refY='5' markerWidth='5' markerHeight='5' orient='auto'>
    <path d='M 0 0 L 10 5 L 0 10 z' fill='$lw_color' />
  </marker>

  <marker id='m_sens' viewBox='0 0 10 10' refX='5' refY='5' markerWidth='5' markerHeight='5' orient='auto'>
    <path d='M 0 0 L 10 5 L 0 10 z' fill='$sens_color' />
  </marker>

  <marker id='m_lat' viewBox='0 0 10 10' refX='5' refY='5' markerWidth='5' markerHeight='5' orient='auto'>
    <path d='M 0 0 L 10 5 L 0 10 z' fill='$lat_color' />
  </marker>
</defs>
""")

# background
println(svg, "<rect width='100%' height='100%' fill='white'/>")

# atmosphere box (rounded + shadow)
println(svg, "<g>")
println(svg, "  <rect x='$atm_x' y='$atm_y' rx='12' ry='12' width='$atm_w' height='$atm_h' fill='url(#atmGrad)' stroke='#9fb7cf' stroke-width='1.8'/>")
println(svg, "</g>")

# lapse ticks (left)
tick_x = atm_x + 24; tick_len = 12; n_ticks = 7
for k in 1:n_ticks
  yy = atm_y + 24 + (k-1)*(atm_h - 48)/(n_ticks-1)
  println(svg, "<line x1='$(tick_x)' y1='$yy' x2='$(tick_x + tick_len)' y2='$yy' stroke='#6b7f88' stroke-width='1' stroke-dasharray='2,3'/>")
end
println(svg, "<text x='$(tick_x + tick_len + 8)' y='$(atm_y + 20)' font-family='Verdana' font-size='12' fill='#6b7f88'>Lapse-rate guide</text>")

# column polygons with different fills & bolder stroke
for i in 1:4
  bx = col_bottom_x[i]; tx = col_top_x[i]; w = thin_w
  x1 = tx; y1 = atm_y + 14
  x2 = tx + w; y2 = atm_y + 14
  x3 = bx + w; y3 = atm_y + atm_h - 14
  x4 = bx; y4 = atm_y + atm_h - 14

  # pick colours for columns: LW up/down = lw_col_fill, SW down/up = sw_col_fill
  fillcol = i <= 2 ? lw_col_fill : sw_col_fill
  strokecol = i <=2 ? "#d66a60" : "#caa33a"
  strokew = 2.4
  println(svg, "<polygon points='$(x1) $(y1), $(x2) $(y2), $(x3) $(y3), $(x4) $(y4)' fill='$fillcol' stroke='$strokecol' stroke-width='$strokew' fill-opacity='0.9'/>")
end

# convex-up surface path
top_arc_depth = 46
left_top_x = surf_x; left_top_y = surf_y
right_top_x = surf_x + surf_w; right_top_y = surf_y
cx1 = surf_x + surf_w*0.25; cy1 = surf_y - top_arc_depth
cx2 = surf_x + surf_w*0.75; cy2 = surf_y - top_arc_depth
bottom_y = surf_y + surf_h
surface_path = "M $left_top_x $left_top_y C $cx1 $cy1, $cx2 $cy2, $right_top_x $right_top_y L $right_top_x $bottom_y L $left_top_x $bottom_y Z"
println(svg, "<path d=\"$surface_path\" fill='$surf_fill' stroke='$surf_stroke' stroke-width='1.6'/>")

# titles
println(svg, "<text x='$(atm_x + 18)' y='$(atm_y + 40)' font-family='Verdana' font-size='$title_fs' fill='$text_color'>Atmosphere</text>")
println(svg, "<text x='$(surf_x + 18)' y='$(surf_y + 44)' font-family='Verdana' font-size='$title_fs' fill='$text_color'>Surface</text>")

# helper: slanted arrow (x1,y1 -> x2,y2) with label near tip; marker orient='auto' rotates head
function slanted_arrow(buf, x1, y1, x2, y2, col, w, markerid, label; label_dx=8, label_dy=-8, anchor="start")
  println(buf, "<line x1='$x1' y1='$y1' x2='$x2' y2='$y2' stroke='$col' stroke-width='$w' stroke-linecap='round' marker-end='url(#$markerid)'/>")
  # place label a little offset from tip (x2,y2)
  lx = clamp(x2 + label_dx, atm_x + 12, atm_x + atm_w - 12)
  ly = clamp(y2 + label_dy, atm_y + 8, atm_y + atm_h - 8)
  println(buf, "<text x='$lx' y='$ly' font-family='Verdana' font-size='$flux_fs' fill='$text_color' text-anchor='$anchor'>$label</text>")
end

# --- arrows: compute endpoints angled toward roughly same top y positions ---
# choose small horizontal offsets so arrows sit visually inside columns
# LW Up (col 1): arrow from surface up to near-top, slanted slightly rightwards
cx1_bot = col_bottom_x[1] + thin_w*0.5
cx1_top = col_top_x[1] + thin_w*0.6
slant_offset = 8
slanted_top_y = y_top + 4

slanted_arrow(svg, cx1_bot, y_lw_up_start, cx1_top + slant_offset, y_lw_up_end - 2, lw_color, stroke_thin(lw_up), "m_lw", "LW Up $(fmt(lw_up))"; label_dx=-46, label_dy=-6, anchor="end")

# LW Down (col 2): arrow from top down to surface, slanted slightly leftwards
cx2_top = col_top_x[2] + thin_w*0.5
cx2_bot = col_bottom_x[2] + thin_w*0.5
slanted_arrow(svg, cx2_top - slant_offset, y_lw_down_start + 4, cx2_bot - 4, y_lw_down_end, lw_color, stroke_thin(lw_down), "m_lw", "LW Down $(fmt(lw_down))"; label_dx=-46, label_dy=12, anchor="end")

# add OLR at top of LW Up column (slightly left of the LW Up head)
olr_label_x = cx1_top + slant_offset - 6
olr_label_y = y_top - 8
println(svg, "<text x='$olr_label_x' y='$olr_label_y' font-family='Verdana' font-size='$flux_fs' fill='$text_color' text-anchor='end'>OLR $(fmt( (lw_up + 0.0)/1.7 ))</text>") 
# NOTE: OLR value here is illustrative — using a rough relation to lw_up for the visual example.

# SW Down (col 3): surface-directed arrow (top -> surface), slanted slightly leftwards
cx3_top = col_top_x[3] + thin_w*0.5
cx3_bot = col_bottom_x[3] + thin_w*0.6
slanted_arrow(svg, cx3_top - 6, y_sw_top, cx3_bot - 12, y_sw_end, sw_color, stroke_thin(sw_down), "m_sw", "SW Down $(fmt(sw_down))"; label_dx=10, label_dy=2, anchor="start")

# SW Reflected (col 4): surface -> top (slanted slightly rightwards)
cx4_bot = col_bottom_x[4] + thin_w*0.5
cx4_top = col_top_x[4] + thin_w*0.5
slanted_arrow(svg, cx4_bot + 2, y_ref_start, cx4_top + 6, y_ref_end - 2, sw_color, stroke_thin(sw_ref; vmax=280), "m_sw", "Reflected $(fmt(sw_ref))"; label_dx=10, label_dy=-6, anchor="start")

# Sensible (between columns): slanted upward to ~half height (shorter), teal
sens_x_bot = (col_bottom_x[1] + col_bottom_x[3]) * 0.44
sens_x_top = sens_x_bot + 2
slanted_arrow(svg, sens_x_bot, y_sens_start, sens_x_top - 4, y_sens_end, sens_color, 8.0, "m_sens", "Sensible $(fmt(h_val))"; label_dx=8, label_dy=-6)

# Latent (next to sensible): slanted upward to ~half height (shorter), blue
lat_x_bot = (col_bottom_x[1] + col_bottom_x[3]) * 0.66
lat_x_top = lat_x_bot - 2
slanted_arrow(svg, lat_x_bot, y_lat_start, lat_x_top + 4, y_lat_end, lat_color, 8.0, "m_lat", "Latent $(fmt(le_val))"; label_dx=10, label_dy=-6)

# SW absorbed label centered, nudged down a bit so no overlap
mid_sw = ( (col_bottom_x[3] + col_bottom_x[4])/2 )
sw_label_x = clamp(mid_sw - 24, atm_x + 40, atm_x + atm_w - 120)
println(svg, "<text x='$sw_label_x' y='$(y_sw_end + 22)' font-family='Verdana' font-size='$flux_fs' fill='$text_color' text-anchor='end'>SW Absorbed $(fmt(sw_abs))</text>")

# nets & timestamp
println(svg, "<text x='$(W/2)' y='$(atm_y + 60)' font-family='Verdana' font-size='22' fill='$text_color' text-anchor='middle'>Atmosphere net = $(fmt(atm_net))</text>")
println(svg, "<text x='$(W/2)' y='$(H - 44)' font-family='Verdana' font-size='22' fill='$text_color' text-anchor='middle'>Surface net = $(fmt(surface_net))</text>")

# legend (unchanged)
leg_x = W - 360; leg_y = H - 220
println(svg, "<g>")
println(svg, "  <rect x='$leg_x' y='$leg_y' rx='8' ry='8' width='300' height='160' fill='#ffffff' stroke='#e6eef5'/>")
println(svg, "  <text x='$(leg_x + 18)' y='$(leg_y + 36)' font-family='Verdana' font-size='$legend_fs' fill='$text_color'>Legend</text>")
println(svg, "  <line x1='$(leg_x + 18)' y1='$(leg_y + 70)' x2='$(leg_x + 98)' y2='$(leg_y + 70)' stroke='$sw_color' stroke-width='12' stroke-linecap='round'/>")
println(svg, "  <text x='$(leg_x + 118)' y='$(leg_y + 74)' font-family='Verdana' font-size='$legend_fs' fill='$text_color'>Shortwave</text>")
println(svg, "  <line x1='$(leg_x + 18)' y1='$(leg_y + 106)' x2='$(leg_x + 98)' y2='$(leg_y + 106)' stroke='$lw_color' stroke-width='12' stroke-linecap='round'/>")
println(svg, "  <text x='$(leg_x + 118)' y='$(leg_y + 110)' font-family='Verdana' font-size='$legend_fs' fill='$text_color'>Longwave</text>")
println(svg, "  <line x1='$(leg_x + 18)' y1='$(leg_y + 142)' x2='$(leg_x + 98)' y2='$(leg_y + 142)' stroke='$sens_color' stroke-width='10' stroke-dasharray='8,6' stroke-linecap='round'/>")
println(svg, "  <text x='$(leg_x + 118)' y='$(leg_y + 146)' font-family='Verdana' font-size='$legend_fs' fill='$text_color'>Sensible (teal)</text>")
println(svg, "  <line x1='$(leg_x + 18)' y1='$(leg_y + 174)' x2='$(leg_x + 98)' y2='$(leg_y + 174)' stroke='$lat_color' stroke-width='10' stroke-dasharray='8,6' stroke-linecap='round'/>")
println(svg, "  <text x='$(leg_x + 118)' y='$(leg_y + 178)' font-family='Verdana' font-size='$legend_fs' fill='$text_color'>Latent (blue)</text>")
println(svg, "</g>")

nowstr = Dates.format(now(), "yyyy-mm-dd HH:MM")
println(svg, "<text x='14' y='$(H - 16)' font-family='Verdana' font-size='$small_fs' fill='#666666'>Generated: $nowstr — trenberth_columns_v16 (random example)</text>")

println(svg, "</svg>")

# write
outname = "trenberth_columns_v16.svg"
open(outname,"w") do io
  write(io, String(take!(svg)))
end
println("Wrote $outname")

# try PNG via rsvg-convert
pngname = "trenberth_columns_v16.png"
try
  run(`rsvg-convert -o $pngname $outname`)
  println("Also wrote $pngname (via rsvg-convert)")
catch e
  println("rsvg-convert not available; SVG produced.")
end

#!/usr/bin/env julia
# trenberth_columns_v14.jl
# Focused: make LW arrows *longer* (match SW extents), ensure LW Down is a real arrow with shaft,
# shorten sensible/latent and place their labels at the tip (label at tip).
# Run: julia trenberth_columns_v14.jl

using Random, Dates, Printf

Random.seed!(1234)

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
atm_net     = (lw_up + sw_ref) - (lw_down + sw_ref)

fmt(x) = @sprintf("%.1f W/m²", x)

# Canvas & layout (based on v13/v12)
W = 1400; H = 980; pad = 92
atm_x = pad; atm_y = 60; atm_w = W - 2*pad; atm_h = 560

# surface convex-up
surf_x = atm_x; surf_y = atm_y + atm_h; surf_w = atm_w; surf_h = 150

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

# colours & fonts
sw_color = "#F2C94C"; lw_color = "#E94B3C"
sens_color = "#0F6B6B"; lat_color  = "#1F4FA3"
atm_grad_top = "#EAF6FF"; atm_grad_bot = "#DDEFF7"
surf_fill = "#F3FBF3"; surf_stroke = "#2E8A3B"; text_color = "#08121A"

title_fs = 24; flux_fs = 14; legend_fs = 14; small_fs = 11

function stroke_for(val; vmin=0.0, vmax=450.0, wmin=5.0, wmax=36.0)
  t = clamp((val - vmin)/(vmax - vmin), 0.0, 1.0)
  return round(wmin + (wmax - wmin)*t, digits=2)
end

# vertical anchors
y_top = atm_y + 24
y_surface_pen = surf_y + 14

# --- KEY: Make LW arrows long (match SW) ---
# SW: top -> surface and surface -> top extents
y_sw_top = y_top
y_sw_end = y_surface_pen
y_ref_start = y_surface_pen
y_ref_end   = y_top

# Make LW Down go from top -> surface (full shaft). Make LW Up go from surface -> top.
y_lw_down_start = y_top          # start exactly at same top as SW (so they line up)
y_lw_down_end   = y_surface_pen  # down to surface (shaft visible)

y_lw_up_start = y_surface_pen
# extend LW Up to the same top as SW Reflected (avoid clipping by stopping a few px below y_top)
y_lw_up_end   = y_top + 0        # equal to SW top so visually matching

# Sensible & Latent: much shorter and labels positioned at the arrow tip
# Set them to only reach a small distance into the atmosphere (user requested much shorter)
y_sens_start = y_surface_pen
y_sens_end   = y_surface_pen + 28   # ~28 px above surface (tiny)
y_lat_start  = y_surface_pen
y_lat_end    = y_surface_pen + 48   # slightly higher than sensible but still small

# Compose SVG
svg = IOBuffer()
println(svg, "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>")
println(svg, "<svg xmlns='http://www.w3.org/2000/svg' width='$W' height='$H' viewBox='0 0 $W $H'>")

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
  <filter id="softShadow" x='-20%' y='-20%' width='140%' height='140%'><feDropShadow dx='0' dy='10' stdDeviation='14' flood-color='#000' flood-opacity='0.12'/></filter>

  <!-- normal-sized markers (no huge heads) -->
  <marker id='m_lw' viewBox='0 0 10 10' refX='5' refY='5' markerWidth='6' markerHeight='6' orient='auto'>
    <path d='M 0 0 L 10 5 L 0 10 z' fill='$lw_color' />
  </marker>

  <marker id='m_sw' viewBox='0 0 10 10' refX='5' refY='5' markerWidth='6' markerHeight='6' orient='auto'>
    <path d='M 0 0 L 10 5 L 0 10 z' fill='$sw_color' />
  </marker>

  <marker id='m_sens' viewBox='0 0 10 10' refX='5' refY='5' markerWidth='6' markerHeight='6' orient='auto'>
    <path d='M 0 0 L 10 5 L 0 10 z' fill='$sens_color' />
  </marker>

  <marker id='m_lat' viewBox='0 0 10 10' refX='5' refY='5' markerWidth='6' markerHeight='6' orient='auto'>
    <path d='M 0 0 L 10 5 L 0 10 z' fill='$lat_color' />
  </marker>
</defs>
""")

println(svg, "<rect width='100%' height='100%' fill='#ffffff'/>")

# atmosphere
println(svg, "<g filter='url(#softShadow)'>")
println(svg, "  <rect x='$atm_x' y='$atm_y' rx='12' ry='12' width='$atm_w' height='$atm_h' fill='url(#atmGrad)' stroke='#9fb7cf' stroke-width='1.6'/>")
println(svg, "</g>")

# lapse-rate ticks (left)
tick_x = atm_x + 24; tick_len = 12; n_ticks = 7
for k in 1:n_ticks
  yy = atm_y + 24 + (k-1)*(atm_h - 48)/(n_ticks-1)
  println(svg, "<line x1='$(tick_x)' y1='$yy' x2='$(tick_x + tick_len)' y2='$yy' stroke='#6b7f88' stroke-width='1' stroke-dasharray='2,3'/>")
end
println(svg, "<text x='$(tick_x + tick_len + 8)' y='$(atm_y + 20)' font-family='Verdana, Arial, sans-serif' font-size='12' fill='#6b7f88'>Lapse-rate guide</text>")

# columns (subtle backgrounds)
for i in 1:4
  bx = col_bottom_x[i]; tx = col_top_x[i]; w = thin_w
  x1 = tx; y1 = atm_y + 14
  x2 = tx + w; y2 = atm_y + 14
  x3 = bx + w; y3 = atm_y + atm_h - 14
  x4 = bx; y4 = atm_y + atm_h - 14
  println(svg, "<polygon points='$(x1) $(y1), $(x2) $(y2), $(x3) $(y3), $(x4) $(y4)' fill='#2f6c8a' fill-opacity='0.06' stroke='none'/>")
end

# convex-up surface
top_arc_depth = 46
left_top_x = surf_x; left_top_y = surf_y
right_top_x = surf_x + surf_w; right_top_y = surf_y
cx1 = surf_x + surf_w*0.25; cy1 = surf_y - top_arc_depth
cx2 = surf_x + surf_w*0.75; cy2 = surf_y - top_arc_depth
bottom_y = surf_y + surf_h
surface_path = "M $left_top_x $left_top_y C $cx1 $cy1, $cx2 $cy2, $right_top_x $right_top_y L $right_top_x $bottom_y L $left_top_x $bottom_y Z"
println(svg, "<g filter='url(#softShadow)'>")
println(svg, "  <path d=\"$surface_path\" fill='url(#surfGrad)' stroke='$surf_stroke' stroke-width='1.6'/>")
println(svg, "</g>")

# titles
println(svg, "<text x='$(atm_x + 18)' y='$(atm_y + 40)' font-family='Verdana, Arial, sans-serif' font-size='$title_fs' fill='$text_color'>Atmosphere</text>")
println(svg, "<text x='$(surf_x + 18)' y='$(surf_y + 44)' font-family='Verdana, Arial, sans-serif' font-size='$title_fs' fill='$text_color'>Surface</text>")

# helper: vertical arrow that can place label at mid or tip
function vertical_arrow(buf, cx, y1, y2, col, w, markerid, label; dx=14, dy=-6, anchor="start", label_at_tip=false)
  # draw shaft + arrowhead
  println(buf, "<line x1='$cx' y1='$y1' x2='$cx' y2='$y2' stroke='$col' stroke-width='$w' stroke-linecap='round' marker-end='url(#$markerid)'/>")
  # label position
  if label_at_tip
    # put label near tip: a few px above tip for upward arrows, a few px below for downward arrows
    if y2 < y1
      # arrow going up (y2 smaller than y1), label slightly above tip
      ly = y2 - 6
    else
      # arrow going down, label slightly below tip
      ly = y2 + 12
    end
    tx = clamp(cx + dx, atm_x + 8, atm_x + atm_w - 8)
    println(buf, "<text x='$tx' y='$(ly)' font-family='Verdana, Arial, sans-serif' font-size='$flux_fs' fill='$text_color' text-anchor='$anchor'>$label</text>")
  else
    ym = (y1 + y2)/2
    tx = clamp(cx + dx, atm_x + 8, atm_x + atm_w - 8)
    println(buf, "<text x='$tx' y='$(ym + dy)' font-family='Verdana, Arial, sans-serif' font-size='$flux_fs' fill='$text_color' text-anchor='$anchor'>$label</text>")
  end
end

# ---- LONGWAVE: now extend to match SW extents (longer shafts), normal-sized heads ----
cx_lw_down = col_centers[2]
vertical_arrow(svg, cx_lw_down, y_lw_down_start, y_lw_down_end, lw_color, stroke_for(lw_down), "m_lw", "LW Down $(fmt(lw_down))"; dx=-18, anchor="end", label_at_tip=true)

cx_lw_up = col_centers[1]
vertical_arrow(svg, cx_lw_up, y_lw_up_start, y_lw_up_end, lw_color, stroke_for(lw_up), "m_lw", "LW Up $(fmt(lw_up))"; dx=-18, anchor="end", label_at_tip=true)

# ---- SHORTWAVE (unchanged) ----
cx_sw_down = col_centers[3]; cx_sw_up = col_centers[4]
vertical_arrow(svg, cx_sw_down, y_sw_top, y_sw_end, sw_color, stroke_for(sw_down), "m_sw", "SW Down $(fmt(sw_down))"; dx=14, anchor="start")
vertical_arrow(svg, cx_sw_up, y_ref_start, y_ref_end, sw_color, stroke_for(sw_ref; vmax=280), "m_sw", "Reflected $(fmt(sw_ref))"; dx=14, anchor="start")

# SW Absorbed label (clamped)
mid_sw = (cx_sw_down + cx_sw_up)/2
sw_label_x = clamp(mid_sw - 40, atm_x + 40, atm_x + atm_w - 120)
println(svg, "<text x='$sw_label_x' y='$(y_sw_end + 18)' font-family='Verdana, Arial, sans-serif' font-size='$flux_fs' fill='$text_color' text-anchor='end'>SW Absorbed $(fmt(sw_abs))</text>")

# ---- SENSIBLE & LATENT: much shorter, label at tip ----
sens_x = (col_centers[1] + col_centers[3]) * 0.44
lat_x  = (col_centers[1] + col_centers[3]) * 0.66
vertical_arrow(svg, sens_x, y_sens_start, y_sens_end, sens_color, stroke_for(h_val; vmax=60), "m_sens", "Sensible $(fmt(h_val))"; dx=10, anchor="start", label_at_tip=true)
vertical_arrow(svg, lat_x, y_lat_start, y_lat_end, lat_color, stroke_for(le_val; vmax=240), "m_lat", "Latent $(fmt(le_val))"; dx=10, anchor="start", label_at_tip=true)

# nets
println(svg, "<text x='$(W/2)' y='$(atm_y + 60)' font-family='Verdana, Arial, sans-serif' font-size='22' fill='$text_color' text-anchor='middle'>Atmosphere net = $(fmt(atm_net))</text>")
println(svg, "<text x='$(W/2)' y='$(H - 44)' font-family='Verdana, Arial, sans-serif' font-size='22' fill='$text_color' text-anchor='middle'>Surface net = $(fmt(surface_net))</text>")

# legend
leg_x = W - 360; leg_y = H - 220
println(svg, "<g>")
println(svg, "  <rect x='$leg_x' y='$leg_y' rx='8' ry='8' width='300' height='160' fill='#ffffff' stroke='#e6eef5'/>")
println(svg, "  <text x='$(leg_x + 18)' y='$(leg_y + 36)' font-family='Verdana, Arial, sans-serif' font-size='$legend_fs' fill='$text_color'>Legend</text>")
println(svg, "  <line x1='$(leg_x + 18)' y1='$(leg_y + 70)' x2='$(leg_x + 98)' y2='$(leg_y + 70)' stroke='$sw_color' stroke-width='12' stroke-linecap='round'/>")
println(svg, "  <text x='$(leg_x + 118)' y='$(leg_y + 74)' font-family='Verdana, Arial, sans-serif' font-size='$legend_fs' fill='$text_color'>Shortwave</text>")
println(svg, "  <line x1='$(leg_x + 18)' y1='$(leg_y + 106)' x2='$(leg_x + 98)' y2='$(leg_y + 106)' stroke='$lw_color' stroke-width='12' stroke-linecap='round'/>")
println(svg, "  <text x='$(leg_x + 118)' y='$(leg_y + 110)' font-family='Verdana, Arial, sans-serif' font-size='$legend_fs' fill='$text_color'>Longwave</text>")
println(svg, "  <line x1='$(leg_x + 18)' y1='$(leg_y + 142)' x2='$(leg_x + 98)' y2='$(leg_y + 142)' stroke='$sens_color' stroke-width='10' stroke-dasharray='8,6' stroke-linecap='round'/>")
println(svg, "  <text x='$(leg_x + 118)' y='$(leg_y + 146)' font-family='Verdana, Arial, sans-serif' font-size='$legend_fs' fill='$text_color'>Sensible (teal)</text>")
println(svg, "  <line x1='$(leg_x + 18)' y1='$(leg_y + 174)' x2='$(leg_x + 98)' y2='$(leg_y + 174)' stroke='$lat_color' stroke-width='10' stroke-dasharray='8,6' stroke-linecap='round'/>")
println(svg, "  <text x='$(leg_x + 118)' y='$(leg_y + 178)' font-family='Verdana, Arial, sans-serif' font-size='$legend_fs' fill='$text_color'>Latent (blue)</text>")
println(svg, "</g>")

nowstr = Dates.format(now(), "yyyy-mm-dd HH:MM")
println(svg, "<text x='14' y='$(H - 16)' font-family='Verdana, Arial, sans-serif' font-size='$small_fs' fill='#666666'>Generated: $nowstr — trenberth_columns_v14 (random example)</text>")

println(svg, "</svg>")

# write out
outname = "trenberth_columns_v14.svg"
open(outname,"w") do io
  write(io, String(take!(svg)))
end
println("Wrote $outname")

# try png
pngname = "trenberth_columns_v14.png"
try
  run(`rsvg-convert -o $pngname $outname`)
  println("Also wrote $pngname (via rsvg-convert)")
catch e
  println("rsvg-convert not available; SVG produced.")
end

#!/usr/bin/env julia
# trenberth_cairomakie_anim_final.jl
# Clean CairoMakie animation of Trenberth diagram (patched + length mapping + stable surface)

using CairoMakie, Colors, CSV, DataFrames, Dates, Printf, Statistics
import Printf: @sprintf

fmt(x) = @sprintf("%.1f W/m²", x)

function map_stroke(val, vmin, vmax, smin, smax)
    t = isnan(val) ? 0.0 : clamp((val - vmin) / max(eps(), vmax - vmin), 0.0, 1.0)
    return smin + t * (smax - smin)
end

# improved arrow drawing: shaft stops short so head remains visible when shaft thick
# Replacement draw_arrow! — prevents shaft covering the head and makes head visible.
function draw_arrow!(ax, x1, y1, x2, y2;
        color=parse(Colorant, "#000000"),
        linewidth=4.0,
        headsize=10.0,
        head_ratio = 1.0)
    dx = x2 - x1; dy = y2 - y1
    L = hypot(dx, dy)
    if L < 1e-6 return end
    ux, uy = dx / L, dy / L
    # make head scale with linewidth so it stays visible
    headsize_eff = max(headsize, linewidth * 1.6)
    # compute head_space and clamp so the head has room
    head_space = clamp(headsize_eff * 1.05, linewidth*1.4, L*0.8) * head_ratio
    sx = x2 - ux * head_space
    sy = y2 - uy * head_space

    # draw shaft (butt cap so it does not overhang)
    lines!(ax, [x1, sx], [y1, sy], linewidth=linewidth, color=color, linecap=:butt)

    # draw triangular head on top, a little wider so it protrudes
    px, py = -uy, ux
    tipx, tipy = x2, y2
    b1x = tipx - headsize_eff * (ux + 0.32 * px); b1y = tipy - headsize_eff * (uy + 0.32 * py)
    b2x = tipx - headsize_eff * (ux - 0.32 * px); b2y = tipy - headsize_eff * (uy - 0.32 * py)
    poly!(ax, [tipx, b1x, b2x], [tipy, b1y, b2y], color=color)
end

# cubic bezier sampler used to make the curved surface
function bezier_cubic(p0, p1, p2, p3, n=64)
    xs = Vector{Float64}(undef, n)
    ys = Vector{Float64}(undef, n)
    idx = 1
    for t in range(0, 1, length=n)
        x = (1-t)^3*p0[1] + 3*(1-t)^2*t*p1[1] + 3*(1-t)*t^2*p2[1] + t^3*p3[1]
        y = (1-t)^3*p0[2] + 3*(1-t)^2*t*p1[2] + 3*(1-t)*t^2*p2[2] + t^3*p3[2]
        xs[idx] = x; ys[idx] = y; idx += 1
    end
    return xs, ys
end

# -----------------------------
# Load CSV or create demo
# -----------------------------
csvfile = length(ARGS) >= 1 ? ARGS[1] : nothing

if csvfile !== nothing && isfile(csvfile)
    df = CSV.read(csvfile, DataFrame)
    required = [:sw_down, :sw_ref, :lw_up, :lw_down, :sensible, :latent]
    for c in required
        if !(c in names(df)); error("CSV missing column: $c"); end
    end
else
    n = 20
    times = [DateTime(2025,1,1) + Hour(i) for i in 0:n-1]
    base = (sw_down=340.0, sw_ref=100.0, lw_up=396.0, lw_down=340.0, sensible=17.0, latent=80.0)
    df = DataFrame(time=times,
        sw_down = [base.sw_down + 10*sin(2π*(i)/n) for i in 0:n-1],
        sw_ref  = [base.sw_ref  + 8*cos(2π*(i)/n)  for i in 0:n-1],
        lw_up   = [base.lw_up   + 6*sin(2π*(i+3)/n) for i in 0:n-1],
        lw_down = [base.lw_down + 5*cos(2π*(i+5)/n) for i in 0:n-1],
        sensible= [max(1.0, base.sensible + 6*sin(2π*(i+1)/n)) for i in 0:n-1],
        latent  = [max(1.0, base.latent + 30*cos(2π*(i+2)/n)) for i in 0:n-1]
    )
end

nframes = nrow(df)
println("Frames: $nframes")

# -----------------------------
# Stroke scaling ranges
# -----------------------------
sw_vmin, sw_vmax = extrema(df.sw_down)
swr_vmin, swr_vmax = extrema(df.sw_ref)
lw_vmin, lw_vmax = extrema(df.lw_up)
lwd_vmin, lwd_vmax = extrema(df.lw_down)
sens_vmin, sens_vmax = extrema(df.sensible)
lat_vmin, lat_vmax = extrema(df.latent)

fixrange!(a, b) = (a == b ? (a-1, b+1) : (a, b))
sw_vmin, sw_vmax = fixrange!(sw_vmin, sw_vmax)
swr_vmin, swr_vmax = fixrange!(swr_vmin, swr_vmax)
lw_vmin, lw_vmax = fixrange!(lw_vmin, lw_vmax)
lwd_vmin, lwd_vmax = fixrange!(lwd_vmin, lwd_vmax)
sens_vmin, sens_vmax = fixrange!(sens_vmin, sens_vmax)
lat_vmin, lat_vmax = fixrange!(lat_vmin, lat_vmax)

min_radiative = 2.0; max_radiative = 12.0
min_sens = 3.0; max_sens = 10.0
min_lat = 3.0; max_lat = 12.0

# -----------------------------
# Layout
# -----------------------------
W, H = 1400, 980
pad = 92
atm_x, atm_y, atm_w, atm_h = pad, 60, W - 2*pad, 560
surf_x, surf_y, surf_w, surf_h = atm_x, atm_y + atm_h, atm_w, 150
thin_w = atm_w * 0.065

left_cluster_x = atm_x + 80 + 80 + 24
right_cluster_x = atm_x + atm_w - 80 - thin_w*2 - 10

col_bottom_x = Float64[
  left_cluster_x,
  left_cluster_x + thin_w*0.9 + 6.0,
  right_cluster_x - 30.0,
  right_cluster_x + thin_w*0.9 + 6.0
]
slant_px = 84
col_top_x = Float64[
  col_bottom_x[1] - slant_px,
  col_bottom_x[2] + slant_px,
  col_bottom_x[3] - (slant_px/6),
  col_bottom_x[4] + (slant_px/6)
]

# vertical anchors (static baseline, endpoints will be mapped)
y_surface_pen = surf_y + 14
y_down_start = atm_y + Int(round(atm_h*0.42))
y_up_start   = y_surface_pen

# -----------------------------
# Colors
# -----------------------------
sw_col = parse(Colorant, "#D6A91E")
lw_col = parse(Colorant, "#D94536")
sens_col = parse(Colorant, "#0F6B6B")
lat_col = parse(Colorant, "#1F4FA3")
col_fill_lw = parse(Colorant, "#FADBD7")
col_fill_sw = parse(Colorant, "#F7E9B7")
col_stroke_lw = parse(Colorant, "#d66a60")
col_stroke_sw = parse(Colorant, "#caa33a")
atm_fill = parse(Colorant, "#DDEFF7")
surf_fill = parse(Colorant, "#F3FBF3")
surf_stroke = parse(Colorant, "#2E8A3B")
textcol = parse(Colorant, "#08121A")

# -----------------------------
# Mapping functions for arrow lengths
# -----------------------------
# bottom (surface) y is y_surface_pen; topmost allowed is atm_y + 20
top_limit = atm_y + 20
mid_limit = atm_y + Int(round(atm_h * 0.30))  # mid-high for radiative
short_limit = atm_y + Int(round(atm_h * 0.50)) # for turbulent max

function map_rad_length(val, vmin, vmax)
    t = clamp((val - vmin) / max(eps(), vmax - vmin), 0.0, 1.0)
    # invert so larger flux -> smaller y (higher drawing)
    return round(Int, y_surface_pen - (y_surface_pen - mid_limit) * t - 2)
end

function map_rad_length_long(val, vmin, vmax)
    t = clamp((val - vmin) / max(eps(), vmax - vmin), 0.0, 1.0)
    return round(Int, y_surface_pen - (y_surface_pen - top_limit) * t - 2)
end

function map_turb_length(val, vmin, vmax)
    t = clamp((val - vmin) / max(eps(), vmax - vmin), 0.0, 1.0)
    # keep turbulent shorter (only rise a little)
    return round(Int, y_surface_pen - (y_surface_pen - short_limit) * 0.5 * t - 2)
end

# -----------------------------
# Make figure/axis once (we create new figure per frame later for robust saving)
# -----------------------------
# (we will not reuse this axis; draw_on_axis! draws into passed axis)

# -----------------------------
# Draw one frame into provided axis
# -----------------------------
function draw_on_axis!(ax, i)
    # atmosphere rectangle
    poly!(ax, [atm_x, atm_x+atm_w, atm_x+atm_w, atm_x],
              [atm_y, atm_y, atm_y+atm_h, atm_y+atm_h],
              color=atm_fill, strokecolor=parse(Colorant,"#9fb7cf"), strokewidth=1.8)

    # ticks (lapse-rate guide)
    tick_x, tick_len, n_ticks = atm_x+24, 12, 7
    for k in 1:n_ticks
        yy = atm_y + 24 + (k-1)*(atm_h-48)/(n_ticks-1)
        lines!(ax, [tick_x,tick_x+tick_len],[yy,yy], color=parse(Colorant,"#6b7f88"), linewidth=1, linestyle=:dash)
    end
    text!(ax, "Lapse-rate guide", position=(tick_x+tick_len+8, atm_y+20), align=(:left,:center), color=parse(Colorant,"#6b7f88"), fontsize=12)

    # columns
    for j in 1:4
        bx, tx = col_bottom_x[j], col_top_x[j]; w = thin_w
        x1,y1 = tx, atm_y+14; x2,y2 = tx+w, atm_y+14
        x3,y3 = bx+w, atm_y+atm_h-14; x4,y4 = bx, atm_y+atm_h-14
        fillcol = j ≤ 2 ? col_fill_lw : col_fill_sw
        strokecol = j ≤ 2 ? col_stroke_lw : col_stroke_sw
        poly!(ax,[x1,x2,x3,x4],[y1,y2,y3,y4], color=fillcol, strokecolor=strokecol, strokewidth=2.4)
    end

    # surface bezier + close polygon to explicit bottom_y (avoid any clipping)
    left_top_x, left_top_y = surf_x, surf_y
    right_top_x, right_top_y = surf_x + surf_w, surf_y
    cx1, cy1 = surf_x + surf_w * 0.25, surf_y - 46
    cx2, cy2 = surf_x + surf_w * 0.75, surf_y - 46
    xs, ys = bezier_cubic((left_top_x,left_top_y),(cx1,cy1),(cx2,cy2),(right_top_x,right_top_y),64)
    bottom_y = surf_y + surf_h
    xs2 = vcat(xs, [right_top_x, right_top_x, left_top_x, left_top_x])
    ys2 = vcat(ys, [right_top_y, bottom_y, bottom_y, left_top_y])
    poly!(ax, xs2, ys2, color=surf_fill, strokecolor=surf_stroke, strokewidth=1.6)

    # labels
    text!(ax,"Atmosphere",position=(atm_x+18,atm_y+40), align=(:left,:center),color=textcol,fontsize=22)
    text!(ax,"Surface",position=(surf_x+18,surf_y+44), align=(:left,:center),color=textcol,fontsize=22)

    # dynamic flux values
    row = df[i,:]
    sw_down = Float64(row[:sw_down]); sw_ref = Float64(row[:sw_ref])
    lw_up = Float64(row[:lw_up]); lw_down = Float64(row[:lw_down])
    sens = Float64(row[:sensible]); lat = Float64(row[:latent])
    tlabel = haskey(row,:time) ? string(row[:time]) : "t=$i"

    sw_stroke = map_stroke(sw_down, sw_vmin, sw_vmax, min_radiative, max_radiative)
    swref_stroke = map_stroke(sw_ref, swr_vmin, swr_vmax, min_radiative, max_radiative)
    lw_stroke = map_stroke(lw_up, lw_vmin, lw_vmax, min_radiative, max_radiative)
    lwd_stroke = map_stroke(lw_down, lwd_vmin, lwd_vmax, min_radiative, max_radiative)
    sens_stroke = map_stroke(sens, sens_vmin, sens_vmax, min_sens, max_sens)
    lat_stroke = map_stroke(lat, lat_vmin, lat_vmax, min_lat, max_lat)

    # compute dynamic endpoints (longer for radiative; shorter for turbulent)
    # === FIXED ENDPOINTS (only linewidth will vary) ===
    # Use constant drawing heights so arrows don't jump position between frames.
    # You can tweak the fractions (0.12, 0.45, 0.60) to move tips higher/lower.
    y_lw_up_top   = atm_y + Int(round(atm_h * 0.12))   # high endpoint for LW up
    y_lw_down_top = atm_y + Int(round(atm_h * 0.12))   # high start for LW down (we draw from this y to surface)
    y_sw_top      = atm_y + Int(round(atm_h * 0.15))   # high endpoint for SW down
    y_sw_ref_top  = atm_y + Int(round(atm_h * 0.15))   # high endpoint for SW reflected
    y_sens_top    = atm_y + Int(round(atm_h * 0.45))   # short endpoint for sensible (fixed)
    y_lat_top     = atm_y + Int(round(atm_h * 0.45))   # short endpoint for latent (fixed)
# === end fixed endpoints ===


    # slant offset and shaft positions
    s = 8.0

    # LW Up (col 1) - up from surface to y_lw_up_top
    cx1_bot = col_bottom_x[1] + thin_w*0.5
    cx1_top = col_top_x[1] + thin_w*0.6 + s
    draw_arrow!(ax, cx1_bot, y_up_start, cx1_top+s, y_lw_up_top, color=lw_col, linewidth=lw_stroke, headsize=10.0)
    text!(ax,"LW Up "*fmt(lw_up), position=(cx1_top+s-44,y_lw_up_top-6), align=(:right,:center), color=textcol, fontsize=13)

    # LW Down (col 2) - from top down to surface (drawn top->bot)
    cx2_top = col_top_x[2] + thin_w*0.5 - s
    cx2_bot = col_bottom_x[2] + thin_w*0.3 - s
    draw_arrow!(ax, cx2_top - s, y_lw_down_top, cx2_bot - 4, y_surface_pen, color=lw_col, linewidth=lwd_stroke, headsize=10.0)
    text!(ax,"LW Down "*fmt(lw_down), position=(cx2_bot-46,y_surface_pen+16), align=(:right,:center), color=textcol, fontsize=13)

    # SW Down (col 3) - top -> surface
    cx3_top = col_top_x[3] + thin_w*0.5 - 6
    cx3_bot = col_bottom_x[3] + thin_w*0.6 - 12
    draw_arrow!(ax, cx3_top - 6, y_sw_top, cx3_bot - 12, y_surface_pen+2, color=sw_col, linewidth=sw_stroke, headsize=10.0)
    text!(ax,"SW Absorbed "*fmt(sw_down-sw_ref), position=(cx3_bot-6,y_surface_pen+24), align=(:right,:center), color=textcol, fontsize=13)

    # SW Reflected (col 4) - surface -> top
    cx4_bot = col_bottom_x[4] + thin_w*0.5 + 6
    cx4_top = col_top_x[4] + thin_w*0.5 + 10
    draw_arrow!(ax, cx4_bot + 2, y_surface_pen, cx4_top + 6, y_sw_ref_top, color=sw_col, linewidth=swref_stroke, headsize=10.0)
    text!(ax,"Reflected "*fmt(sw_ref), position=(cx4_top+18,y_sw_ref_top-8), align=(:left,:center), color=textcol, fontsize=13)

    # Sensible (shorter)
    sens_x_bot = (col_bottom_x[1]+col_bottom_x[3])*0.44
    sens_x_top = sens_x_bot + 2
    draw_arrow!(ax, sens_x_bot, y_surface_pen, sens_x_top - 4, y_sens_top, color=sens_col, linewidth=sens_stroke, headsize=9.0)
    text!(ax,"Sensible "*fmt(sens), position=(sens_x_top+8,y_sens_top-8), align=(:left,:center), color=textcol, fontsize=13)

    # Latent (shorter)
    lat_x_bot = (col_bottom_x[1]+col_bottom_x[3])*0.66
    lat_x_top = lat_x_bot - 2
    draw_arrow!(ax, lat_x_bot, y_surface_pen, lat_x_top + 4, y_lat_top, color=lat_col, linewidth=lat_stroke, headsize=9.0)
    text!(ax,"Latent "*fmt(lat), position=(lat_x_top+8,y_lat_top-6), align=(:left,:center), color=textcol, fontsize=13)

    # frame label
    text!(ax, tlabel, position=(W-36, atm_y+36), align=(:right,:center), fontsize=14)
end

# -----------------------------
# Render PNG frames
# -----------------------------
frames_dir = "cairo_frames"
isdir(frames_dir) || mkpath(frames_dir)

png_pattern(i) = joinpath(frames_dir, lpad(string(i),4,'0')*".png")

println("Rendering $nframes PNG frames into $frames_dir ...")

for i in 1:nframes
    figf = Figure(size=(W,H), fontsize=14)
    axf = Axis(figf[1,1];
        limits=(0,W,0,H),
        yreversed=true,
        xticksvisible=false, yticksvisible=false,
        xticklabelsvisible=false, yticklabelsvisible=false,
        leftspinevisible=false, rightspinevisible=false,
        topspinevisible=false, bottomspinevisible=false,
        xgridvisible=false, ygridvisible=false
    )
    draw_on_axis!(axf, i)

    pngfile = png_pattern(i)
    save(pngfile, figf)
    figf = nothing
    GC.gc()

    if i % 10 == 0 || i == nframes
        println("  wrote frame $i / $nframes")
    end
end

# -----------------------------
# Stitch PNGs into GIF / MP4 (robust: no shell globbing, proper Cmd args)
# -----------------------------
gif_out = "trenberth_cairo_frames.gif"
mp4_out = "trenberth_cairo_frames.mp4"

# gather pngs (accept any .png in frames_dir)
all_pngs = readdir(frames_dir; join=true)
png_files = filter(p -> endswith(lowercase(p), ".png"), all_pngs)

if isempty(png_files)
    @error "No PNG frames found in $frames_dir; aborting stitch."
else
    function numeric_index_from_filename(p)
        b = basename(p)
        m = match(r"(\d+)(?=\.png$)", lowercase(b))
        return m === nothing ? nothing : parse(Int, m.captures[1])
    end

    files_meta = [(p, numeric_index_from_filename(p), stat(p).mtime) for p in png_files]
    use_numeric = any(x -> x[2] !== nothing, files_meta)
    sorted_files = use_numeric ? sort(files_meta, by = x -> (x[2] === nothing ? typemax(Int) : x[2])) :
                                  sort(files_meta, by = x -> x[3])
    png_files_sorted = [x[1] for x in sorted_files]

    println("Found $(length(png_files_sorted)) PNG(s) in $frames_dir; first/last 5 (or fewer):")
    for p in first(png_files_sorted, min(5,length(png_files_sorted)))
        println("  ", p)
    end
    if length(png_files_sorted) > 5
        println("  ...")
        for p in last(png_files_sorted, min(5,length(png_files_sorted)))
            println("  ", p)
        end
    end

    convert_path = Sys.which("convert"); magick_path = Sys.which("magick"); ffmpeg_path = Sys.which("ffmpeg")

    if convert_path !== nothing
        println("Using convert at: ", convert_path)
        try
            args = vcat([convert_path, "-delay", "12", "-loop", "0"], png_files_sorted, [gif_out])
            run(Cmd(args))
            println("Wrote $gif_out (via convert)")
        catch e
            @warn "convert failed: $e"
        end

    elseif magick_path !== nothing
        println("Using magick at: ", magick_path)
        try
            args = vcat([magick_path, "convert", "-delay", "12", "-loop", "0"], png_files_sorted, [gif_out])
            run(Cmd(args))
            println("Wrote $gif_out (via magick)")
        catch e
            @warn "magick convert failed: $e"
        end

    elseif ffmpeg_path !== nothing
        println("Using ffmpeg at: ", ffmpeg_path)
        try
            run(`$ffmpeg_path -y -framerate 8 -i $frames_dir/frame_%04d.png -c:v libx264 -pix_fmt yuv420p $mp4_out`)
            println("Wrote $mp4_out (via ffmpeg)")
        catch e
            @error "ffmpeg failed: $e"
        end

    else
        @error "No convert/magick/ffmpeg found on PATH. Install ImageMagick or ffmpeg."
    end
end

# last-frame copy
last_png = png_pattern(nframes)
if isfile(last_png)
    cp(last_png, "trenberth_cairo_lastframe.png"; force=true)
    println("Wrote trenberth_cairo_lastframe.png")
end

println("Frame-by-frame render complete.")

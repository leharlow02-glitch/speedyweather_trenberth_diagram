#!/usr/bin/env julia
# trenberth_interactive.jl
# Interactive GLMakie viewer for the Trenberth 3D animation.
using GLMakie, Colors, CSV, DataFrames, Dates, Printf, Observables

fmt(x) = @sprintf("%.1f W/m²", x)

# Map stroke widths to data values
function map_stroke(val, vmin, vmax, smin, smax)
    t = isnan(val) ? 0.0 : clamp((val - vmin) / max(eps(), vmax - vmin), 0.0, 1.0)
    return smin + t * (smax - smin)
end

# Draw beautiful 3D arrow with smooth cylinder and cone (reduced segments for interactivity)
function draw_arrow_3d!(ax, start, endpt, radius, color; segments=12)
    dir = endpt .- start
    length = norm(dir)
    if length < 1e-6 return end
    dir_normalized = dir ./ length
    shaft_length = length * 0.80
    shaft_end = start .+ dir_normalized .* shaft_length

    # perpendicular vectors
    if abs(dir_normalized[3]) < 0.9
        perp1 = cross(dir_normalized, [0, 0, 1])
    else
        perp1 = cross(dir_normalized, [1, 0, 0])
    end
    perp1 = perp1 ./ norm(perp1)
    perp2 = cross(dir_normalized, perp1)
    perp2 = perp2 ./ norm(perp2)

    theta = range(0, 2π, length=segments+1)

    # Shaft - draw as triangle strips (approx)
    for i in 1:segments
        p1 = start .+ radius .* (cos(theta[i]) .* perp1 .+ sin(theta[i]) .* perp2)
        p2 = start .+ radius .* (cos(theta[i+1]) .* perp1 .+ sin(theta[i+1]) .* perp2)
        p3 = shaft_end .+ radius .* (cos(theta[i+1]) .* perp1 .+ sin(theta[i+1]) .* perp2)
        p4 = shaft_end .+ radius .* (cos(theta[i]) .* perp1 .+ sin(theta[i]) .* perp2)
        mesh!(ax, [p1[1], p2[1], p3[1], p4[1]],
                  [p1[2], p2[2], p3[2], p4[2]],
                  [p1[3], p2[3], p3[3], p4[3]],
                  color=color, shading=true)
    end

    # Cap the shaft bottom
    for i in 1:segments
        p1 = start .+ radius .* (cos(theta[i]) .* perp1 .+ sin(theta[i]) .* perp2)
        p2 = start .+ radius .* (cos(theta[i+1]) .* perp1 .+ sin(theta[i+1]) .* perp2)
        mesh!(ax, [start[1], p1[1], p2[1]],
                  [start[2], p1[2], p2[2]],
                  [start[3], p1[3], p2[3]],
                  color=color, shading=true)
    end

    # Cone head
    cone_radius = radius * 2.4
    cone_base = [shaft_end .+ cone_radius .* (cos(t) .* perp1 .+ sin(t) .* perp2) for t in theta]
    for i in 1:segments
        p1 = cone_base[i]
        p2 = cone_base[i+1]
        mesh!(ax, [p1[1], p2[1], endpt[1]],
                  [p1[2], p2[2], endpt[2]],
                  [p1[3], p2[3], endpt[3]],
                  color=color, shading=true)
    end
    # Cap cone base
    for i in 1:segments
        p1 = cone_base[i]
        p2 = cone_base[i+1]
        mesh!(ax, [shaft_end[1], p1[1], p2[1]],
                  [shaft_end[2], p1[2], p2[2]],
                  [shaft_end[3], p1[3], p2[3]],
                  color=color, shading=true)
    end
end

# -----------------------------
# Load or create demo data
# -----------------------------
csvfile = length(ARGS) >= 1 ? ARGS[1] : nothing
if csvfile !== nothing && isfile(csvfile)
    df = CSV.read(csvfile, DataFrame)
    required = [:sw_down, :sw_ref, :lw_up, :lw_down, :sensible, :latent]
    for c in required
        if !(c in names(df)); error("CSV missing column: $c"); end
    end
else
    n = 50
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
    nframes = n
end
nframes = nrow(df)

# Calculate value ranges for scaling
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

min_radius = 0.10; max_radius = 0.35

# Colors
sw_col = colorant"#FFB84D"
lw_col = colorant"#FF6B6B"
sens_col = colorant"#4ECDC4"
lat_col = colorant"#5B7FFF"
atm_col = RGBA(0.85, 0.93, 0.98, 0.25)
surf_col = colorant"#8FBC8F"
grid_col = colorant"#B0C4DE"

# Scene geometry
surf_z = 0.0
atm_bottom = 0.0
atm_top = 6.0
atm_mid = 3.0
box_size = 5.0

# Derived geometry for surfaces
surf_points = 30
xs = range(-box_size, box_size, length=surf_points)
ys = range(-box_size, box_size, length=surf_points)
zs = [surf_z + 0.1*sin(x*0.5)*cos(y*0.5) for x in xs, y in ys]

# Interactive UI state
frame_idx = Observable(1)
playing = Observable(false)
fps = Observable(8.0)   # frames per second for play mode
segments_default = 12   # lower for interactive use

# Build figure with layout: big 3D + controls row
fig = Figure(resolution=(1100, 800), fontsize=14)
ax = Axis3(fig[1, 1], 
    aspect=(1, 1, 0.7),
    elevation=0.25,
    azimuth=2.2,
    xlabel="", ylabel="", zlabel="",
    xticksvisible=false, yticksvisible=false, zticksvisible=false,
    xticklabelsvisible=false, yticklabelsvisible=false, zticklabelsvisible=false,
    xgridvisible=false, ygridvisible=false, zgridvisible=false,
    xspinesvisible=false, yspinesvisible=false, zspinesvisible=false)

# draw static elements once into the axis (we will clear dynamic parts each frame)
function draw_static!(ax)
    # Atmosphere box wireframe
    box_x = [-box_size, box_size, box_size, -box_size, -box_size, box_size, box_size, -box_size]
    box_y = [-box_size, -box_size, box_size, box_size, -box_size, -box_size, box_size, box_size]
    box_z = [atm_bottom, atm_bottom, atm_bottom, atm_bottom, atm_top, atm_top, atm_top, atm_top]
    for i in 1:4
        next_i = (i % 4) + 1
        lines!(ax, [box_x[i], box_x[next_i]], [box_y[i], box_y[next_i]], [box_z[i], box_z[next_i]], 
               color=grid_col, linewidth=2.0, linestyle=:dash)
        lines!(ax, [box_x[i+4], box_x[next_i+4]], [box_y[i+4], box_y[next_i+4]], [box_z[i+4], box_z[next_i+4]], 
               color=grid_col, linewidth=2.0, linestyle=:dash)
        lines!(ax, [box_x[i], box_x[i+4]], [box_y[i], box_y[i+4]], [box_z[i], box_z[i+4]], 
               color=grid_col, linewidth=2.0, linestyle=:dash)
    end

    # soft atmosphere plane
    mesh!(ax, [-box_size, box_size, box_size, -box_size], 
          [-box_size, -box_size, box_size, box_size], 
          [atm_top, atm_top, atm_top, atm_top],
          color=atm_col, transparency=true)

    # surface
    surface!(ax, xs, ys, zs, color=surf_col, alpha=0.7, shading=true)

    for x in range(-box_size, box_size, length=6)
        lines!(ax, fill(x, surf_points), collect(ys), [surf_z for _ in ys],
               color=RGBA(0.4, 0.6, 0.4, 0.3), linewidth=1)
    end
    for y in range(-box_size, box_size, length=6)
        lines!(ax, collect(xs), fill(y, surf_points), [surf_z for _ in xs],
               color=RGBA(0.4, 0.6, 0.4, 0.3), linewidth=1)
    end

    text!(ax, "ATMOSPHERE", position=(0, 0, atm_top + 0.8), align=(:center, :center),
          fontsize=28, color=:black, font=:bold)
    text!(ax, "EARTH SURFACE", position=(0, 0, surf_z - 0.8), align=(:center, :center),
          fontsize=28, color=colorant"#2F5233", font=:bold)
end

draw_static!(ax)

# dynamic layer group (we clear this each frame)
dynamic_group = Node([])  # store nothing, used as marker

# function to draw/update dynamic arrows & labels for a given index
function draw_frame!(ax, idx)
    # remove previously drawn dynamic objects by clearing the axis and redrawing static,
    # but to keep UI responsive we remove everything and redraw static + dynamic.
    clear!(ax)  # clears whole axis; cheap enough for interactive sizes
    draw_static!(ax)

    row = df[idx, :]
    sw_d = map_stroke(row[:sw_down], sw_vmin, sw_vmax, min_radius, max_radius)
    sw_r = map_stroke(row[:sw_ref], swr_vmin, swr_vmax, min_radius, max_radius)
    lw_u = map_stroke(row[:lw_up], lw_vmin, lw_vmax, min_radius, max_radius)
    lw_d = map_stroke(row[:lw_down], lwd_vmin, lwd_vmax, min_radius, max_radius)
    sen = map_stroke(row[:sensible], sens_vmin, sens_vmax, min_radius*0.85, max_radius*0.85)
    la = map_stroke(row[:latent], lat_vmin, lat_vmax, min_radius*0.85, max_radius*0.85)

    offset = 2.2

    # arrows (use segments_default)
    draw_arrow_3d!(ax, [offset, offset, atm_top + 1.5], [offset, offset, surf_z + 0.3], sw_d, sw_col, segments=segments_default)
    text!(ax, "Incoming Solar\n" * fmt(row[:sw_down]), position=(offset + 0.8, offset + 0.3, atm_mid + 1.5),
          fontsize=14, color=:black, align=(:left, :center))

    draw_arrow_3d!(ax, [offset, -offset, surf_z + 0.3], [offset, -offset, atm_top + 1.5], sw_r, sw_col, segments=segments_default)
    text!(ax, "Reflected Solar\n" * fmt(row[:sw_ref]), position=(offset + 0.8, -offset - 0.3, atm_mid + 1.5),
          fontsize=14, color=:black, align=(:left, :center))

    draw_arrow_3d!(ax, [-offset, offset, surf_z + 0.3], [-offset, offset, atm_top + 1.5], lw_u, lw_col, segments=segments_default)
    text!(ax, "Thermal Up\n" * fmt(row[:lw_up]), position=(-offset - 0.8, offset + 0.3, atm_mid + 1.5),
          fontsize=14, color=:black, align=(:right, :center))

    draw_arrow_3d!(ax, [-offset, -offset, atm_top - 1.0], [-offset, -offset, surf_z + 0.3], lw_d, lw_col, segments=segments_default)
    text!(ax, "Back Radiation\n" * fmt(row[:lw_down]), position=(-offset - 0.8, -offset - 0.3, atm_mid - 0.5),
          fontsize=14, color=:black, align=(:right, :center))

    draw_arrow_3d!(ax, [0.3, 1.2, surf_z + 0.3], [0.3, 1.2, atm_mid - 0.5], sen, sens_col, segments=segments_default)
    text!(ax, "Sensible\n" * fmt(row[:sensible]), position=(0.8, 1.7, atm_mid/2 + 0.3),
          fontsize=13, color=:black, align=(:left, :center))

    draw_arrow_3d!(ax, [-0.3, -1.2, surf_z + 0.3], [-0.3, -1.2, atm_mid - 0.5], la, lat_col, segments=segments_default)
    text!(ax, "Latent\n" * fmt(row[:latent]), position=(-0.8, -1.7, atm_mid/2 + 0.3),
          fontsize=13, color=:black, align=(:right, :center))

    tlabel = haskey(row, :time) ? Dates.format(row[:time], "yyyy-mm-dd HH:MM") : "Frame $idx/$nframes"
    text!(ax, tlabel, position=(box_size - 1.2, box_size - 0.5, atm_top + 1.2), fontsize=14, color=:black, align=(:right, :top))

    net_surface = row[:sw_down] - row[:sw_ref] + row[:lw_down] - row[:lw_up] - row[:sensible] - row[:latent]
    balance_text = "Net Surface: " * fmt(net_surface)
    text!(ax, balance_text, position=(-box_size + 1.2, box_size - 0.5, atm_top + 1.2), fontsize=14, color=:black, align=(:left, :top))
end

# initially draw frame 1
draw_frame!(ax, 1)

# --- UI widgets --- (placed in row 2)
slider = Slider(fig[2, 1], range = 1:nframes, start = 1, showvalue=true)
playbtn = Button(fig[2, 2], label = "Play")
pausebtn = Button(fig[2, 3], label = "Pause")
backbtn = Button(fig[2, 4], label = "◀")
fwdbtn = Button(fig[2, 5], label = "▶")
speedslider = Slider(fig[2, 6], range = 1:1:30, start = round(Int, fps[]), showvalue=true)
label_speed = Label(fig[2,7], "FPS")

# wire slider to frame observable
on(slider.value) do v
    i = Int(round(v))
    frame_idx[] = i
    draw_frame!(ax, i)
end

# step buttons
on(backbtn.clicks) do _
    newi = clamp(frame_idx[] - 1, 1, nframes)
    slider.value[] = newi
end
on(fwdbtn.clicks) do _
    newi = clamp(frame_idx[] + 1, 1, nframes)
    slider.value[] = newi
end

# play / pause functionality using a Task
on(playbtn.clicks) do _
    playing[] = true
end
on(pausebtn.clicks) do _
    playing[] = false
end

# speed slider observable
on(speedslider.value) do v
    fps[] = float(v)
end

# reactive task that advances frames while playing==true
@async begin
    while isopen(fig.scene) # loop while window not closed
        if playing[]
            # advance one frame
            nexti = frame_idx[] == nframes ? 1 : frame_idx[] + 1
            slider.value[] = nexti  # triggers redraw through slider hook
            sleep(1.0 / max(0.1, fps[])) # prevent division by zero, limit max speed
        else
            sleep(0.05)
        end
    end
end

# show the figure/window
display(fig)

# Keep the Julia process alive until the window is closed
# (display(fig) does this for interactive sessions; the following ensures script won't exit immediately)
while isopen(fig.scene)
    sleep(0.2)
end
println("Window closed; exiting.")

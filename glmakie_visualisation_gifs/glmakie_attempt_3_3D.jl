#!/usr/bin/env julia
# trenberth_3d_glmakie_fixed3.jl
using GLMakie, Colors, CSV, DataFrames, Dates, Printf, Statistics, LinearAlgebra

fmt(x) = @sprintf("%.1f W/m²", x)

# Map stroke widths to data values
function map_stroke(val, vmin, vmax, smin, smax)
    t = isnan(val) ? 0.0 : clamp((val - vmin) / max(eps(), vmax - vmin), 0.0, 1.0)
    return smin + t * (smax - smin)
end

# Draw beautiful 3D arrow with smooth cylinder and cone
function draw_arrow_3d!(ax, start, endpt, radius, color; segments=32)
    # accept plain Colors.jl color types, coerce to Float32 RGB
    col_rgb = RGB{Float32}(color)
    start_f = Float32.(start)
    end_f   = Float32.(endpt)
    radius_f = Float32(radius)

    dir = end_f .- start_f
    length = norm(dir)
    if length < Float32(1e-6)
        return
    end

    dir_normalized = dir ./ length
    shaft_length = length * Float32(0.80)
    shaft_end = start_f .+ dir_normalized .* shaft_length

    # perpendicular vectors
    if abs(dir_normalized[3]) < Float32(0.9)
        perp1 = cross(dir_normalized, Float32[0, 0, 1])
    else
        perp1 = cross(dir_normalized, Float32[1, 0, 0])
    end
    perp1 .= perp1 ./ max(norm(perp1), eps(Float32))
    perp2 = cross(dir_normalized, perp1)
    perp2 .= perp2 ./ max(norm(perp2), eps(Float32))

    theta = range(0f0, 2π, length=segments+1)
    theta_f = Float32.(theta)

    shaft_bottom = [start_f .+ radius_f .* (cos(t) .* perp1 .+ sin(t) .* perp2) for t in theta_f]
    shaft_top    = [shaft_end .+ radius_f .* (cos(t) .* perp1 .+ sin(t) .* perp2) for t in theta_f]

    # shaft quads
    for i in 1:segments
        p1 = shaft_bottom[i]; p2 = shaft_bottom[i+1]; p3 = shaft_top[i+1]; p4 = shaft_top[i]
        mesh!(ax,
            Float32[ p1[1], p2[1], p3[1], p4[1] ],
            Float32[ p1[2], p2[2], p3[2], p4[2] ],
            Float32[ p1[3], p2[3], p3[3], p4[3] ],
            color=col_rgb, shading=false)
    end

    # cap bottom
    for i in 1:segments
        p1 = shaft_bottom[i]; p2 = shaft_bottom[i+1]
        mesh!(ax,
            Float32[ start_f[1], p1[1], p2[1] ],
            Float32[ start_f[2], p1[2], p2[2] ],
            Float32[ start_f[3], p1[3], p2[3] ],
            color=col_rgb, shading=false)
    end

    # cone head
    cone_radius = radius_f * Float32(2.8)
    cone_base = [shaft_end .+ cone_radius .* (cos(t) .* perp1 .+ sin(t) .* perp2) for t in theta_f]

    for i in 1:segments
        p1 = cone_base[i]; p2 = cone_base[i+1]
        mesh!(ax,
            Float32[ p1[1], p2[1], end_f[1] ],
            Float32[ p1[2], p2[2], end_f[2] ],
            Float32[ p1[3], p2[3], end_f[3] ],
            color=col_rgb, shading=false)
    end

    # cap cone base
    for i in 1:segments
        p1 = cone_base[i]; p2 = cone_base[i+1]
        mesh!(ax,
            Float32[ shaft_end[1], p1[1], p2[1] ],
            Float32[ shaft_end[2], p1[2], p2[2] ],
            Float32[ shaft_end[3], p1[3], p2[3] ],
            color=col_rgb, shading=false)
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
end

nframes = nrow(df)
println("Creating 3D animation with $nframes frames")

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

# Beautiful color palette (coerce later as needed)
sw_col = colorant"#FFB84D"      # Warm golden yellow for solar
lw_col = colorant"#FF6B6B"      # Vibrant red for longwave
sens_col = colorant"#4ECDC4"    # Turquoise for sensible
lat_col = colorant"#5B7FFF"     # Royal blue for latent
atm_col = RGBA(0.85, 0.93, 0.98, 0.25)  # Soft sky blue
surf_col = colorant"#8FBC8F"    # Sage green for surface
grid_col = colorant"#B0C4DE"    # Light steel blue for grid
grid_rgba = RGBA(0.4, 0.6, 0.4, 0.3)

# Create figure with white background for contrast
fig = Figure(size=(1600, 1200), backgroundcolor=:white)
ax = Axis3(fig[1, 1], 
    aspect=(1, 1, 0.7),
    elevation=0.25,
    azimuth=2.2,
    xlabel="", ylabel="", zlabel="",
    xticksvisible=false, yticksvisible=false, zticksvisible=false,
    xticklabelsvisible=false, yticklabelsvisible=false, zticklabelsvisible=false,
    xgridvisible=false, ygridvisible=false, zgridvisible=false,
    xspinesvisible=false, yspinesvisible=false, zspinesvisible=false)

# Observable for current frame (not strictly required but kept)
frame_idx = Observable(1)

# Define geometry - make it more spacious
surf_z = 0.0f0
atm_bottom = 0.0f0
atm_top = 6.0f0
atm_mid = 3.0f0

# Atmosphere box with subtle styling
box_size = 5.0f0
box_x = [-box_size, box_size, box_size, -box_size, -box_size, box_size, box_size, -box_size]
box_y = [-box_size, -box_size, box_size, box_size, -box_size, -box_size, box_size, box_size]
box_z = [atm_bottom, atm_bottom, atm_bottom, atm_bottom, atm_top, atm_top, atm_top, atm_top]

# Draw atmosphere box with dashed lines
for i in 1:4
    next_i = (i % 4) + 1
    # Bottom face
    lines!(ax, [box_x[i], box_x[next_i]], [box_y[i], box_y[next_i]], [box_z[i], box_z[next_i]], 
           color=grid_col, linewidth=2.5, linestyle=:dash)
    # Top face
    lines!(ax, [box_x[i+4], box_x[next_i+4]], [box_y[i+4], box_y[next_i+4]], [box_z[i+4], box_z[next_i+4]], 
           color=grid_col, linewidth=2.5, linestyle=:dash)
    # Vertical edges
    lines!(ax, [box_x[i], box_x[i+4]], [box_y[i], box_y[i+4]], [box_z[i], box_z[i+4]], 
           color=grid_col, linewidth=2.5, linestyle=:dash)
end

# Semi-transparent atmosphere fill (top face)
mesh!(ax, 
    [-box_size, box_size, box_size, -box_size], 
    [-box_size, -box_size, box_size, box_size], 
    [atm_top, atm_top, atm_top, atm_top],
    color=atm_col, shading=false)

# Beautiful surface with gradient — build grid and draw each quad (robust)
surf_points = 30
xs = collect(range(-box_size, box_size, length=surf_points))  # Float64
ys = collect(range(-box_size, box_size, length=surf_points))
# convert to Float32 elementwise where used
# Precompute z-values (Float32)
zs = [Float32(surf_z + 0.1*sin(0.5*x)*cos(0.5*y)) for x in xs, y in ys]

# Draw quads (per cell) to avoid the high-level surface path that triggers colormap code
for j in 1:(length(ys)-1), i in 1:(length(xs)-1)
    x1 = Float32(xs[i]); x2 = Float32(xs[i+1])
    y1 = Float32(ys[j]); y2 = Float32(ys[j+1])
    z11 = zs[i, j]; z21 = zs[i+1, j]; z22 = zs[i+1, j+1]; z12 = zs[i, j+1]
    mesh!(ax,
        Float32[ x1, x2, x2, x1 ],
        Float32[ y1, y1, y2, y2 ],
        Float32[ z11, z21, z22, z12 ],
        color=surf_col, shading=false)
end

# Add decorative grid on surface
for x in range(-box_size, box_size, length=6)
    lines!(ax, fill(Float32(x), surf_points), Float32.(ys), fill(Float32(surf_z), surf_points), 
           color=grid_rgba, linewidth=1)
end
for y in range(-box_size, box_size, length=6)
    lines!(ax, Float32.(xs), fill(Float32(y), surf_points), fill(Float32(surf_z), surf_points), 
           color=grid_rgba, linewidth=1)
end

# Elegant text labels with backgrounds
text!(ax, "ATMOSPHERE", position=(0f0, 0f0, atm_top + 0.8f0), align=(:center, :center), 
      fontsize=32, color=:black, font=:bold)
text!(ax, "EARTH SURFACE", position=(0f0, 0f0, surf_z - 0.8f0), align=(:center, :center), 
      fontsize=32, color=colorant"#2F5233", font=:bold)

# Animation function
function update_arrows!(idx)
    row = df[idx, :]
    sw_d = map_stroke(row[:sw_down], sw_vmin, sw_vmax, min_radius, max_radius)
    sw_r = map_stroke(row[:sw_ref], swr_vmin, swr_vmax, min_radius, max_radius)
    lw_u = map_stroke(row[:lw_up], lw_vmin, lw_vmax, min_radius, max_radius)
    lw_d = map_stroke(row[:lw_down], lwd_vmin, lwd_vmax, min_radius, max_radius)
    sen = map_stroke(row[:sensible], sens_vmin, sens_vmax, min_radius*0.85, max_radius*0.85)
    la = map_stroke(row[:latent], lat_vmin, lat_vmax, min_radius*0.85, max_radius*0.85)
    
    offset = 2.2
    
    # SW Down (incoming solar) - from top of atmosphere
    draw_arrow_3d!(ax, [offset, offset, atm_top + 1.5], [offset, offset, surf_z + 0.3], 
                   sw_d, sw_col, segments=12, )
    text!(ax, "Incoming Solar\n" * fmt(row[:sw_down]), 
          position=(offset + 0.8, offset + 0.3, atm_mid + 1.5), 
          fontsize=16, color=:black, font=:bold, align=(:left, :center))
    
    # SW Reflected - back to space
    draw_arrow_3d!(ax, [offset, -offset, surf_z + 0.3], [offset, -offset, atm_top + 1.5], 
                   sw_r, sw_col, segments=40)
    text!(ax, "Reflected Solar\n" * fmt(row[:sw_ref]), 
          position=(offset + 0.8, -offset - 0.3, atm_mid + 1.5), 
          fontsize=16, color=:black, font=:bold, align=(:left, :center))
    
    # LW Up - thermal radiation from surface
    draw_arrow_3d!(ax, [-offset, offset, surf_z + 0.3], [-offset, offset, atm_top + 1.5], 
                   lw_u, lw_col, segments=40)
    text!(ax, "Thermal Up\n" * fmt(row[:lw_up]), 
          position=(-offset - 0.8, offset + 0.3, atm_mid + 1.5), 
          fontsize=16, color=:black, font=:bold, align=(:right, :center))
    
    # LW Down - back radiation from atmosphere
    draw_arrow_3d!(ax, [-offset, -offset, atm_top - 1.0], [-offset, -offset, surf_z + 0.3], 
                   lw_d, lw_col, segments=40)
    text!(ax, "Back Radiation\n" * fmt(row[:lw_down]), 
          position=(-offset - 0.8, -offset - 0.3, atm_mid - 0.5), 
          fontsize=16, color=:black, font=:bold, align=(:right, :center))
    
    # Sensible heat - turbulent heat transfer
    draw_arrow_3d!(ax, [0.3, 1.2, surf_z + 0.3], [0.3, 1.2, atm_mid - 0.5], 
                   sen, sens_col, segments=40)
    text!(ax, "Sensible\n" * fmt(row[:sensible]), 
          position=(0.8, 1.7, atm_mid/2 + 0.3), 
          fontsize=15, color=:black, font=:bold, align=(:left, :center))
    
    # Latent heat - evaporation/condensation
    draw_arrow_3d!(ax, [-0.3, -1.2, surf_z + 0.3], [-0.3, -1.2, atm_mid - 0.5], 
                   la, lat_col, segments=40)
    text!(ax, "Latent\n" * fmt(row[:latent]), 
          position=(-0.8, -1.7, atm_mid/2 + 0.3), 
          fontsize=15, color=:black, font=:bold, align=(:right, :center))
    
    # Time label with nice styling
    tlabel = haskey(row, :time) ? Dates.format(row[:time], "yyyy-mm-dd HH:MM") : "Frame $idx/$nframes"
    text!(ax, tlabel, position=(box_size - 1.2, box_size - 0.5, atm_top + 1.2), 
          fontsize=18, color=:black, font=:bold, align=(:right, :top))
    
    # Energy balance info
    net_surface = row[:sw_down] - row[:sw_ref] + row[:lw_down] - row[:lw_up] - row[:sensible] - row[:latent]
    balance_text = "Net Surface: " * fmt(net_surface)
    text!(ax, balance_text, position=(-box_size + 1.2, box_size - 0.5, atm_top + 1.2), 
          fontsize=18, color=:black, font=:bold, align=(:left, :top))
end

# Initial draw
update_arrows!(1)

# Create animation with smooth framerate
println("Rendering animation...")
record(fig, "trenberth_3d_beautiful_fixed3.mp4", 1:nframes; framerate=12) do i
    frame_idx[] = i
    empty!(ax)
    
    # Redraw static elements
    for i in 1:4
        next_i = (i % 4) + 1
        lines!(ax, [box_x[i], box_x[next_i]], [box_y[i], box_y[next_i]], [box_z[i], box_z[next_i]], 
               color=grid_col, linewidth=2.5, linestyle=:dash)
        lines!(ax, [box_x[i+4], box_x[next_i+4]], [box_y[i+4], box_y[next_i+4]], [box_z[i+4], box_z[next_i+4]], 
               color=grid_col, linewidth=2.5, linestyle=:dash)
        lines!(ax, [box_x[i], box_x[i+4]], [box_y[i], box_y[i+4]], [box_z[i], box_z[i+4]], 
               color=grid_col, linewidth=2.5, linestyle=:dash)
    end
    
    mesh!(ax, 
        [-box_size, box_size, box_size, -box_size], 
        [-box_size, -box_size, box_size, box_size], 
        [atm_top, atm_top, atm_top, atm_top],
        color=atm_col, shading=false)
    
    # redraw ground quads quickly (same loop as above)
    for j in 1:(length(ys)-1), i in 1:(length(xs)-1)
        x1 = Float32(xs[i]); x2 = Float32(xs[i+1])
        y1 = Float32(ys[j]); y2 = Float32(ys[j+1])
        z11 = zs[i, j]; z21 = zs[i+1, j]; z22 = zs[i+1, j+1]; z12 = zs[i, j+1]
        mesh!(ax,
            Float32[ x1, x2, x2, x1 ],
            Float32[ y1, y1, y2, y2 ],
            Float32[ z11, z21, z22, z12 ],
            color=surf_col, shading=false)
    end

    for x in range(-box_size, box_size, length=6)
        lines!(ax, fill(Float32(x), surf_points), Float32.(ys), fill(Float32(surf_z), surf_points), 
               color=grid_rgba, linewidth=1)
    end
    for y in range(-box_size, box_size, length=6)
        lines!(ax, Float32.(xs), fill(Float32(y), surf_points), fill(Float32(surf_z), surf_points), 
               color=grid_rgba, linewidth=1)
    end
    
    text!(ax, "ATMOSPHERE", position=(0, 0, atm_top + 0.8f0), align=(:center, :center), 
          fontsize=32, color=:black, font=:bold)
    text!(ax, "EARTH SURFACE", position=(0, 0, surf_z - 0.8f0), align=(:center, :center), 
          fontsize=32, color=colorant"#2F5233", font=:bold)
    
    update_arrows!(i)
end

println("Animation saved as trenberth_3d_beautiful_fixed3.mp4")
display(fig)

#!/usr/bin/env julia
# trenberth_3d_glmakie.jl
# 3D visualization of Trenberth energy budget using GLMakie

using GLMakie, Colors, CSV, DataFrames, Dates, Printf, Statistics, LinearAlgebra

fmt(x) = @sprintf("%.1f W/m²", x)

# Map stroke widths to data values
function map_stroke(val, vmin, vmax, smin, smax)
    t = isnan(val) ? 0.0 : clamp((val - vmin) / max(eps(), vmax - vmin), 0.0, 1.0)
    return smin + t * (smax - smin)
end

# Draw 3D arrow with cylinder shaft and cone head
function draw_arrow_3d!(ax, start, endpt, radius, color)
    # Calculate direction and length
    dir = endpt .- start
    length = norm(dir)
    if length < 1e-6 return end
    
    dir_normalized = dir ./ length
    
    # Shaft length (leave room for head)
    shaft_length = length * 0.85
    shaft_end = start .+ dir_normalized .* shaft_length
    
    # Create cylinder for shaft
    n_segments = 20
    theta = range(0, 2π, length=n_segments)
    
    # Find perpendicular vectors for cylinder
    if abs(dir_normalized[3]) < 0.9
        perp1 = cross(dir_normalized, [0, 0, 1])
    else
        perp1 = cross(dir_normalized, [1, 0, 0])
    end
    perp1 = perp1 ./ norm(perp1)
    perp2 = cross(dir_normalized, perp1)
    perp2 = perp2 ./ norm(perp2)
    
    # Cylinder vertices
    for i in 1:n_segments-1
        x1 = start .+ radius .* (cos(theta[i]) .* perp1 .+ sin(theta[i]) .* perp2)
        x2 = start .+ radius .* (cos(theta[i+1]) .* perp1 .+ sin(theta[i+1]) .* perp2)
        y1 = shaft_end .+ radius .* (cos(theta[i]) .* perp1 .+ sin(theta[i]) .* perp2)
        y2 = shaft_end .+ radius .* (cos(theta[i+1]) .* perp1 .+ sin(theta[i+1]) .* perp2)
        
        mesh!(ax, [x1[1], x2[1], y2[1], y1[1]], 
                  [x1[2], x2[2], y2[2], y1[2]], 
                  [x1[3], x2[3], y2[3], y1[3]], 
                  color=color, transparency=false)
    end
    
    # Cone head
    cone_radius = radius * 2.5
    cone_height = length * 0.15
    
    for i in 1:n_segments-1
        p1 = shaft_end .+ cone_radius .* (cos(theta[i]) .* perp1 .+ sin(theta[i]) .* perp2)
        p2 = shaft_end .+ cone_radius .* (cos(theta[i+1]) .* perp1 .+ sin(theta[i+1]) .* perp2)
        
        mesh!(ax, [p1[1], p2[1], endpt[1]], 
                  [p1[2], p2[2], endpt[2]], 
                  [p1[3], p2[3], endpt[3]], 
                  color=color, transparency=false)
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

min_radius = 0.08; max_radius = 0.3

# Colors
sw_col = parse(Colorant, "#D6A91E")
lw_col = parse(Colorant, "#D94536")
sens_col = parse(Colorant, "#0F6B6B")
lat_col = parse(Colorant, "#1F4FA3")
atm_col = RGBA(0.8, 0.9, 0.95, 0.3)
surf_col = RGBA(0.4, 0.7, 0.4, 0.4)

# Create figure
fig = Figure(size=(1400, 1000))
ax = Axis3(fig[1, 1], 
    aspect=(1, 1, 0.8),
    elevation=0.3,
    azimuth=2.4,
    xlabel="", ylabel="", zlabel="",
    xticksvisible=false, yticksvisible=false, zticksvisible=false,
    xticklabelsvisible=false, yticklabelsvisible=false, zticklabelsvisible=false)

# Observable for current frame
frame_idx = Observable(1)

# Define geometry
surf_z = 0.0
atm_bottom = 0.0
atm_top = 5.0
atm_mid = 2.5

# Draw atmosphere layer (semi-transparent box)
box_x = [-4, 4, 4, -4, -4, 4, 4, -4]
box_y = [-4, -4, 4, 4, -4, -4, 4, 4]
box_z = [atm_bottom, atm_bottom, atm_bottom, atm_bottom, atm_top, atm_top, atm_top, atm_top]

# Draw atmosphere box faces
for i in 1:4
    next_i = (i % 4) + 1
    # Bottom face edges
    lines!(ax, [box_x[i], box_x[next_i]], [box_y[i], box_y[next_i]], [box_z[i], box_z[next_i]], 
           color=:lightblue, linewidth=2)
    # Top face edges
    lines!(ax, [box_x[i+4], box_x[next_i+4]], [box_y[i+4], box_y[next_i+4]], [box_z[i+4], box_z[next_i+4]], 
           color=:lightblue, linewidth=2)
    # Vertical edges
    lines!(ax, [box_x[i], box_x[i+4]], [box_y[i], box_y[i+4]], [box_z[i], box_z[i+4]], 
           color=:lightblue, linewidth=2)
end

# Draw surface plane
surf_mesh = mesh!(ax, 
    [-4, 4, 4, -4], [-4, -4, 4, 4], [surf_z, surf_z, surf_z, surf_z],
    color=surf_col)

# Text labels
text!(ax, "ATMOSPHERE", position=(0, 0, atm_top + 0.5), align=(:center, :center), 
      fontsize=24, color=:black)
text!(ax, "SURFACE", position=(0, 0, surf_z - 0.5), align=(:center, :center), 
      fontsize=24, color=:darkgreen)

# Observables for arrow parameters
sw_down_radius = @lift(map_stroke(df[$frame_idx, :sw_down], sw_vmin, sw_vmax, min_radius, max_radius))
sw_ref_radius = @lift(map_stroke(df[$frame_idx, :sw_ref], swr_vmin, swr_vmax, min_radius, max_radius))
lw_up_radius = @lift(map_stroke(df[$frame_idx, :lw_up], lw_vmin, lw_vmax, min_radius, max_radius))
lw_down_radius = @lift(map_stroke(df[$frame_idx, :lw_down], lwd_vmin, lwd_vmax, min_radius, max_radius))
sens_radius = @lift(map_stroke(df[$frame_idx, :sensible], sens_vmin, sens_vmax, min_radius*0.8, max_radius*0.8))
lat_radius = @lift(map_stroke(df[$frame_idx, :latent], lat_vmin, lat_vmax, min_radius*0.8, max_radius*0.8))

# Draw energy flow arrows (these will be redrawn each frame)
function update_arrows!(idx)
    empty!(ax)
    
    # Redraw static elements
    for i in 1:4
        next_i = (i % 4) + 1
        lines!(ax, [box_x[i], box_x[next_i]], [box_y[i], box_y[next_i]], [box_z[i], box_z[next_i]], 
               color=:lightblue, linewidth=2)
        lines!(ax, [box_x[i+4], box_x[next_i+4]], [box_y[i+4], box_y[next_i+4]], [box_z[i+4], box_z[next_i+4]], 
               color=:lightblue, linewidth=2)
        lines!(ax, [box_x[i], box_x[i+4]], [box_y[i], box_y[i+4]], [box_z[i], box_z[i+4]], 
               color=:lightblue, linewidth=2)
    end
    
    mesh!(ax, [-4, 4, 4, -4], [-4, -4, 4, 4], [surf_z, surf_z, surf_z, surf_z], color=surf_col)
    text!(ax, "ATMOSPHERE", position=(0, 0, atm_top + 0.5), align=(:center, :center), 
          fontsize=24, color=:black)
    text!(ax, "SURFACE", position=(0, 0, surf_z - 0.5), align=(:center, :center), 
          fontsize=24, color=:darkgreen)
    
    # Get current data
    row = df[idx, :]
    sw_d = map_stroke(row[:sw_down], sw_vmin, sw_vmax, min_radius, max_radius)
    sw_r = map_stroke(row[:sw_ref], swr_vmin, swr_vmax, min_radius, max_radius)
    lw_u = map_stroke(row[:lw_up], lw_vmin, lw_vmax, min_radius, max_radius)
    lw_d = map_stroke(row[:lw_down], lwd_vmin, lwd_vmax, min_radius, max_radius)
    sen = map_stroke(row[:sensible], sens_vmin, sens_vmax, min_radius*0.8, max_radius*0.8)
    la = map_stroke(row[:latent], lat_vmin, lat_vmax, min_radius*0.8, max_radius*0.8)
    
    # SW Down (incoming solar)
    draw_arrow_3d!(ax, [2, 2, atm_top + 1], [2, 2, surf_z + 0.1], sw_d, sw_col)
    text!(ax, "SW ↓\n" * fmt(row[:sw_down]), position=(2.5, 2, atm_mid), 
          fontsize=14, color=:black)
    
    # SW Reflected
    draw_arrow_3d!(ax, [2, -2, surf_z + 0.1], [2, -2, atm_top + 1], sw_r, sw_col)
    text!(ax, "SW ↑\n" * fmt(row[:sw_ref]), position=(2.5, -2, atm_mid), 
          fontsize=14, color=:black)
    
    # LW Up
    draw_arrow_3d!(ax, [-2, 2, surf_z + 0.1], [-2, 2, atm_top + 1], lw_u, lw_col)
    text!(ax, "LW ↑\n" * fmt(row[:lw_up]), position=(-2.5, 2, atm_mid), 
          fontsize=14, color=:black)
    
    # LW Down
    draw_arrow_3d!(ax, [-2, -2, atm_top - 0.5], [-2, -2, surf_z + 0.1], lw_d, lw_col)
    text!(ax, "LW ↓\n" * fmt(row[:lw_down]), position=(-2.5, -2, atm_mid), 
          fontsize=14, color=:black)
    
    # Sensible heat
    draw_arrow_3d!(ax, [0, 0.8, surf_z + 0.1], [0, 0.8, atm_mid], sen, sens_col)
    text!(ax, "Sensible\n" * fmt(row[:sensible]), position=(0.3, 1.3, atm_mid/2), 
          fontsize=12, color=:black)
    
    # Latent heat
    draw_arrow_3d!(ax, [0, -0.8, surf_z + 0.1], [0, -0.8, atm_mid], la, lat_col)
    text!(ax, "Latent\n" * fmt(row[:latent]), position=(0.3, -1.3, atm_mid/2), 
          fontsize=12, color=:black)
    
    # Time label
    tlabel = haskey(row, :time) ? string(row[:time]) : "Frame $idx"
    text!(ax, tlabel, position=(3, 3, atm_top + 0.8), fontsize=16, color=:black)
end

# Initial draw
update_arrows!(1)

# Animation
println("Starting animation...")
record(fig, "trenberth_3d.mp4", 1:nframes; framerate=8) do i
    frame_idx[] = i
    update_arrows!(i)
end

println("Animation saved as trenberth_3d.mp4")

display(fig)
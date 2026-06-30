#!/usr/bin/env julia
using GLMakie
fig = Figure(resolution=(640,480))
ax = Axis3(fig[1,1])
lines!(ax, [0,0], [0,0], [0,1], linewidth=6)
text!(ax, "GL one-frame test", position=(0,0,1.2), align=(:center,:center))
save("test_oneframe.png", fig)
println("wrote test_oneframe.png")

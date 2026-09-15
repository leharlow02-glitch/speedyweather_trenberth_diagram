using Pkg
using SpeedyWeather, GLMakie, Statistics
using SpeedyWeatherInternals.Utils
using LowerTriangularArrays
using SpeedyTransforms

# Load order matters: trenberth_calc.jl defines calc_trenberth_from_diagn,
# which trenberth_callback.jl depends on.
include("trenberth_calc.jl")
include("trenberth_callback.jl")
include("trenberth_observables.jl")
include("trenberth_diagram_3.jl")

# 1) set up the model
spectral_grid = SpectralGrid(trunc=31, nlayers=8)

model = PrimitiveWetModel(spectral_grid; shortwave_radiation=OneBandShortwave(spectral_grid, clouds = DiagnosticClouds(spectral_grid; use_stratocumulus=true)))

# 2) attach TWO callbacks instead of one.
#
# For a 10-year run, recording map snapshots at daily resolution is what
# was causing the memory/segfault trouble - record_maps=true keeps one
# Field snapshot per recorded step, per field, in memory for the whole
# run. Over 10 years daily that's ~3650 steps x 9 fields; weekly over the
# same period is ~520 x 9 - roughly 7x less memory, and still plenty
# smooth for the "Show Flux Maps" viewer / a maps GIF.
#
# The scalar time series (arrow diagram, "Show All Flux Time Series") is
# cheap by comparison - it's just numbers, not full grids - so there's no
# need to sacrifice its resolution to save memory. Splitting into two
# callbacks lets each one use the schedule that actually suits it:
#   - cb_scalars: daily, record_maps=false -> smooth arrow diagram/time series
#   - cb_maps:    weekly, record_maps=true  -> maps viewer/GIF without the memory blowup
#
# If you'd rather keep everything on one callback (simpler, but ties the
# arrow-diagram resolution to the map resolution), just use:
#   cb = TrenberthCallback(schedule=Schedule(every=Week(1)), record_maps=true)
#   add!(model.callbacks, :trenberth => cb)
# and skip cb_maps below entirely.
cb_scalars = TrenberthCallback(
    schedule=Schedule(every=Day(1)),
    record_maps=false)
cb_maps = TrenberthCallback(
    schedule=Schedule(every=Week(1)),
    record_maps=true)
add!(model.callbacks, :trenberth_scalars => cb_scalars)
add!(model.callbacks, :trenberth_maps    => cb_maps)

# 3) initialize and run
sim = initialize!(model)   # this will call SpeedyWeather.initialize! on both callbacks
run!(sim, period=Year(1))

# --- sanity checks -----------------------------------------------------
println("\ncb_scalars.timestep_counter = $(cb_scalars.timestep_counter) (should be roughly the number of days simulated)")
println("cb_scalars.data[:OLR] has $(length(cb_scalars.data[:OLR])) recorded values")
println("cb_maps.timestep_counter = $(cb_maps.timestep_counter) (should be roughly the number of weeks simulated)")
println("cb_maps.maps[:OLR] has $(length(cb_maps.maps[:OLR])) recorded map snapshots")
# finalize! (called automatically at the end of run!) already printed the
# per-flux simulation means, and the approximate memory used by cb_maps.maps,
# for each callback above.

# 4) build the Observables - one for the fast scalar diagram, one for the
# sparser maps. Both skip the initial/pre-run timestep by default.
obs      = build_trenberth_observables(cb_scalars)   # drives the arrow diagram + time series
obs_maps = build_trenberth_observables(cb_maps)      # drives the flux maps viewer/GIF
arrows   = build_flux_arrow_observables(obs.current_point)
solar    = get_solar_constant(model)

println("\nobs.nsteps = $(obs.nsteps) (daily steps available to animate, after skipping the first)")
println("obs_maps.nsteps = $(obs_maps.nsteps) (weekly map steps available)")
println("obs_maps.maps has entries for: $(collect(keys(obs_maps.maps)))")

# 5) Save GIFs. Over a 10-year run this is usually more practical than the
# interactive window - the arrow-diagram GIF plays through all 3650+ daily
# steps, the time series GIF plays through the same daily steps with a
# sweeping marker on each panel, and the maps GIF plays through the ~520
# weekly steps, without needing anyone to sit and scrub a slider.
println("\nSaving GIFs (this can take a little while for a 10-year run)...")
save_trenberth_gif(obs, arrows, solar; filename="trenberth_3.gif", framerate=24)
save_flux_timeseries_gif(obs; filename="trenberth_timeseries_3.gif", framerate=24)
save_flux_maps_gif(obs_maps; filename="trenberth_maps_3.gif", framerate=8)
println("Saved trenberth_3.gif, trenberth_timeseries_3.gif, and trenberth_maps_3.gif")

# 6) Optional: also open the interactive window. Note this uses obs (daily,
# no maps attached) for the arrow diagram/time series; if you want the
# "Show Flux Maps" button available interactively too, swap in obs_maps
# below (you'll get the coarser weekly resolution for everything, though,
# since plot_trenberth_diagram only takes one `obs`).
fig, cleanup = plot_trenberth_diagram(obs, arrows, solar)
screen = display(fig)

println("\nDiagram is up.")
wait(screen)   # blocks here until the window is closed, instead of exiting immediately
println("Click 'Show All Flux Time Series' for the full time series (dates now")
println("label only the bottom row of panels, to cut down on clutter).")
println("Maps were recorded on a separate (weekly) callback for this 10-year run,")
println("so they're not wired into this interactive window - see trenberth_maps.gif")
println("for the maps animation instead, or rebuild with plot_trenberth_diagram(obs_maps, ...)")
println("if you want them interactive too (at weekly rather than daily resolution).")

# When you're done (e.g. closing the app), call cleanup() to stop the
# animation task and close any open popup windows.
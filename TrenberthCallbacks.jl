module TrenberthCallbacks

export TrenberthCallback, calc_trenberth_from_diagn

using SpeedyWeather
using Dates
using Statistics

# put your existing definitions here:
# - calc_trenberth_from_diagn
function calc_trenberth_from_diagn(diagn, model; SumFlag::Bool=false)
    fields = Dict(
        :LHF   => diagn.physics.surface_latent_heat_flux,
        :SHF   => diagn.physics.sensible_heat_flux,
        :SSRU  => diagn.physics.surface_shortwave_up,
        :SLRU  => diagn.physics.surface_longwave_up,
        :SSRD  => diagn.physics.surface_shortwave_down,
        :SLRD  => diagn.physics.surface_longwave_down,
        :OSR   => diagn.physics.outgoing_shortwave_radiation,
        :OLR   => diagn.physics.outgoing_longwave_radiation,
        :albedo=> diagn.physics.albedo
    )

    function calc_global_mean(field)
        a = transform(field)
        a00 = real(a[1])
        return a00 / model.spectral_transform.norm_sphere
    end

    function calc_global_sum(field)
        mean_val = calc_global_mean(field)
        area = 4π * model.planet.radius^2
        return mean_val * area
    end

    calcfun = SumFlag ? calc_global_sum : calc_global_mean

    results = Dict{Symbol, Float64}()
    for (k, f) in fields
        try
            results[k] = Float64(calcfun(f))
        catch err
            @warn "calc_trenberth_from_diagn: could not compute $k: $err"
            results[k] = NaN
        end
    end

    results[:SW_net_sfc]  = results[:SSRD] - results[:SSRU]
    results[:LW_net_sfc]  = results[:SLRD] - results[:SLRU]
    results[:surface_net] = results[:SW_net_sfc] + results[:LW_net_sfc] - results[:LHF] - results[:SHF]

    return results
end

# - TRENBERTH_LONGNAMES
const TRENBERTH_LONGNAMES = Dict(
    :LHF => "Surface latent heat flux (W/m²)",
    :SHF => "Surface sensible heat flux (W/m²)",
    :SSRU => "Surface shortwave up (W/m²)",
    :SLRU => "Surface longwave up (W/m²)",
    :SSRD => "Surface shortwave down (W/m²)",
    :SLRD => "Surface longwave down (W/m²)",
    :OSR => "Outgoing shortwave radiation (TOA) (W/m²)",
    :OLR => "Outgoing longwave radiation (TOA) (W/m²)",
    :albedo => "Surface albedo",
    :SW_net_sfc => "Surface net shortwave (W/m²)",
    :LW_net_sfc => "Surface net longwave (W/m²)",
    :surface_net => "Surface net energy (W/m²)"
)

# - TrenberthCallback struct
Base.@kwdef mutable struct TrenberthCallback <: SpeedyWeather.AbstractCallback
    timestep_counter::Int = 0
    data::Dict{Symbol, Vector{Float64}} = Dict{Symbol, Vector{Float64}}()
    times::Vector{Float64} = Float64[]
    datetimes::Vector{DateTime} = DateTime[]
    start_time::Float64 = 0.0
    SumFlag::Bool = false
    var_longnames::Dict{Symbol,String} = TRENBERTH_LONGNAMES
    schedule::Schedule = Schedule()
end

function TrenberthCallback(; vars = [:LHF,:SHF,:SSRU,:SLRU,:SSRD,:SLRD,:OSR,:OLR,:albedo,:SW_net_sfc,:LW_net_sfc,:surface_net],
                             SumFlag::Bool=false,
                             nsteps::Int=0,
                             var_longnames::Dict{Symbol,String}=TRENBERTH_LONGNAMES,
                             schedule::Schedule=Schedule())
    d = Dict{Symbol, Vector{Float64}}()
    for v in vars
        d[v] = nsteps > 0 ? Vector{Float64}(undef, nsteps + 1) : Float64[]
    end
    times = nsteps > 0 ? Vector{Float64}(undef, nsteps + 1) : Float64[]
    datetimes = nsteps > 0 ? Vector{DateTime}(undef, nsteps + 1) : DateTime[]
    return TrenberthCallback(0, d, times, datetimes, 0.0, SumFlag, var_longnames, schedule)
end

# - SpeedyWeather.initialize!
function SpeedyWeather.initialize!(cb::TrenberthCallback,
                                   progn::PrognosticVariables,
                                   diagn::DiagnosticVariables,
                                   model::AbstractModel)

    initialize!(cb.schedule, progn.clock)

    cb.start_time = Dates.datetime2unix(progn.clock.time)

    try
        nsteps = progn.clock.nsteps
        for (k, v) in cb.data
            if isempty(v) || length(v) != nsteps + 1
                cb.data[k] = Vector{Float64}(undef, nsteps + 1)
            end
        end
        if isempty(cb.times) || length(cb.times) != nsteps + 1
            cb.times = Vector{Float64}(undef, nsteps + 1)
        end
        if isempty(cb.datetimes) || length(cb.datetimes) != nsteps + 1
            cb.datetimes = Vector{DateTime}(undef, nsteps + 1)
        end
    catch
        @info "Could not determine nsteps, using dynamic push mode"
    end

    cb.timestep_counter = 1
    t0 = Dates.datetime2unix(progn.clock.time)
    dt0 = progn.clock.time
    res0 = calc_trenberth_from_diagn(diagn, model; SumFlag=cb.SumFlag)
    for (k, v) in res0
        if haskey(cb.data, k)
            if length(cb.data[k]) > 0
                cb.data[k][1] = v
            else
                push!(cb.data[k], v)
            end
        else
            cb.data[k] = [v]
        end
    end

    if length(cb.times) > 0
        cb.times[1] = t0 - cb.start_time
        cb.datetimes[1] = dt0
    else
        push!(cb.times, t0 - cb.start_time)
        push!(cb.datetimes, dt0)
    end
    return nothing
end

# - SpeedyWeather.callback!
function SpeedyWeather.callback!(cb::TrenberthCallback,
                                 progn::PrognosticVariables,
                                 diagn::DiagnosticVariables,
                                 model::AbstractModel)
    isscheduled(cb.schedule, progn.clock) || return nothing
    cb.timestep_counter += 1
    res = calc_trenberth_from_diagn(diagn, model; SumFlag=cb.SumFlag)
    for (k, v) in res
        if !haskey(cb.data, k)
            cb.data[k] = [v]
        else
            push!(cb.data[k], v)
        end
    end
    current_time = Dates.datetime2unix(progn.clock.time)
    push!(cb.times, current_time - cb.start_time)
    push!(cb.datetimes, progn.clock.time)
    return nothing
end

# - SpeedyWeather.finalize!

function SpeedyWeather.finalize!(cb::TrenberthCallback,
                                 progn::PrognosticVariables,
                                 diagn::DiagnosticVariables,
                                 model::AbstractModel)
    @info "Finalizing TrenberthCallback: computing means"
    for (k, vec) in cb.data
        mean_val = mean(vec)
        @info "Mean $k over simulation: $mean_val"
    end
    return nothing
end

function make_trenberth_callback(; vars = [:LHF,:SHF,:SSRU,:SLRU,:SSRD,:SLRD,:OSR,:OLR,:albedo,:SW_net_sfc,:LW_net_sfc,:surface_net],
                                  SumFlag::Bool=false,
                                  nsteps::Int=0,
                                  var_longnames::Dict{Symbol,String}=TRENBERTH_LONGNAMES,
                                  schedule::Schedule=Schedule())
    TrenberthCallback(
        data = Dict{Symbol, Vector{Float64}}(),
        times = Float64[],
        datetimes = DateTime[],
        start_time = 0.0,
        SumFlag = SumFlag,
        var_longnames = var_longnames,
        schedule = schedule
    )
end

function attach_trenberth!(model, cb)
    SpeedyWeather.attach_callback!(model, cb)
end


end # module

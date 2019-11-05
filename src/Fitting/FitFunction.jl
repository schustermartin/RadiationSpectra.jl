"""
    AbstractFitFunction{T, ND, NP}

Abstract type for an `ND`-dimensional fit of eltype `T` with `NP` parameters.
"""
abstract type AbstractFitFunction{T, ND, NP} end

"""
    mutable struct FitFunction{T, ND, NP} <: AbstractFitFunction{T, ND, NP}

T: Precision type

ND: Dimensionality

NP: NP parameters

Fields:
- `model::Function`: Function of the fit model.
- `fitranges::NTuple{N, Vector{T}}`: Range on which the fit is performed.
- `parameter_names::Vector{Symbol}`: Parameters names.
- `fitted_parameters::Vector{T}`: Fitted parameters.
- `initial_parameters::Vector{T}`: Initial parameters.

"""
mutable struct FitFunction{T, ND, NP} <: AbstractFitFunction{T, ND, NP}
    model::Function
    fitranges::NTuple{ND, AbstractVector{T}}
    parameter_names::AbstractVector{Symbol}
    fitted_parameters::AbstractVector{T}
    initial_parameters::AbstractVector{T}
    parameter_bounds::AbstractVector{<:Interval}
    backend_result::Any

    function FitFunction{T}(model::Function, ndims::Int, nparams::Int) where {T <: AbstractFloat}
        fitranges::NTuple{ndims, Vector{T}} = NTuple{ndims, Vector{T}}( [-Inf, Inf] for idim in 1:ndims)
        parameter_names::Vector{Symbol} = [Symbol("par$(ipar)") for ipar in 1:nparams]
        fitted_parameters::Vector{T} = [ T(NaN) for ipar in 1:nparams]
        initial_parameters::Vector{T} = [ T(NaN) for ipar in 1:nparams]
        parameter_bounds = [ T(nextfloat(typemin(T))/2)..T(prevfloat(typemax(T))/2) for ipar in 1:nparams]
        return new{T, ndims, nparams}(model, fitranges, parameter_names, fitted_parameters, initial_parameters, parameter_bounds, missing)
    end
end

get_ndims(ff::AbstractFitFunction{T, ND}) where {T <: AbstractFloat, ND} = ND
get_nparams(ff::AbstractFitFunction{T, ND, NP}) where {T <: AbstractFloat, ND, NP} = NP
get_pricision_type(ff::AbstractFitFunction{T}) where {T <: AbstractFloat} = T

function get_fit_backend_result(f::AbstractFitFunction)
    return f.backend_result
end
function set_fit_backend_result!(f::AbstractFitFunction, r)
    f.backend_result = r
    nothing
end

function set_parameter_bounds!(ff::FitFunction{T}, par_bounds::Vector{<:Interval})::Nothing where {T <: AbstractFloat}
    nparams::Int = get_nparams(ff)
    @assert length(par_bounds) == nparams "Wrong number of parameter bounds."
    for i in 1:nparams
        ff.parameter_bounds[i] = par_bounds[i]
    end
end

function set_fitranges!(ff::AbstractFitFunction{T, N}, fitranges::NTuple{N, NTuple{2, <:Real}})::Nothing where {T <: AbstractFloat, N}
     for idim in 1:N
        ff.fitranges[idim][:] = T.([ fitranges[idim][1], fitranges[idim][2] ])
    end
    nothing
end
function set_fitranges!(ff::AbstractFitFunction{T, N}, fitranges::NTuple{N, AbstractVector{<:Real}})::Nothing where {T <: AbstractFloat, N}
    for idim in 1:N
        @assert length(fitranges[idim]) == 2 "All vectors in `fitranges` must have length 2. But in dimension $(idim) it is $(length(fitranges[idim])) ($(fitranges[idim]))."
        ff.fitranges[idim][:] = T.([ first(fitranges[idim]), last(fitranges[idim]) ])
    end
    nothing
end
function set_parameter_names!(ff::FitFunction{T}, parameter_names::Vector{String})::Nothing where {T <: AbstractFloat}
    ff.parameter_names[:] = [Symbol(name) for name in parameter_names]
    nothing
end
function set_initial_parameters!(ff::FitFunction{T}, initial_parameters::NamedTuple)::Nothing where {T <: AbstractFloat}
    ff.parameter_names[:] = collect(keys(initial_parameters))
    ff.initial_parameters[:] = collect(T, initial_parameters)
    nothing
end
function set_initial_parameters!(ff::FitFunction{T}, initial_parameters::AbstractVector{<:Real})::Nothing where {T <: AbstractFloat}
    ff.initial_parameters[:] = collect(T, initial_parameters)
    nothing
end
function _set_fitted_parameters!(ff::FitFunction{T}, fitted_parameters::AbstractVector{<:Real})::Nothing where {T <: AbstractFloat}
    ff.fitted_parameters[:] = T.(fitted_parameters)
    nothing
end
function _set_fitted_parameters!(ff::FitFunction{T}, fitted_parameters::NamedTuple)::Nothing where {T <: AbstractFloat}
    ff.fitted_parameters[:] = collect(T, fitted_parameters)
    nothing
end

function get_fitted_parameters(ff::FitFunction{T, ND, NP}) where {T <: AbstractFloat, ND, NP}
    return NamedTuple{Tuple(ff.parameter_names), NTuple{NP, T}}( ff.fitted_parameters )
end
function get_initial_parameters(ff::FitFunction{T, ND, NP}) where {T <: AbstractFloat, ND, NP}
    return NamedTuple{Tuple(ff.parameter_names), NTuple{NP, T}}( ff.initial_parameters )
end

function println(io::IO, f::FitFunction)
    println(io, "Model: ", f.model)
    println(io, "  fit ranges: ", f.fitranges)
    println(io, "  Parameters: value (initial value)")
    for i in eachindex(f.parameter_names)
        println("    ", f.parameter_names[i], ": ", f.fitted_parameters[i], " (", f.initial_parameters[i],")" )
    end
end
function print(io::IO, f::FitFunction)
    println(io, f)
end
function show(io::IO, f::FitFunction)
    println(io, f)
end
function show(io::IO, ::MIME"text/plain", f::FitFunction)
    show(io, f)
end

@recipe function f(ff::FitFunction; npoints = 501, use_initial_parameters = false, bin_width = 1.0)
    x = collect(range(ff.fitranges[1][1], stop=ff.fitranges[1][2], length=npoints))
    par = use_initial_parameters ? ff.initial_parameters : ff.fitted_parameters
    y = bin_width .* (ff.model(x, collect(par)))
    linecolor --> (use_initial_parameters ? :green : :red)
    label --> (use_initial_parameters ? "Fit model with initial parameters" : "Fit model with fitted parameters")
    x,y
end

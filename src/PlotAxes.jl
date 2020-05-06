module PlotAxes
using AxisArrays
using DataFrames
using Requires
using Dates
using Compat
using Statistics

export asplotable, plotaxes, linrange, logrange, rangefn

struct ContinuousPlotAxis{N}
  step::N
  scale::Symbol
end

struct QualitativePlotAxis end

PlotAxis(x::Vector{<:Number}) = ContinuousPlotAxis(cleanup(x[2] - x[1]),:linear)
PlotAxis(x::AbstractRange{<:Number}) = ContinuousPlotAxis(cleanup(step(x)),:linear)
PlotAxis(x::Vector{<:TimeType}) = ContinuousPlotAxis(cleanup(x[2] - x[1]),:linear)
PlotAxis(x::AbstractRange{<:TimeType}) = ContinuousPlotAxis(cleanup(step(x)),:linear)
PlotAxis(x) = QualitativePlotAxis()

const current_backend = Ref{Union{Nothing,Symbol}}(nothing)
const available_backends = Dict{Symbol,Function}()

"""
    plotaxes(data,[axis1,axis2,etc...];quantize=(100,100,10,10,...))

A rudimentary, quantized display of large arrays of medium dimensionality (up
to about 4-6 dimensions, depending on the backend).

## Plot layout

By default all axes are plotted, but you can explicitly specifiy the names of
the axes as symbols to look at the data averaged across the unlisted
dimensions.

A single axis is plotted as a line. Multiple axes are plotted as a heatmap.
The first two axes specified are the x and y axes of this heatmap. The
remaining axes are plotted along rows and columns of a grid of plots; some
backends allow a row or column to represent multiple dimensions by wrapping a
dimension (e.g. ggplot).

## Display backends

You can change how the plot is displayed using `PlotAxes.set_backend!`.

## Axis Transformations

You can transform axes by a given function by explicitly specifying
axes, and using a `name => function`. Example:

    using PlotAxes, VegaLite
    data = AxisArray(rand(10,10),Axis{:a}(range(0,1,length=10)),
        Axis{:b}(exp.(range(0,1,length=10))))
    df, = PlotAxes.asplotable(data,:a,:b => logrange)

Will result in a plot with a y axis named `logb` with axis values ranging
between 0 and 1.

## Data Quantization

The data are quantized by default to maintain reasonable performance. You can
change the amount of quantization, specifying the maximum number of bins per
axis as a tuple. The order of a quantization tuple is the same as the
axis arguments passed, which defaults to the natural order of the dimensinos
(rows, cols, etc...).

"""
function plotaxes(args...;kwds...)
  if current_backend[] isa Nothing
    error("No backend defined for plot axes. Call `PlotAxes.set_backend`")
  else
    fn = available_backends[current_backend[]]
    fn(args...;kwds...)
  end
end

"""
    set_backend!(symbol)

Set the backend used to display plots when calling `plotaxes`. Call
`list_backends()` for a list of available backends.

Note that, when a package with a backend is loaded (e.g. `using Gadfly`) this
method will be called automatically for the new backend.
"""
function set_backend!(x::Symbol)
  if x ∉ list_backends()
    error("The symbol `$x` is not an available backend. "*
      "Select from one of $(list_backends()).")
  else
    current_backend[] = x
  end
end

"""
    list_backends()

List all currently available backends for plotting with `plotaxes`. This will
be populated with available backends as packages that are supported by
`PlotAxes` are loaded (e.g. via `using`)

# Supported backends

- Gadfly
- VegaLite
- RCall (via ggplot2)

"""
list_backends() = keys(available_backends)

asplotable(x::AbstractArray,args...;kwds...) =
  asplotable(AxisArray(x),args...;kwds...)
asplotable(x::AxisArray;kwds...) = asplotable(x,axisnames(x)...;kwds...)
default_quantize(x) = (100,)
default_quantize(x,y) = (100,100,)
default_quantize(x,y,args...) = (100,100,fill(10,length(args))...)
bin(i,step) = floor(Int,(i-1)/step)+1
bin(ii::CartesianIndex,steps) = CartesianIndex(bin.(ii.I,steps))
# unbin(i,step) = (i-1)*step + 1, i*step

cleanup(x::Number) = x
cleanup(x::TimeType) = x
cleanup(x) = string(x)
default_value(::Type{T}) where T <: Number = zero(float(T))
default_value(::Type{T}) where T <: TimeType = T(0)
default_value(::Type) = ""

function quantize(x::AbstractRange{<:TimeType},steps::Number)
  step = steps[1]
  qsize = bin(length(x),step)
  if qsize >= length(x)
    return x
  end

  range(first(x),last(x),step=(last(x) - first(x))/(qsize-1))
end

function quantize(x,steps)
  qsize = bin.(size(x),steps)
  if all(qsize .>= size(x))
    return x
  end
  if default_value(eltype(x)) isa String
    error("Cannot quantize non-numeric value of type $(eltype(x)).")
  end

  values = fill(default_value(eltype(x)),qsize)
  # TODO: computation of n could be optimized
  # we're taking a "dumb" approach that is easy to understand but inefficient
  n = fill(0,qsize)

  for I in CartesianIndices(x)
    values[bin(I,steps)] += cleanup(x[I])
    n[bin(I,steps)] += 1
  end
  values ./= n
  values
end

axarg_name(x::Symbol) = x
axarg_name((name,fn)::Pair) = name
axarg_name(x) =
  throw(ArgumentError("Unexpected argument. Must be a Symbol or Pair."))

struct RangeFn{F}
  fn::F
  tol::Float64
end
(r::RangeFn)(x) = r.fn(x)
(r::RangeFn)(;tol) = RangeFn(r.fn,tol)

rawnum(x) = x
rawnum(x::TimePeriod) = Dates.value(x)
torange(xs) = range(first(xs),last(xs), length=length(xs))
torange(xs::AbstractArray{<:TimeType}) =
  range(first(xs),last(xs), step=(last(xs) - first(xs))/(length(xs)-1))
rangeable(::Type{<:Number}) = true
rangeable(::Type{<:TimeType}) = true
rangeable(x) = false

function Base.Broadcast.broadcasted(r::RangeFn{typeof(identity)},
  vals::AbstractRange)

  vals
end

function Base.Broadcast.broadcasted(r::RangeFn{typeof(identity)}, vals)
  if rangeable(eltype(vals))
    fnvals = cleanup.(vals)
    std(rawnum.(diff(fnvals))) < r.tol ? torange(fnvals) : fnvals
  else
    vals
  end
end

function Base.Broadcast.broadcasted(r::RangeFn,vals)
  fnvals = r.fn.(cleanup.(vals))
  if rangeable(eltype(fnvals))
    std(rawnum.(diff(fnvals))) < r.tol ? torange(fnvals) : fnvals
  else
    fnvals
  end
end

"""
    rangefn(fn;tol=1e-8)

Transforms `fn` to a ranged function. A ranged function acts just like the
wrapped, single-arugment function except that when it is broadcast over a
number of values and those values are very close to evenly spaced, the
returned values are returned as a Range of exactly evenly spaced values.

# Example

    julia> fn = rangefn(identity,tol=0.1)
    julia> fn.([1,2,3,4.1,5,6,7,8])
    1.0:1.0:8.0

# Tolerance

What counts as "very close" can be adjusted using `tol`. If `std(diff(x))` is
smaller than tol, a `Range` is returned. The tolerance can also be modified
by passing a single keyword argument to the ranged function. That is, the
following is true:

    f = rangefn(fn)
    f(tol=1e-12) == rangefn(fn,tol=1e-12)

"""
rangefn(x;tol=1e-8) = RangeFn(x,tol)

"""
    logrange(x;tol=1e-8)

Log transform of an axis. This is similar to `log`, but will translate
broadcasted output to a `Range` object when std(diff(xs)) < tol.

# See also
- `linrange`
- `rangefn`
"""
const logrange = rangefn(log)

"""
    linrange(x;tol=1e-8)

Linear transform of an axis. This is similar to `identity`, but will translate
broadcasted output to a `Range` object when std(diff(xs)) < tol.

# See also
- `logrange`
- `rangefn`
"""
const linrange = rangefn(identity)

const exact = identity

fn_prefix(x) = ""
fn_prefix(x::typeof(identity)) = "exact_"
fn_prefix(x::RangeFn{typeof(identity)}) = ""
fn_prefix(x::RangeFn) = fn_prefix(x.fn)
function fn_prefix(x::Function)
  name = string(Base.typename(typeof(x)))
  pattern =
    r"typeof\([-[:alpha:]_\u2207][[:word:]\u207A-\u209C!\u2032\u2207]*\)"
  if occursin(pattern,name)
    replace(name,r"typeof\((.*)\)" => s"\1")
  else
    ""
  end
end

# apply any specified transform to the axes
function transform_axes(xs,showax)
  allax = collect(Any,axisnames(xs))
  showax = collect(showax)
  showax_i = indexin(axarg_name.(showax),allax)
  if any(isnothing,showax_i)
    ax = axarg_name(showax[findfirst(isnothing,showax_i)])
    error("Could not find the axis $ax.")
  end
  allax[showax_i] = showax
  axs = map(ax -> transform_axis(xs,ax),allax)

  result = AxisArray(xs.data,axs...)
  result, axisnames(result)[showax_i]
end

# default to a linear "transformation"
transform_axis(xs,name::Symbol) = transform_axis(xs,name => linrange)
function transform_axis(xs,(name,fn)::Pair)
  allvals = axisvalues(xs)
  axisnames(xs)
  n = axisdim(xs,Axis{name})
  vals = fn.(allvals[n])
  newname = Symbol(string(fn_prefix(fn),name))
  Axis{newname}(vals)
end

function asplotable(x::AxisArray,ax1,axes...;
                    quantize=default_quantize(ax1,axes...))
  show_axes = (ax1,axes...)
  x,show_axes = transform_axes(x,show_axes)
  qs = map(axisnames(x)) do ax
    if ax ∈ show_axes
      min(size(x,Axis{ax}),quantize[findfirst(isequal(ax),show_axes)])
    else
      1
    end
  end

  steps = size(x) ./ qs
  vals = PlotAxes.quantize(x,steps)
  axqvals = PlotAxes.quantize.(axisvalues(x),steps)

  df = DataFrame(value = convert(Array{eltype(vals)},vec(vals)))
  for ax in show_axes
    axi = findfirst(isequal(axarg_name(ax)),axisnames(x))
    df[!,ax] .= default_value(eltype(axqvals[axi]))
    for (j,jj) in enumerate(CartesianIndices(vals))
      df[j,ax] = cleanup(axqvals[axi][jj.I[axi]])
    end
  end

  df, map(axv -> PlotAxis(axv),
    map(ax -> axqvals[findfirst(isequal(ax),axisnames(x))],show_axes))
end

# using Gadfly
# include("gadfly.jl")

const AxisId = Union{Symbol,Pair}

function __init__()
  @require RCall="6f49c342-dc21-5d91-9882-a32aef131414" begin
    using .RCall
    @info "Loading RCall ggplot2 backend for `PlotAxes`"
    include("ggplot2.jl")
  end
  @require Unitful="1986cc42-f94f-5a68-af5c-568840ba703d" begin
    using .Unitful
    cleanup(x::Quantity) = ustrip(x)
    default_value(::Type{<:Quantity{T}}) where T = default_value(T)
  end
  @require VegaLite="112f6efa-9a02-5b7d-90c0-432ed331239a" begin
    using .VegaLite
    @info "Loading VegaLite backend for `PlotAxes`"
    include("vegalite.jl")
  end
  @require Gadfly="c91e804a-d5a3-530f-b6f0-dfbca275c004" begin
    using .Gadfly
    @info "Loading Gadfly backend for `PlotAxes`"
    include("gadfly.jl")
  end
end

end # module

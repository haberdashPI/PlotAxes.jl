module PlotAxes
using AxisArrays
using DataFrames
using Requires
using Dates
using Compat

export asplotable, plotaxes

struct ContinuousPlotAxis{N}
  step::N
  scale::Symbol
end

struct QualitativePlotAxis end

PlotAxis(x::Vector{<:Number}) = ContinuousPlotAxis(x[2] - x[1],:linear)
PlotAxis(x::AbstractRange{<:Number}) = ContinuousPlotAxis(step(x),:linear)
PlotAxis(x::Vector{<:TimeType}) = ContinuousPlotAxis(x[2] - x[1],:linear)
PlotAxis(x::AbstractRange{<:TimeType}) = ContinuousPlotAxis(step(x),:linear)
PlotAxis(x) = QualitativePlotAxis()

const current_backend = Ref{Union{Nothing,Symbol}}(nothing)
const available_backends = Dict{Symbol,Function}()

"""
    plotaxes(data,[axis1,axis2,etc...];quantize=(100,100,10,10,...))

A quick and rudimentary display of large arrays of medium dimensionality (up
to about 5 dimensions, depending on the backend). You can change how the
plot is displayed using `PlotAxes.set_backend`.

The data should be an array between 1 and up to about 6 dimensions (how high
you can go depends on the backend). By default all axes are plotted, but you
can explicitly specifiy the names of the axes (as defined by
`AxisArray(data)`) to look at the data averaged across the unlisted
dimensions.

A single axis is plotted as a line. Multiple axes are plotted as a heatmap.
The first two axes specified are the x and y axes of this heatmap. The
remaining axes are plotted along rows and columns of a grid of plots; some
backends allow a row or column to represent multiple dimensions (e.g. ggplot).

The data are quantized by default to maintain reasonable performance. You can
change the amount of quantization, specifying the maximum number of bins per
axis as a tuple. The order of a quantizatio tuple is the same as the
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
set_backend!(x::Symbol) = current_backend[] = x

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

cleanup(x) = x
cleanup(x::Symbol) = string(x)
default_value(::Type{T}) where T = zero(float(T))
default_value(::Type{T}) where T <: TimeType = T(0)
default_value(::Type{T}) where T <: Union{Symbol,String} = ""

function quantize(x::AbstractRange{<:DateTime},steps::Number)
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

axis_hasname(axis::Axis{Name},name) where Name = Name == name
function axis_forname(axes,name)
  pos = findfirst(x -> axis_hasname(x,name),axes)
  if isnothing(pos)
    error("No axis with name $name")
  else
    axes[pos]
  end
end

function asplotable(x::AxisArray,ax1,axes...;
                    quantize=default_quantize(ax1,axes...))
  show_axes = (ax1,axes...)
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

  df = DataFrame(value = vec(vals))
  for ax in show_axes
    axi = findfirst(isequal(ax),axisnames(x))
    if isnothing(axi)
      error("Could not find the axis $ax.")
    end
    df[:,ax] = default_value(eltype(axqvals[axi]))
    for (j,jj) in enumerate(CartesianIndices(vals))
      df[j,ax] = cleanup(axqvals[axi][jj.I[axi]])
    end
  end

  df, map(axv -> PlotAxis(axv),
    map(ax -> axqvals[findfirst(isequal(ax),axisnames(x))],show_axes))
end

# using Gadfly
# include("gadfly.jl")

function __init__()
  @require RCall="6f49c342-dc21-5d91-9882-a32aef131414" begin
    using .RCall
    @info "Loading RCall ggplot2 backend for `PlotAxes`"
    include("ggplot2.jl")
    available_backends[:ggplot2] = ggplot_axes
    set_backend!(:ggplot2)
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
    available_backends[:vegalite] = vlplot_axes
    set_backend!(:vegalite)
  end
  @require Gadfly="c91e804a-d5a3-530f-b6f0-dfbca275c004" begin
    using .Gadfly
    @info "Loading Gadfly backend for `PlotAxes`"
    include("gadfly.jl")
    available_backends[:gadfly] = gadplot_axes
    set_backend!(:gadfly)
  end
end

end # module

module PlotAxes
using AxisArrays
using DataFrames
using Unitful
using Requires

export asplotable, plotaxes

struct ContinuousPlotAxis
  step::Float64
  scale::Symbol
end

struct QualitativePlotAxis end

PlotAxis(x::Vector{<:Number}) = ContinuousPlotAxis(x[2] - x[1],:linear)
PlotAxis(x) = QualitativePlotAxis()

const current_backend = Ref{Union{Nothing,Symbol}}(nothing)
const available_backends = Dict{Symbol,Function}()
function plotaxes(args...;kwds...)
  if current_backend[] isa Nothing
    error("No backend defined for plot axes.")
  else
    fn = available_backends[current_backend[]]
    fn(args...;kwds...)
  end
end

set_backend!(x::Symbol) = current_backend[] = x

asplotable(x::AbstractArray,args...;kwds...) =
  asplotable(AxisArray(x),args...;kwds...)
asplotable(x::AxisArray;kwds...) = asplotable(x,axisnames(x)...;kwds...)
default_quantize(x) = (100,)
default_quantize(x,y) = (100,100,)
default_quantize(x,y,args...) where N = (100,100,fill(10,length(args))...)
bin(i,step) = floor(Int,(i-1)/step)+1
bin(ii::CartesianIndex,steps) = CartesianIndex(bin.(ii.I,steps))
# unbin(i,step) = (i-1)*step + 1, i*step

function quantize(x,steps)
  qsize = bin.(size(x),steps)
  if all(qsize .>= size(x))
    return x
  end
  values = fill(zero(float(eltype(x))),qsize)
  # TODO: computation of n could be optimized
  # we're taking a "dumb" approach that is easy to understand but inefficient
  n = fill(0,qsize)

  for I in CartesianIndices(x)
    values[bin(I,steps)] += x[I]
    n[bin(I,steps)] += 1
  end
  values ./= n
  values
end

axis_hasname(axis::Axis{Name},name) where Name = Name == name
function axis_forname(axes,name)
  pos = findfirst(x -> axis_hasname(x,name),axes)
  if pos isa Nothing
    error("No axis with name $name")
  else
    axes[pos]
  end
end

cleanup(x::Number) = x
cleanup(x::Quantity) = ustrip(x)
cleanup(x) = string(x)
default(::Type{T}) where T<:Number = zero(T)
default(x) = ""

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
  axqvals = PlotAxes.quantize.(map(x -> cleanup.(x),axisvalues(x)),steps)

  df = DataFrame(value = vec(vals))
  for ax in show_axes
    axi = findfirst(isequal(ax),axisnames(x))
    df[:,ax] = default(eltype(axqvals[axi]))
    for (j,jj) in enumerate(CartesianIndices(vals))
      df[j,ax] = axqvals[axi][jj.I[axi]]
    end
  end

  df, map(axv -> PlotAxis(axv),axqvals)
end

# using Gadfly
# include("gadfly.jl")

function __init__()
  @require RCall="6f49c342-dc21-5d91-9882-a32aef131414" begin
    using .RCall

    ggplot_axes(axis::AbstractArray) = error("Not implemented.")
  end
  @require VegaLite="112f6efa-9a02-5b7d-90c0-432ed331239a" begin
    using .VegaLite
    include("vegalite.jl")
    available_backends[:vegalite] = vlplot_axes
    set_backend!(:vegalite)
  end
  @require Gadfly="c91e804a-d5a3-530f-b6f0-dfbca275c004" begin
    using .Gadfly
    include("gadfly.jl")
    available_backends[:gadfly] = gadplot_axes
    set_backend!(:gadfly)
  end
end

end # module

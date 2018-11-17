module PlotAxes
using AxisArrays
using DataFrames
using Unitful
using Requires

export asplotable, quantize, bin, quantstep, PlotAxis

mutable struct PlotAxis
  step::Float64
  scale::Symbol
end

asplotable(x::AbstractArray;kwds...) = asplotable(AxisArray(x);kwds...)
asplotable(x::AxisArray;kwds...) = asplotable(x,axisnames(x)...;kwds...)
default_quantize(x::AbstractArray) = default_quantize(size(x))
default_quantize(x::NTuple{1,Int}) = min.(x,(100,))
default_quantize(x::NTuple{2,Int}) = min.(x,(100,100,))
default_quantize(x::NTuple{N,Int}) where N = min.(x,(100,100,fill(10,N-2)...))
bin(i,step) = floor(Int,(i-1)/step)+1
bin(ii::CartesianIndex,steps) = CartesianIndex(bin.(ii.I,steps))
# unbin(i,step) = (i-1)*step + 1, i*step

function quantize(x,steps)
  qsize = bin.(size(x),steps)
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

# TODO: I need to use min on the quantize size no in the default quantile
# function but inside `asplotable` so that user specified quantization works
function asplotable(x::AxisArray,ax1,axes...;quantize_size=default_quantize(x))
  steps = size(x) ./ quantize_size
  vals = quantize(x,steps)
  axvals = axisvalues(axis_forname.(Ref(AxisArrays.axes(x)),(ax1,axes...))...)
  axqvals = quantize.(map(x -> ustrip.(x),axvals),steps)

  df = DataFrame(value = vec(vals))
  for (i,ax) in enumerate((ax1,axes...))
    df[:,ax] = NaN
    for (j,jj) in enumerate(CartesianIndices(vals))
      df[j,ax] = axqvals[i][jj.I[i]]
    end
  end

  df, map(axv -> PlotAxis(axv[2] - axv[1],:linear),axqvals)
end

function __init__()
  @require RCall="6f49c342-dc21-5d91-9882-a32aef131414" begin
    using .RCall

    ggplot_axes(axis::AbstractArray) = error("Not implemented.")
  end
  @require VegaLite="112f6efa-9a02-5b7d-90c0-432ed331239a" begin
    using .VegaLite
    include("vegalite.jl")
  end
end

end # module

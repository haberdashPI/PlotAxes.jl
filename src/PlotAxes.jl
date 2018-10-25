module PlotAxes
using AxisArrays
using DataFrames
using Unitful

export asplotable, quantize, bin, quantstep

asplotable(x::AxisArray;kwds...) = asplotable(x,axisnames(x)...;kwds...)
default_quantize(x::AbstractArray) = default_quantize(size(x))
default_quantize(x::NTuple{1,Int}) = (100,)
default_quantize(x::NTuple{2,Int}) = (100,100,)
default_quantize(x::NTuple{N,Int}) where N = (100,100,fill(10,N-2)...)
bin(i,step) = floor(Int,(i-1)/step)+1
bin(ii::CartesianIndex,steps) = CartesianIndex(bin.(ii.I,steps))
# unbin(i,step) = (i-1)*step + 1, i*step

function quantize(x,qsize)
  steps = size(x) ./ qsize
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

function asplotable(x::AxisArray,ax1,axes...;quantize_size=default_quantize(x),
                    return_size=false)
  vals = quantize(x,quantize_size)
  axvals = axisvalues(axis_forname.(Ref(AxisArrays.axes(x)),(ax1,axes...))...)
  axqvals = quantize.(map(x -> ustrip.(x),axvals),quantize_size)

  df = DataFrame(value = vec(vals))
  for (i,ax) in enumerate((ax1,axes...))
    df[:,ax] = NaN
    for (j,jj) in enumerate(CartesianIndices(vals))
      df[j,ax] = axqvals[i][jj.I[i]]
    end
  end

  if return_size
    df, size(vals)
  else
    df
  end
end

function __init__()
  @require RCall="6f49c342-dc21-5d91-9882-a32aef131414" begin
    using .RCall

    ggplot_axes(axis::AbstractArray) = error("Not implemented.")
  end
  @require VegaLite="112f6efa-9a02-5b7d-90c0-432ed331239a" begin
    using .VegaLite
    vlplot_axes(x::AxisArray;kwds) = vlplot_axes(x,axisnames(x)...;kwds...)
    function vlplot_axes(data::AxisArray,x,y;kwds...)
      df,qsize = asplotable(data,x,y;return_size=true,kwds...)
      df |>
        @vlplot(:rect, width=300, height=300, 
                x={field=x,typ="quantitative", bin={maxbins=qsize[1]}},
                y={field=y,typ="quantitative", bin={maxbins=qsize[2]}},
                color={field=:value, aggregate="mean", typ="quantitative"})
    end
    # TODO: add 1, 3 and 4 dimensional plots
  end
end

end # module

module VegaPlotAxes

using .VegaLite
vlplot_axes(x::AxisArray;kwds) = vlplot_axes(x,axisnames(x)...;kwds...)
function vlplot_axes(data::AxisArray,x,y;kwds...)
    df,qsize = asplotable(data,x,y;return_size=true,kwds...)
    df |>
      @vlplot(:rect, width=300, height=300,
              x={field=x,typ="ordingal"},
              y={field=y,typ="ordingal"},
              color={field=:value, aggregate="mean", typ="quantitative"})
end

# TODO: add 1, 3 and 4 dimensional plots

end # module

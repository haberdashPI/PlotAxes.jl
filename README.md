# PlotAxes

PlotAxes is intended to simplify the visualization of medium dimensional data
(e.g. 4-5 dimensions max) during an interactive session. (It is *not*
intended as a full fledged plotting API for publication quality graphs.)

It can be used to plot an `AbstractArray` or
[`AxisArray`](https://github.com/JuliaArrays/AxisArrays.jl). Supported
backends are described in the documentation of `PlotAxes.list_backends`. With
an `AxisArray` the axes will be properly labeled.

To use it, just call `plotaxes`, as follows.

```julia
using PlotAxes
using Gadfly # replace with VegaLite or RCall as desired

plotaxes(AxisArray(rand(10,10,4,2),:time,:freq,:age,:gender))
```

For more details, see the documentation for `plotaxes` (ala ? at the REPL).

## Status

This is working for display of data in my day-to-day work. There are plenty
of features that might be added or backends that could be implemented.

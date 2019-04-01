# PlotAxes

An interface to plot an `AbstractArray` or
[`AxisArray`](https://github.com/JuliaArrays/AxisArrays.jl) for quickly
plotting data using a grammar-of-graphics approach. You can use
[`Gadfly`](http://gadflyjl.org/stable/) or
[`VegaLite.jl`](https://github.com/fredo-dedup/VegaLite.jl) to plot them.

PlotAxes is mostly not intended for publication quality plots, but rather
reduces the time to generate a quick and dirty plot of medium dimensional
data (e.g. 4-5 dimensions at most) during exploratory analyses.

To use it, just call `plotaxes` as follows.

```julia
using PlotAxes
using Gadfly

plotaxes(rand(10,10,4,4))
```

## Status

This is a relatively incomplete package at this point. It works for my needs,
in the few cases I have tested, but there is still some work to do to make
this accessible and easy to use. Right now, your best bet for understanding
how to use all the features of this package is to read all of the code:
there's not very much of it.

## TODO

* Improve documentation.
* Implement `ggplot` plots using `RCall`.
* Improve the flexibility of the interface.

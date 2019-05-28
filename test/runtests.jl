using Test
using PlotAxes
using Dates

@tesset "Can generate plotable data" begin
  data = AxisArray(rand(10,10,2,2),:a,:b,:c,:d)
  df = PlotAxes.asplotable(data)
  @test size(df,2) == length(data)
  @test :a ∈ names(df)
  @test :b ∈ names(df)
  @test :c ∈ names(df)
  @test :d ∈ names(df)
  @test :value ∈ names(df)

  data = AxisArray(rand(10,10,2),:a,:b,:c)
  df = PlotAxes.asplotable(data)
  @test size(df,1) == length(data)

  data = AxisArray(rand(10,10),:a,:b)
  df = PlotAxes.asplotable(data)
  @test size(df,1) == length(data)

  data = AxisArray(rand(10),:a)
  df = PlotAxes.asplotable(data)
  @test size(df,1) == length(data)

  data = AxisArray(rand(10),Axis{:time}(DateTime(1961,1,1):Day(1):DateTime(1961,1,10)))
  df = PlotAxes.asplotable(data)
  @test size(df,1) == length(data)

  df = PlotAxes.asplotable(rand(10,10),quantize=(5,5))
  @test size(df,1) == 25
end

@testset "Can use backends" begin
  plotaxes(data)

  using Gadfly
  data = AxisArray(rand(10,10,2,2),:a,:b,:c,:d)
  @assert PlotAxes.current_backend[] == :gadfly

  using VegaLite
  plotaxes(data)
  @assert PlotAxes.current_backend[] == :vegalite

  using RCall
  R"install.packages('ggplot2',repos='https://cran.r-project.org')"
  plotaxes(data)
  @assert PlotAxes.current_backend[] == :ggplot2
end



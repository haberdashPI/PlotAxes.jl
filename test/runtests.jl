using Test
using PlotAxes
using Dates
using AxisArrays
using Unitful

macro handle_RCall_failure(body)
  quote
    try
      $(esc(body))
    catch e
      if e isa ErrorException && Sys.iswindows() &&
        startswith(e.msg,"Failed to precompile RCall ")
        @warn "Failed to properly install RCall; currently fails on Windows "*
        "when you use Conda to install R. You can fix this by manually "*
        "installing and downloading R and then typing ]build RCall at the "*
        "julia REPL."
      else
        rethrow(e)
      end
    end
  end
end

@testset "PlotAxes" begin

@testset "Can generate plotable data" begin
  data = AxisArray(rand(10,10,2,2),:a,:b,:c,:d)
  df, = PlotAxes.asplotable(data)
  @test size(df,1) == length(data)
  @test :a ∈ propertynames(df)
  @test :b ∈ propertynames(df)
  @test :c ∈ propertynames(df)
  @test :d ∈ propertynames(df)
  @test :value ∈ propertynames(df)

  data = AxisArray(rand(10,10,2),:a,:b,:c)
  df, = PlotAxes.asplotable(data)
  @test size(df,1) == length(data)

  data = AxisArray(rand(10,10),:a,:b)
  df, = PlotAxes.asplotable(data)
  @test size(df,1) == length(data)

  data = AxisArray(rand(10),:a)
  df, = PlotAxes.asplotable(data)
  @test size(df,1) == length(data)

  @test logrange.(exp.([1,2,3])) isa AbstractRange
  @test linrange.([1,2,3]) isa AbstractRange

  data = AxisArray(rand(10,10),Axis{:a}(range(0,1,length=10)),
    Axis{:b}(exp.(range(0,1,length=10))))
  df, = PlotAxes.asplotable(data,:a,:b => logrange)
  @test size(df,1) == length(data)
  @test :logb in propertynames(df)
  @test sort(unique(df.logb)) ≈ range(0,1,length=10)

  data = AxisArray(rand(10,10),Axis{:a}(exp.(range(0,1,length=10))),
    Axis{:b}(range(0,1,length=10)))
  df, = PlotAxes.asplotable(data,:a => logrange,:b)
  @test size(df,1) == length(data)
  @test :loga in propertynames(df)
  @test sort(unique(df.loga)) ≈ range(0,1,length=10)

  @test_throws(ErrorException("Could not find the axis c."),
    PlotAxes.asplotable(data,:c))

  @test_throws(ArgumentError("Unexpected argument. Must be a Symbol or Pair."),
    PlotAxes.asplotable(data,:a,df))

  data = AxisArray(rand(10),Axis{:time}(DateTime(1961,1,1):Day(1):DateTime(1961,1,10)))
  df, = PlotAxes.asplotable(data)
  @test size(df,1) == length(data)

  data = AxisArray(rand(10),Axis{:time}(collect(DateTime(1961,1,1):Day(1):DateTime(1961,1,10))))
  df, = PlotAxes.asplotable(data)
  @test size(df,1) == length(data)

  data = AxisArray(rand(3),Axis{:time}([DateTime(1961,1,1),DateTime(1961,1,3),DateTime(1961,1,10)]))
  df, = PlotAxes.asplotable(data)
  @test size(df,1) == length(data)

  data = AxisArray(rand(10),Axis{:time}(DateTime(1961,1,1):Day(1):DateTime(1961,1,10)))
  df, = PlotAxes.asplotable(data,quantize=(5,))
  @test size(df,1) == 5

  data = AxisArray(rand(4),Axis{:tuple}([(1,2),(1,3),(2,5),(2,6)]))
  df, = PlotAxes.asplotable(data,quantize=(5,))
  msg = "Cannot quantize non-numeric value of type Tuple{Int64,Int64}."
  @test size(df,1) == 4
  @test_throws(ErrorException(msg), PlotAxes.asplotable(data,quantize=(3,)))

  data = AxisArray(rand(10),Axis{:time}(range(0u"s",1u"s",length=10)))
  df, = PlotAxes.asplotable(data,quantize=(5,))
  @test size(df,1) == 5
  @test df.time isa Array

  df, = PlotAxes.asplotable(data,quantize=(20,))
  @test size(df,1) == length(data)
  @test df.time isa Array

  data = AxisArray(rand(10,5),Axis{:time}(range(0u"s",1u"s",length=10)),
    Axis{:freq}(range(10u"Hz",50u"Hz",length=5)))
  df, = PlotAxes.asplotable(data)
  @test size(df,1) == length(data)

  df, = PlotAxes.asplotable(rand(10,10),quantize=(5,5))
  @test size(df,1) == 25
end

allowed_dimensions = Dict(:ggplot2 => 6,:vegalite => 4,:gadfly => 4)
@testset "Can use backends" begin
  @test_throws ErrorException PlotAxes.set_backend!(:foo)

  msg = "No backend defined for plot axes. Call `PlotAxes.set_backend`"
  @test_throws ErrorException(msg) plotaxes(rand(10))

  using Gadfly
  @test PlotAxes.current_backend[] == :gadfly

  using VegaLite
  @test PlotAxes.current_backend[] == :vegalite

  @handle_RCall_failure begin
    using RCall
    @test PlotAxes.current_backend[] == :ggplot2
  end

  alldata = [
    AxisArray(rand(10),:a),
    AxisArray(rand(10,10),:a,:b),
    AxisArray(rand(10,10,2),:a,:b,:c),
    AxisArray(rand(10,10,2,2),:a,:b,:c,:d),
    AxisArray(rand(10,10,2,2,2),:a,:b,:c,:d,:e),
    AxisArray(rand(10,10,2,2,2,2),:a,:b,:c,:d,:e,:f),
    AxisArray(rand(10,10,2,2,2,2,2),:a,:b,:c,:d,:e,:f,:h)
  ]

  for b in PlotAxes.list_backends()
    title = string("Backend ",b)
    @testset "$title" begin
      for d in alldata
        PlotAxes.set_backend!(b)
        if allowed_dimensions[b] >= ndims(d)
          result = plotaxes(d)
          @test result != false
        else
          @test_throws ErrorException plotaxes(d)
        end

        result = if ndims(d) == 3
          plotaxes(d,:a,:b => logrange,:c)
        elseif ndims(d) == 2
          plotaxes(d,:a,:b => logrange)
        elseif ndims(d) == 1
          plotaxes(d,:a => logrange)
        end
        @test result != false
      end
    end
  end
end

end

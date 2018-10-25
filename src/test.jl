x = AxisArray([i*j for i in 1:1000, j in 1:1000],
      Axis{:time}(range(0,stop=1,length=1000)),
      Axis{:freq}(range(1,stop=100,length=1000)))

df, steps = asplotable(x,quantize_size=(50,50),return_steps=true)

df |>
  @vlplot(:rect, width=300, height=300,
          x={field=:time,typ="quantitative", bin={step=steps[1]}},
          y={field=:freq,typ="quantitative", bin={step=steps[2]}},
          color={field=:value, aggregate="mean", typ="quantitative"},
          config={view={stroke="transparent"},
                  scale={bandPaddingInner=0, bandPaddingOuter=0},
                  range={heatmap={scheme="viridis"}}})

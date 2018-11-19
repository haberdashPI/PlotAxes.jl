export gadplot_axes

function gadplot_axes(data,args...;colors=Scale.color_continuous,kwds...)
  df, axes = asplotable(data,args...;kwds...)
  gadplot_axes_(df,axes,names(df)[2:end]...;colors=colors)
end

function gadplot_axes_(df,axes,x;colors)
  plot(df,x=x,y=:value,Geom.line)
end

function gadplot_axes_(df,axes,x,y;colors)
  plot(df,x=x,y=y,color=:value,Geom.rectbin,colors)
end

function gadplot_axes_(df,axes,x,y,z;colors)
  plot(df,x=x,y=y,color=:value,xgroup=z,
       Geom.subplot_grid(Geom.rectbin),colors)
end

function gadplot_axes_(df,axes,x,y,z,w;colors)
  plot(df,x=x,y=y,color=:value,xgroup=z,ygroup=w,
       Geom.subplot_grid(Geom.rectbin),colors)
end
function gadplot_axes_(df,axes,args...;kwds...)
  error("Plotting data with $(length(axes)) dims along
        $(length(args)) axes is not supported.")
end

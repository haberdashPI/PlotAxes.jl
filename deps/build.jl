using Pkg

@static if lowercase(get(ENV, "CI", "false")) == "true"
  ENV["R_HOME"]="*"
  # the latest Conda master simplifies the specification of conda channels
  pkg"add RCall Conda#fb9a112921656b9d38fbc92ef7dae540f1ba182b"
  pkg"build RCall"
  using Conda
  Conda.add("r-ggplot2",channel="r")
end

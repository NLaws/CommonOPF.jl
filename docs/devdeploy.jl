using LiveServer

"""
Run this script to locally host the CommonOPF.jl documentation.
NOTE you have to dev CommonOPF in the `docs` environment to get local changes. 

e.g. 
```julia
[~/.julia/dev/CommonOPF/docs]
(CommonOPF) pkg> activate .
(CommonOPF) pkg> dev CommonOPF
julia> include("devdeploy.jl")
[ Info: Precompiling CommonOPF [73c867df-75f8-459f-abd8-059b58de1e18]
...
✓ LiveServer listening on http://localhost:8000/ ...
  (use CTRL+C to shut down)
```
"""
function devbuildserve()
    rm("build", force=true, recursive=true)
    include("make.jl")
    serve(dir="build")
end

devbuildserve()
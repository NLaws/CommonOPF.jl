using Documenter
using CommonOPF

makedocs(
    sitename = "CommonOPF",
    format = Documenter.HTML(),
    modules = [CommonOPF],
    workdir = joinpath(@__DIR__, ".."),
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
deploydocs(
    repo = "github.com/NLaws/CommonOPF.jl.git"
)

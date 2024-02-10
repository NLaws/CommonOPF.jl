using Documenter
using CommonOPF

makedocs(
    sitename = "CommonOPF",
    format = Documenter.HTML(),
    modules = [CommonOPF],
    workdir = joinpath(@__DIR__, ".."),
    pages = [
        "User Documentation" => "index.md",
        "The Network Model" => "network.md",
        "Results" => "results.md",
        "Methods" => "methods.md",
        "Math" => "math.md",
        "Developer" => "developer.md"
    ],
    warnonly = true,  # TODO rm this and fix all the docs
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
deploydocs(
    repo = "github.com/NLaws/CommonOPF.jl.git"
)

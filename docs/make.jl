using Documenter
using CommonOPF

makedocs(
    sitename = "CommonOPF",
    format = Documenter.HTML(),
    modules = [CommonOPF],
    workdir = joinpath(@__DIR__, ".."),
    pages = [
        "User Documentation" => "index.md",
        "Inputs" => "inputs.md",
        "The Network Model" => "network.md",
        "Variables for Mathematical Programs" => "variables.md",
        "Results" => "results.md",
        "Methods" => [
            "impedance_and_admittance.md",
            "graph_methods.md",
            "decomposition.md"
        ],
        "Math" => "math.md",
        "Developer" => [
            "developer/developer.md",
            "developer/impedance_and_admittance_methods.md",
            "developer/input_validation.md",
            "developer/jump_variables.md",
        ]
    ],
    warnonly = true,  # TODO rm this and fix all the docs
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
deploydocs(
    repo = "github.com/NLaws/CommonOPF.jl.git"
)

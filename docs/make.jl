using Documenter, NEMStorageUnderUncertainty

makedocs(;
    sitename="NEM Storage Under Uncertainty",
    pages=Any[
        "Home" => "index.md",
        "Storage Devices" => "devices.md",
        "Price Data Compilers" => "data.md",
        "Model Formulations" => "formulations.md",
        "Model Components" => [
            "variables.md", "constraints.md", "objectives.md", "build.md"
        ],
        "Simulations" => "simulations.md",
    ],
)

deploydocs(; repo="github.com/prakaa/NEMStorageUnderUncertainty.jl.git")

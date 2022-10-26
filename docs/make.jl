using Documenter, NEMStorageUnderUncertainty

makedocs(;
    sitename="NEM Storage Under Uncertainty",
    authors="Abhijith (Abi) Prakash",
    pages=Any[
        "Home" => "index.md",
        "Storage Devices" => "devices.md",
        "Price Data Compilers" => "data.md",
        "Formulations" => "model_formulations.md",
        "Model Components" => ["variables.md", "constraints.md", "objectives.md"],
    ],
)

deploydocs(; repo="github.com/prakaa/NEMStorageUnderUncertainty.jl.git")

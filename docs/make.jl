using Documenter, NEMStorageUnderUncertainty

makedocs(;
    sitename="NEM Storage Under Uncertainty",
    authors="Abhijith (Abi) Prakash",
    pages=Any[
        "Home" => "index.md",
        "Storage Devices" => "devices.md",
        "Price Data Compilers" => "data.md",
        "Model Components" => ["base_model.md", "variables.md", "constraints.md"],
    ],
)

deploydocs(; repo="github.com/prakaa/NEMStorageUnderUncertainty.jl.git")

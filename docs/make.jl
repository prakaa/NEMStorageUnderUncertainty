using Documenter, NEMStorageUnderUncertainty

makedocs(
    sitename="NEM Storage Under Uncertainty",
    pages = Any[
        "Home" => "index.md",
        "Storage Devices" => "devices.md"
    ])

deploydocs(
    repo = "github.com/prakaa/NEMStorageUnderUncertainty.jl.git",
)

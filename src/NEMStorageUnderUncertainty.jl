module NEMStorageUnderUncertainty

# Exports
## Storage Devices
export BESS

# Imports
import MathOptInterface: OptimizerWithAttributes
import Parquet: read_parquet

# Using
using DataFrames
using Dates
using Impute: Impute
using JuMP: JuMP
using Logging
using ProgressMeter
using JLD2

#DocStringExtensions Templates
using DocStringExtensions
@template (FUNCTIONS, METHODS) = """
                                 $(TYPEDSIGNATURES)

                                 # Summary
                                 $(DOCSTRING)

                                 # Methods
                                 $(METHODLIST)
                                 """
@template TYPES = """
                  $(TYPEDEF)
                  $(TYPEDFIELDS)
                  $(DOCSTRING)
                  """

# Includes
## Storage Devices
include("devices.jl")
## Data Management
include("data.jl")
## Model Components
include("model/formulations.jl")
include("model/variables.jl")
include("model/constraints.jl")
include("model/objectives.jl")
include("model/build_and_run.jl")
## Simulations
include("simulations.jl")
## Utilities
include("simulation_utils.jl")

end

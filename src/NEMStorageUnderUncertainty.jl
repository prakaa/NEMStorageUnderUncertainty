module NEMStorageUnderUncertainty

# Exports
## Storage Devices
export BESS

# Imports
import Dates: DateTime, unix2datetime, Hour, Minute
import ParameterJuMP as PJ
import Parquet: read_parquet

# Using
using DataFrames
using Impute: Impute
using JuMP: JuMP
using ProgressMeter

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
include("model/build.jl")
## Simulations
include("simulations.jl")
## Utilities
include("utils.jl")

end

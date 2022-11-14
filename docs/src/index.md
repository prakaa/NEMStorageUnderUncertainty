# NEMStorageUnderUncertainty Documentation

A modelling framework built to explore the impact of future market information (forecasts) on the operation of energy storage in the National Electricity Market (NEM).

Terminology used in this repo is outlined in [Terminology](@ref)

These pages document the source code used to run storage simulations:

  * [Storage Devices](@ref) contains the storage devices modelled
  * [Price Data Compilers](@ref) documents the functions that compile, clean and assemble actual and forecast price data for use in models/simulations
  * [Model Formulations](@ref) documents the mathematical optimisation problems formulated for each model horizon
  * [Simulation Functions](@ref) documents the code that is used to string model horizons together and simulate the rolling horizon/optimal control problem
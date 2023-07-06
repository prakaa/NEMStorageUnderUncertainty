# NEMStorageUnderUncertainty

[![CI](https://github.com/prakaa/NEMStorageUnderUncertainty/actions/workflows/CI.yml/badge.svg)](https://github.com/prakaa/NEMStorageUnderUncertainty/actions/workflows/CI.yml)
[![codecov](https://codecov.io/gh/prakaa/NEMStorageUnderUncertainty/branch/master/graph/badge.svg?token=K14NYRGFPX)](https://codecov.io/gh/prakaa/NEMStorageUnderUncertainty)
[![Documentation](https://github.com/prakaa/NEMStorageUnderUncertainty/actions/workflows/Docs.yml/badge.svg)](https://prakaa.github.io/NEMStorageUnderUncertainty/dev/)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)

This repository contains the following:
  1. Analysis of historical prices and of (30-minute) pre-dispatch and 5-minute pre-dispatch price "forecast"[^1] errors from the Australian National Electricity Market (NEM).
  2. Source code and results from simulations that investigate how imperfect foresight affects storage arbitrage operation and revenues. This modelling uses historical actual price data and price forecasts from pre-dispatch & 5-minute pre-dispatch.
  
Though we are currently writing up the results from this study, you can still use this repository to access the model source code, documentation and results in the form of charts. 

[^1]: We use the term *"forecast"* loosely, especially given that these *"forecasts"* change once participants update offer information (e.g. through rebidding) or submit revised resource availabilities and energy constraints. Both of these are intended outcomes of these *"ahead processes"*, which are run by the Australian Energy Market Operator (AEMO) to provide system and market information to participants to inform their decision-making. However, to avoid confusion and to ensure consistency with the language used by AEMO, we use the term *"forecast"*.

## Analysis of prices & price forecast errors in the NEM

All charts produced from the analysis of prices & price forecast errors in the NEM can be found [here](price-characterisation/plots). A couple of the most interesting charts are linked below.

- [This chart](./price-characterisation/plots/historical/spreads/historical_daily_price_spreads.pdf) shows that historical daily price spreads ($p_{max} - p_{min}$ for each day) have been increasing over time in each region o f the NEM
- [This chart](./price-characterisation/plots/historical/spreads/tod.pdf) shows the median, 5th and 95th percentile prices in NSW for each dispatch interval in 2021 (i.e. by time of day)
- [This chart](./price-characterisation/plots/historical/errors/price_errors_nemwide_2012_2021.pdf) shows how price forecast errors in the day-ahead and hour-ahead horizons have increased in the past few years. Months with a high number of large price errors do not appear to necessarily coincide with market or system events

### Source code installation

1. Install poetry
2. Use poetry within [price-characterisation](./price-characterisation) to install the required dependencies
3. Run `.py` plot scripts

## Simulating storage operation under uncertainty

Study terminology and detailed methodology (e.g. objective functions, constraints, etc.) can be found in the [source code documentation](https://prakaa.github.io/NEMStorageUnderUncertainty/).

### Overview of methodology

1. At a decision point, optimise a battery energy storage system (BESS) according to model formulation (objective function) for duration of lookahead horizon using 5-minute pre-dispatch (5MPD) and (30-minute) pre-dispatch (PD) price "forecasts"
    - Remove PD forecasts that overlap with 5MPD and only use 5MPD within hour ahead
2. Take results but only *bind* the dispatch decision of next interval (i.e. 5 minutes ahead)
3. Roll horizon forward (rolling horizon optimal control at a frequency of 5 minutes) & repeat until entire year simulated
4. Repeat steps 1-3 with actual price data
5. Run perfect foresight model, where BESS is optimised across entire year with actual data in one go

![Simulation procedure](docs/src/sim_example.png)

### Formulations

A variety of formulations (objective functions) are modelled. Refer to [this section](https://prakaa.github.io/NEMStorageUnderUncertainty/dev/formulations/) of the documentation for more detail.

### Values of perfect information (VPI) and perfect foresight (VPF)

**Value of perfect information**: What is the additional benefit (revenue) that a participant
could gain if they were to know exactly what the market prices will be in the *lookahead
horizon*.

```math
VPI = \textrm{Revenue}_\textrm{Actual Data Simulation} -  \textrm{Revenue}_\textrm{Forecast Data Simulation}$$
```

**Value of perfect foresight**: What is the additional benefit (revenue) that a participant
could gain if they were to know exactly what the market prices will be *over the entire
year*

```math
VPF = \textrm{Revenue}_\textrm{Perfect Foresight} -  \textrm{Revenue}_\textrm{Forecast Data Simulation}
```

### Results

All charts produced from the analysis of simulation results can be found [here](results/plots). A couple of the most interesting charts are linked below.

- [This chart](results/plots/revenues/NSW_100.0MWh_100.0MW_allformulations_revenue.pdf) shows absolute revenues for a 1 hour duration BESS (100 MW/100 MWh) for different lookahead horizons and modelled formulations
- [This chart](results/plots/operation/NSW_100MW_100MWh_Revenue_Lookahead.pdf) shows how under imperfect foresight, a 1 hour duration BESS can miss significant discharge opportunities or make very poor charge decisions
- [This chart](results/plots/vpi_vpf/NSW_100_allformulations_vpi_vpf.pdf) shows VPIs and VPFs for BESS with durations of 15 minutes, 1 hour and 4 hours across lookaheads and modelled formulations
- [This chart](results/plots/throughput/NSW_100_arbitrage_throughputpenalty_no_degradation_600000_throughputs.pdf) shows the cumulative throughput of BES with durations of 15 minutes, 1 hour and 4 hours (all with modelled throughput penalty that amortises a BESS capital cost of 600,000 AUD/MWh across BESS lifetime throughput) across the modelled year (2021).

### Source code installation

#### Julia environment

1. Hit `]` to enter package mode
2. With this project as the current directory, enter:
  ```julia
  activate .
  ```
3. Then instantiate the project
  ```julia
  instantiate
  ```
#### Obtain price data

We make use of [`NEMOSIS`](https://github.com/UNSW-CEEM/NEMOSIS) and [`NEMSEER`](https://github.com/UNSW-CEEM/NEMSEER) to obtain actual and forecast regional price data, respectively.

To populate `data/` with the required data, run (with this project as the current directory):
```bash
make get_NEM_data
```
This command installs the mini-package located in `data_scripts/`, installs the `get_data.py` script as a console command and then runs the console command to obtain the data

- The Makefile assumes Python 3 is installed on your machine.

## Author & licenses

This modelling framework and its associated case studies were developed by Abhijith (Abi) Prakash, PhD Candidate at the UNSW Collaboration on Energy and Environmental Markets.

The source code from this work is licensed under the terms of [GNU GPL-3.0-or-later licences](./LICENSE).

The results (generated plots) and the content within the documentation for this project is licensed under a [Creative Commons Attribution 4.0 International License](http://creativecommons.org/licenses/by/4.0/).

## Acknowledgements

Data used in this study were made accessible by [`NEMOSIS`](https://github.com/UNSW-CEEM/NEMOSIS) and [`NEMSEER`](https://github.com/UNSW-CEEM/NEMSEER).

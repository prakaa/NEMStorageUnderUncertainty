# NEMStorageUnderUncertainty

[![CI](https://github.com/prakaa/NEMStorageUnderUncertainty/actions/workflows/CI.yml/badge.svg)](https://github.com/prakaa/NEMStorageUnderUncertainty/actions/workflows/CI.yml)
[![codecov](https://codecov.io/gh/prakaa/NEMStorageUnderUncertainty/branch/master/graph/badge.svg?token=K14NYRGFPX)](https://codecov.io/gh/prakaa/NEMStorageUnderUncertainty)
[![Documentation](https://github.com/prakaa/NEMStorageUnderUncertainty/actions/workflows/Docs.yml/badge.svg)](https://github.com/prakaa/NEMStorageUnderUncertainty/actions/workflows/Docs.yml)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)

Modelling to investigate how imperfect foresight and information (via actual and forecast energy prices) affects storage operation. 

Case studies using data from the National Electricity Market (NEM). These data include:

- Actual regional prices data from the NEM
- Forecast regional prices produced by AEMO. Forecasts used in this study include:
  - (30-minute) pre-dispatch
  - 5-minute pre-dispatch

## Documentation

Study terminology and methodology/code documentation can be found in the [documentation](https://prakaa.github.io/NEMStorageUnderUncertainty/).

## Installation

### Julia environment

1. Hit `]` to enter package mode
2. With this project as the current directory, enter:
  ```julia
  activate .
  ```
3. Then instantiate the project
  ```julia
  instantiate
  ```

### Obtain price data

We make use of [`NEMOSIS`](https://github.com/UNSW-CEEM/NEMOSIS) and [`NEMSEER`](https://github.com/UNSW-CEEM/NEMSEER) to obtain actual and forecast regional price data, respectively.

To populate `data/` with the required data, run (with this project as the current directory):
```bash
make get_NEM_data
```
This command installs the mini-package located in `data_scripts/`, installs the `get_data.py` script as a console command and then runs the console commanad to obtain the data

- The Makefile assumes Python 3 is installed on your machine.

## Author and Acknowledgements

This modelling framework and its associated case studies were developed by Abhijith (Abi) Prakash, PhD Candidate at the UNSW Collaboration on Energy and Environmental Markets.

Data used in this study were made accessible by [`NEMOSIS`](https://github.com/UNSW-CEEM/NEMOSIS) and [`NEMSEER`](https://github.com/UNSW-CEEM/NEMSEER).

# %% [markdown]
# # Price Analysis

# %% [markdown]
# ## Key imports

# %%
# standard libraries
import logging
from datetime import datetime, timedelta
from pathlib import Path

# NEM data libraries
# NEMOSIS for actual demand data
# NEMSEER for forecast demand data
import nemosis
from nemseer import compile_data, download_raw_data, generate_runtimes

# data wrangling libraries
import numpy as np
import pandas as pd


# static plotting
import matplotlib
import matplotlib.pyplot as plt
import seaborn as sns

# silence NEMSEER and NEMOSIS logging
logging.getLogger("nemosis").setLevel(logging.WARNING)
logging.getLogger("nemseer").setLevel(logging.ERROR)

# suppress warnings
import warnings

warnings.filterwarnings("ignore")

# %% [markdown]
# ## Plot Styling

plt.style.use("matplotlibrc.mplstyle")

# %% [markdown]
# ## Defining our analysis start and end dates

# %%
analysis_start = "2012/01/01 00:00:00"
analysis_end = "2023/01/01 00:00:00"

# %% [markdown]
# ## Getting Data

# %% [markdown]
# ### Obtaining actual price data from `NEMOSIS`
#
# We will download `DISPATCHPRICE` to access the `RRP` (energy price) field and cache it so that it's ready for computation.

# %%
nemosis_cache = Path("nemosis_cache/")
if not nemosis_cache.exists():
    nemosis_cache.mkdir(parents=True)

# %%
nemosis.cache_compiler(
    analysis_start, analysis_end, "DISPATCHPRICE", nemosis_cache, fformat="parquet"
)

# %% [markdown]
# ## Compile price data from 2012 to 2021

# %%
prices = nemosis.dynamic_data_compiler(
    analysis_start,
    analysis_end,
    "DISPATCHPRICE",
    nemosis_cache,
    filter_cols=["INTERVENTION"],
    filter_values=([0],),
)
prices = prices[["SETTLEMENTDATE", "REGIONID", "RRP"]]

# %%
# Reliability Settings from 1 July 2012 - AEMC
# then https://wattclarity.com.au/other-resources/glossary/market-price-cap/
mpcs = [
    ["2012-01-01 00:00:00", "2013-07-01 00:00:00", 12500],
    ["2013-07-01 00:05:00", "2014-07-01 00:00:00", 13100],
    ["2014-07-01 00:05:00", "2015-07-01 00:00:00", 13500],
    ["2015-07-01 00:05:00", "2016-07-01 00:00:00", 13800],
    ["2016-07-01 00:05:00", "2017-07-01 00:00:00", 14000],
    ["2017-07-01 00:05:00", "2018-07-01 00:00:00", 14200],
    ["2018-07-01 00:05:00", "2019-07-01 00:00:00", 14500],
    ["2019-07-01 00:05:00", "2020-07-01 00:00:00", 14700],
    ["2020-07-01 00:05:00", "2021-07-01 00:00:00", 15000],
    ["2021-07-01 00:05:00", "2022-07-01 00:00:00", 15100],
    ["2022-07-01 00:05:00", "2022-07-01 00:00:00", 15500],
]

# %%
# daily min max
def plot_daily_price_spread(prices: pd.DataFrame) -> None:
    prices["YMD"] = prices.SETTLEMENTDATE.dt.round("D")
    daily_regional = prices.groupby(["YMD", "REGIONID"])["RRP"]
    daily_spread = (daily_regional.max() - daily_regional.min()).reset_index()
    daily_spread["log10(Spread)"] = np.log10(daily_spread.RRP)
    fig, axes = plt.subplots(2, 2, sharex=True, sharey=True, dpi=600)
    fig.set_size_inches(10, 7)
    color_cycle = plt.rcParams["axes.prop_cycle"].by_key()["color"]
    for i, (ax, region) in enumerate(
        zip(axes.flat, [x for x in daily_spread.REGIONID if x != "TAS1"])
    ):
        region_spread = daily_spread.query("REGIONID == @region").set_index("YMD")
        rolling_avg_60day = region_spread["log10(Spread)"].rolling("60D").mean()
        ax.plot(
            region_spread["log10(Spread)"].index,
            region_spread["log10(Spread)"],
            lw=1,
            color=color_cycle[i + 1],
        )
        ax.plot(
            rolling_avg_60day.index, rolling_avg_60day, ls="-.", color=color_cycle[-2]
        )
        ax.axvline(
            np.datetime64("2021-10-01 00:00:00"),
            ls="--",
            color="black",
        )
        for mpc in mpcs:
            xs = pd.date_range(mpc[0], mpc[1], freq="5T")
            max_spread = np.log10(mpc[2] + 1000)
            ax.plot(
                xs,
                np.repeat(max_spread, len(xs)),
                ls="--",
                color=color_cycle[0],
            )
        ax.set_title(region[0:-1])
        if i == 0 or i == 2:
            ax.set_ylabel("$log_{10}({p_{max} - p_{min}})$", usetex=True)
    custom_lines = [
        matplotlib.lines.Line2D(
            [0],
            [0],
            color=color_cycle[0],
            lw=2,
            ls="--",
            label="Maximum potential (cap - floor)",
        ),
        matplotlib.lines.Line2D(
            [0], [0], color="black", lw=2, ls="--", label="5MS Commencement"
        ),
        matplotlib.lines.Line2D(
            [0],
            [0],
            color=color_cycle[-2],
            lw=2,
            ls="--",
            label="Rolling avg. (60 days)",
        ),
    ]
    fig.legend(
        handles=custom_lines, loc="lower center", bbox_to_anchor=(0.5, -0.05), ncol=3
    )
    fig.suptitle("Daily Price Spread, 2012-2022", fontsize=20)
    return fig


fig = plot_daily_price_spread(prices)
fig.savefig("volatility.pdf")

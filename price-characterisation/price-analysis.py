# %% [markdown]
# # Price Analysis

# %% [markdown]
# ## Key imports

# %%
# standard libraries
import logging
from pathlib import Path

# NEM data libraries
# NEMOSIS for actual demand data
# NEMSEER for forecast demand data
import nemosis

# data wrangling libraries
import numpy as np
import pandas as pd


# static plotting
import matplotlib
import matplotlib.pyplot as plt

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
analysis_end = "2022/01/01 00:00:00"

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

# %% [markdown]
# ### Define market price caps, with start and end dates

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
    ["2021-07-01 00:05:00", "2022-01-01 00:00:00", 15100],
    # ["2021-07-01 00:05:00", "2022-07-01 00:00:00", 15100],
    # ["2022-07-01 00:05:00", "2022-07-01 00:00:00", 15500],
]

# %% [markdown]
# ## Daily Price Spread, 2012-2021

# %%
# daily min max
def plot_daily_price_spread(prices: pd.DataFrame) -> None:
    prices["YMD"] = prices.SETTLEMENTDATE.dt.round("D")
    daily_regional = prices.groupby(["YMD", "REGIONID"])["RRP"]
    daily_spread = (daily_regional.max() - daily_regional.min()).reset_index()
    daily_spread["log10(Spread)"] = np.log10(daily_spread.RRP)
    fig, axes = plt.subplots(
        2,
        2,
        sharex=True,
        sharey=True,
        dpi=600,
        figsize=(10, 6),
    )
    color_cycle = plt.rcParams["axes.prop_cycle"].by_key()["color"]
    for i, (ax, region) in enumerate(
        zip(axes.flat, [x for x in daily_spread.REGIONID.unique() if x != "TAS1"])
    ):
        region_spread = daily_spread.query("REGIONID == @region").set_index("YMD")
        rolling_days = 60
        rolling = region_spread["log10(Spread)"].rolling(
            f"{rolling_days}D", center=True
        )
        ax.plot(
            region_spread["log10(Spread)"].index,
            region_spread["log10(Spread)"],
            lw=1,
            color=color_cycle[i + 1],
        )
        rolling_mean = rolling.mean()
        ax.plot(rolling_mean.index, rolling_mean, ls="-.", color=color_cycle[-2])
        ax.axvline(
            np.datetime64("2021-10-01 00:00:00"),
            ls="--",
            lw=0.8,
            color="black",
        )
        for mpc in mpcs:
            xs = pd.date_range(mpc[0], mpc[1], freq="5T")
            max_spread = np.log10(mpc[2] + 1000)
            ax.plot(
                xs,
                np.repeat(max_spread, len(xs)),
                ls="--",
                lw=0.8,
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
            label="Maximum Potential (cap - floor)",
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
            label=f"Rolling Avg. ({rolling_days} days)",
        ),
    ]
    leg = fig.legend(
        handles=custom_lines,
        loc="lower center",
        bbox_to_anchor=(0.5, -0.05),
        ncol=3,
    )
    leg.get_frame().set_linewidth(0.0)
    if rolling_mean.index.year[-1] == 2023:
        end_year = 2022
    else:
        end_year = 2021
    fig.suptitle(f"Daily Energy Price Spread, 2012-{end_year}", fontsize=20)
    return fig


# %%

fig = plot_daily_price_spread(prices)
if not (plot_dir := Path("plots", "historical", "spreads")).exists():
    plot_dir.mkdir(parents=True)
fig.savefig(
    Path(plot_dir, "historical_daily_price_spreads.pdf")
)

# %% [markdown]
# ## Volatility, 2012-2021

# %%


def plot_volatility(prices: pd.DataFrame) -> None:
    fig, ax = plt.subplots(
        1,
        1,
        sharex=True,
        sharey=True,
        dpi=600,
    )
    fig.set_size_inches(10, 5)
    color_cycle = plt.rcParams["axes.prop_cycle"].by_key()["color"]
    for i, region in enumerate([x for x in prices.REGIONID.unique() if x != "TAS1"]):
        region_prices = (
            prices.query("REGIONID == @region").set_index("SETTLEMENTDATE").sort_index()
        )
        rolling_days = 30
        rolling = region_prices.rolling(f"{rolling_days}D", center=True)
        log_rolling_std = np.log10(rolling.std())
        ax.plot(
            log_rolling_std.index,
            log_rolling_std,
            color=color_cycle[i + 1],
            lw=0.9,
            label=region,
        )
    ax.axvline(
        np.datetime64("2021-10-01 00:00:00"),
        ls="--",
        lw=0.8,
        color="black",
        label="5MS Commencement",
    )
    ax.set_ylabel("$log_{10}(\sigma_{rolling})$", usetex=True)
    if log_rolling_std.index.year[-1] == 2023:
        end_year = 2022
    else:
        end_year = 2021
    leg = fig.legend(bbox_to_anchor=(0.5, -0.07), loc="lower center", ncols=5)
    leg.get_frame().set_linewidth(0.0)
    ax.set_title(f"Energy Price Volatility, 2012-{end_year}\n", fontsize=20)
    fig.text(
        0.5,
        1.04,
        f"Rolling standard deviation ({rolling_days} days)",
        transform=ax.transAxes,
        horizontalalignment="center",
    )
    return fig


# %%

fig = plot_volatility(prices)
if not (plot_dir := Path("plots", "historical", "volatility")).exists():
    plot_dir.mkdir(parents=True)
fig.savefig(Path(plot_dir, "historical_volatility.pdf"))

# %% [markdown]
# ## NSW Time-of-day Price Percentiles, 2021

# %%


def plot_nsw_price_percentiles(prices: pd.DataFrame) -> None:
    fig, ax = plt.subplots(
        1,
        1,
        sharex=True,
        sharey=True,
        dpi=600,
    )
    fig.set_size_inches(7, 5)
    color = plt.rcParams["axes.prop_cycle"].by_key()["color"][1]
    nsw_2021_prices = (
        prices.query("REGIONID == 'NSW1'").set_index("SETTLEMENTDATE").sort_index()
    )["2021-01-01 00:05:00":"2022-01-01 00:00:00"]
    nsw_2021_prices["TOD"] = nsw_2021_prices.index.strftime("%H:%M")
    nsw_2021_prices["Month"] = nsw_2021_prices.index.month
    tod_groupby = nsw_2021_prices.groupby("TOD")["RRP"]
    tod_median = tod_groupby.quantile(0.5)
    tod_median.index = pd.to_datetime(tod_median.index)
    ax.plot(tod_median, color=color, label="Median")
    tod_upper = tod_groupby.quantile(0.95)
    tod_lower = tod_groupby.quantile(0.05)
    ax.fill_between(
        tod_median.index,
        tod_lower,
        tod_upper,
        alpha=0.4,
        facecolor="grey",
        label=r"5$^{th}$-95$^{th}}$ percentiles",
    )
    ticks = ax.get_xticks()
    ax.set_xticks(np.linspace(ticks[0], ticks[-1], 25))
    ax.tick_params(rotation=90)
    HMSFmt = matplotlib.dates.DateFormatter("%H:%M")
    ax.xaxis.set_major_formatter(HMSFmt)
    ax.set_ylabel("\$/MWh")
    leg = fig.legend(bbox_to_anchor=(0.5, -0.07), loc="lower center", ncols=5)
    leg.get_frame().set_linewidth(0.0)
    ax.set_title("NSW Time-of-Day Energy Price Percentiles, 2021", fontsize=20)
    return fig


fig = plot_nsw_price_percentiles(prices)
if not (plot_dir := Path("plots", "historical", "nsw")).exists():
    plot_dir.mkdir(parents=True)
fig.savefig(Path(plot_dir, "tod.pdf"))

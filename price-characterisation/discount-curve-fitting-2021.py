# %% [markdown]
# # Price Error Counts and Discount Curve Fitting, 2021

# %% [markdown]
# ## Key imports

# %%
# standard libraries
import logging
from datetime import datetime, timedelta
from pathlib import Path
from typing import Tuple

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

# curve fitting
import scipy

# silence NEMSEER and NEMOSIS logging
logging.getLogger("nemosis").setLevel(logging.WARNING)
logging.getLogger("nemseer").setLevel(logging.ERROR)

# suppress warnings
import warnings

warnings.filterwarnings("ignore")

# %% [markdown]
# ## Plot Styling

# %%
plt.style.use("matplotlibrc.mplstyle")

# %% [markdown]
# ## Defining our analysis start and end dates

# %%
analysis_start = "2021/01/01 00:00:00"
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
print("Caching NEMOSIS price data")
nemosis.cache_compiler(
    analysis_start, analysis_end, "DISPATCHPRICE", nemosis_cache, fformat="parquet"
)

# %% [markdown]
# ### Obtaining forecast price data from `NEMSEER`
#
# We will download `PRICE` to access the `RRP` field in `PREDISPATCH` forecasts, and `REGIONSOLUTION` to access the `RRP` field in `P5MIN` forecasts. We'll cache it so that it's ready for computation.

# %%
print("Caching NEMSEER price forecast data")
download_raw_data(
    "PREDISPATCH",
    "PRICE",
    "nemseer_cache/",
    forecasted_start=analysis_start,
    forecasted_end=analysis_end,
)

download_raw_data(
    "P5MIN",
    "REGIONSOLUTION",
    "nemseer_cache/",
    forecasted_start=analysis_start,
    forecasted_end=analysis_end,
)

# %% [markdown]
# ## Price Convergence/Forecast Error
#
# To try and look at convergence a bit more systematically, we'll compute the *"price error"* across 2021.
#
# The code below obtains `P5MIN` and `PREDISPATCH` price forecasts, removes overlapping forecasted periods and calculates a *"price error"*.
#
# - The last two `PREDISPATCH` forecasts overlap with `P5MIN`
#     - These are removed from `PREDISPATCH`


# %%
def calculate_price_error(analysis_start: str, analysis_end: str) -> pd.DataFrame:
    """
    Calculates price error in PREDISPATCH and P5MIN forecasts for periods between
    analysis_start and analysis_end.

    Args:
        analysis_start: Start datetime, YYYY/mm/dd HH:MM:SS
        analysis_end: End datetime, YYYY/mm/dd HH:MM:SS
    Returns:
        DataFrame with computed price error mapped to the ahead time of the
        forecast and the forecasted time.
    """

    def get_actual_price_data() -> pd.DataFrame:
        """
        Gets actual price data
        """
        # get actual demand data for forecasted_time
        # nemosis start time must precede end of interval of interest by 5 minutes
        nemosis_window = (
            (
                datetime.strptime(analysis_start, "%Y/%m/%d %H:%M:%S")
                - timedelta(minutes=5)
            ).strftime("%Y/%m/%d %H:%M:%S"),
            analysis_end,
        )
        nemosis_price = nemosis.dynamic_data_compiler(
            nemosis_window[0],
            nemosis_window[1],
            "DISPATCHPRICE",
            nemosis_cache,
            filter_cols=["INTERVENTION"],
            filter_values=([0],),
        )
        actual_price = nemosis_price[["SETTLEMENTDATE", "REGIONID", "RRP"]]
        actual_price = actual_price.rename(
            columns={"SETTLEMENTDATE": "forecasted_time"}
        )
        return actual_price

    def get_forecast_price_data(ftype: str) -> pd.DataFrame:
        """
        Get price forecast data for the analysis period given a particular forecast type

        Args:
            ftype: 'P5MIN' or 'PREDISPATCH'
        Returns:
            DataFrame with price forecast data
        """
        # ftype mappings
        table = {"PREDISPATCH": "PRICE", "P5MIN": "REGIONSOLUTION"}
        run_col = {"PREDISPATCH": "PREDISPATCH_RUN_DATETIME", "P5MIN": "RUN_DATETIME"}
        forecasted_col = {"PREDISPATCH": "DATETIME", "P5MIN": "INTERVAL_DATETIME"}
        # get run times
        forecasts_run_start, forecasts_run_end = generate_runtimes(
            analysis_start, analysis_end, ftype
        )
        df = compile_data(
            forecasts_run_start,
            forecasts_run_end,
            analysis_start,
            analysis_end,
            ftype,
            table[ftype],
            "nemseer_cache/",
        )[table[ftype]]
        # remove intervention periods
        df = df.query("INTERVENTION == 0")
        # rename run and forecasted time cols
        df = df.rename(
            columns={
                run_col[ftype]: "run_time",
                forecasted_col[ftype]: "forecasted_time",
            }
        )
        # ensure values are sorted by forecasted and run times for nth groupby operation
        return df[["run_time", "forecasted_time", "REGIONID", "RRP"]].sort_values(
            ["forecasted_time", "run_time"]
        )

    def combine_pd_p5_forecasts(
        p5_df: pd.DataFrame, pd_df: pd.DataFrame
    ) -> pd.DataFrame:
        """
        Combines P5 and PD forecasts, including removing PD overlap with P5
        """
        # remove PD overlap with P5MIN
        pd_nooverlap = pd_df.groupby(
            ["forecasted_time", "REGIONID"], as_index=False
        ).nth(slice(None, -2))
        # concatenate and rename RRP to reflect that these are forecasted values
        forecast_prices = pd.concat([pd_nooverlap, p5_df], axis=0).sort_values(
            ["forecasted_time", "actual_run_time"]
        )
        forecast_prices = forecast_prices.rename(columns={"RRP": "FORECASTED_RRP"})
        return forecast_prices

    def process_price_error(
        forecast_prices: pd.DataFrame, actual_price: pd.DataFrame
    ) -> pd.DataFrame:
        """
        Merges actual and forecast prices and calculates ahead time and price error
        """
        # left merge to ensure each forecasted price is mapped to
        #  its corresponding actual price
        all_prices = pd.merge(
            forecast_prices,
            actual_price,
            how="left",
            on=["forecasted_time", "REGIONID"],
        )
        all_prices["ahead_time"] = (
            all_prices["forecasted_time"] - all_prices["actual_run_time"]
        )
        all_prices["error"] = all_prices["RRP"] - all_prices["FORECASTED_RRP"]
        price_error = all_prices.drop(
            columns=["RRP", "FORECASTED_RRP", "actual_run_time"]
        )
        return price_error

    p5_df = get_forecast_price_data("P5MIN")
    pd_df = get_forecast_price_data("PREDISPATCH")
    # calulate actual run time for each forecast type
    p5_df["actual_run_time"] = p5_df["run_time"] - pd.Timedelta(minutes=5)
    pd_df["actual_run_time"] = pd_df["run_time"] - pd.Timedelta(minutes=30)
    p5_df = p5_df.drop(columns="run_time")
    pd_df = pd_df.drop(columns="run_time")
    # get forecast prices
    forecast_prices = combine_pd_p5_forecasts(p5_df, pd_df)

    # actual prices
    actual_price = get_actual_price_data()

    price_error = process_price_error(forecast_prices, actual_price)
    return price_error


# %%
print("Calculating price errors")
price_error = calculate_price_error(analysis_start, analysis_end)

# %% [markdown]
# ## Price Forecast Error Counts
#
# ### Across select ahead timeframes

# %%
aheads = [
    timedelta(minutes=5),
    timedelta(minutes=30),
    timedelta(hours=1),
    timedelta(hours=4),
    timedelta(hours=8),
    timedelta(hours=12),
    timedelta(hours=18),
    timedelta(days=1),
    timedelta(days=1, hours=8),
]

# %% [markdown]
# ### Errors greater than a threshold - region by region
# #### By region
# %%
def count_errors_above_threshold_by_region(
    price_error: pd.DataFrame, threshold: float
) -> None:
    if not (save_dir := Path("plots", "2021", "error-threshold")).exists():
        save_dir.mkdir(parents=True)
    colors = plt.rcParams["axes.prop_cycle"].by_key()["color"]
    for region in price_error.REGIONID.unique():
        region_df = price_error.query("REGIONID==@region")
        box_df = region_df[region_df.ahead_time.isin(aheads)]
        counts = {}
        box_df.loc[:, "ahead_time"] = (
            (box_df.ahead_time.dt.days * 24 + box_df.ahead_time.dt.seconds / 3600)
            .round(1)
            .astype(str)
        )
        for at in box_df.ahead_time.unique():
            at_df = box_df[box_df.ahead_time == at]
            counts[at] = len(at_df)
        box_df.ahead_time = box_df.ahead_time.replace(
            {at: (at + f", [{counts[at]}]") for at in counts.keys()}
        )
        box_df.loc[:, "threshold"] = box_df.error.abs() >= threshold
        threshold_count = box_df.groupby("ahead_time", sort=False)["threshold"].sum()
        total_count = (
            box_df.groupby("ahead_time", sort=False)["threshold"]
            .count()
            .rename("total")
        )
        counts = pd.merge(
            threshold_count, total_count, left_index=True, right_index=True
        )
        fig, ax = plt.subplots()
        ax.bar(counts.index, counts.threshold / counts.total * 100, color=colors[1])
        fig.suptitle(
            f"{region} - Price Forecast Errors Above {threshold} $/MWh, 2021",
            fontsize=18,
        )
        ax.set_title("Error = Actual - Forecast", fontsize=12)
        ax.set_ylabel(f"Errors >= ${threshold}/MW/hr (% of all samples)")
        ax.set_xlabel("Ahead Time (hours), [# of samples]")
        ax.xaxis.set_tick_params(rotation=45)
        ax.yaxis.set_major_formatter(matplotlib.ticker.PercentFormatter())
        fig.tight_layout()
        fig.savefig(
            Path(save_dir,
                f"{region}_percent_above_{threshold}_2021.png",
            ),
            dpi=600,
        )
        return None


for thresh in (300.0, 1000.0, 10000.0):
    print(f"Counting price errors above ${thresh}/MWh")
    count_errors_above_threshold_by_region(price_error, thresh)

# %% [markdown]
# ### Errors greater than a threshold - all regions

# %%
def count_errors_above_threshold(
    price_error: pd.DataFrame, threshold: float, results: dict
) -> dict:
    if not (save_dir := Path("plots", "2021", "error-threshold")).exists():
        save_dir.mkdir(parents=True)
    all_reg_fig = plt.figure(figsize=(12, 9))
    ax1 = plt.subplot2grid(shape=(2, 6), loc=(0, 0), colspan=2, fig=all_reg_fig)
    ax2 = plt.subplot2grid(
        (2, 6), (0, 2), colspan=2, sharex=ax1, sharey=ax1, fig=all_reg_fig
    )
    ax3 = plt.subplot2grid(
        (2, 6), (0, 4), colspan=2, sharex=ax1, sharey=ax1, fig=all_reg_fig
    )
    ax4 = plt.subplot2grid(
        (2, 6), (1, 1), colspan=2, sharex=ax1, sharey=ax1, fig=all_reg_fig
    )
    ax5 = plt.subplot2grid(
        (2, 6), (1, 3), colspan=2, sharex=ax1, sharey=ax1, fig=all_reg_fig
    )
    colors = plt.rcParams["axes.prop_cycle"].by_key()["color"]
    axes = [ax1, ax2, ax3, ax4, ax5]
    results[threshold] = {}
    for region, ax in zip(price_error.REGIONID.unique(), axes):
        region_df = price_error.query("REGIONID==@region")
        box_df = region_df[region_df.ahead_time.isin(aheads)]
        counts = {}
        box_df.loc[:, "ahead_time"] = (
            (box_df.ahead_time.dt.days * 24 + box_df.ahead_time.dt.seconds / 3600)
            .round(1)
            .astype(str)
        )
        for at in box_df.ahead_time.unique():
            at_df = box_df[box_df.ahead_time == at]
            counts[at] = len(at_df)
        box_df.ahead_time = box_df.ahead_time.replace(
            {at: (at + f", [{counts[at]}]") for at in counts.keys()}
        )
        box_df.loc[:, "threshold"] = box_df.error.abs() >= threshold
        threshold_count = box_df.groupby("ahead_time", sort=False)["threshold"].sum()
        total_count = (
            box_df.groupby("ahead_time", sort=False)["threshold"]
            .count()
            .rename("total")
        )
        counts = pd.merge(
            threshold_count, total_count, left_index=True, right_index=True
        )
        counts["frac"] = counts.threshold / counts.total
        results[threshold][region] = counts
        ax.bar(counts.index, counts.frac * 100, color=colors[1])
        ax.set_title(f"{region}", fontsize=12)
        ax.set_ylabel(f"Errors >= ${threshold}/MW/hr (% of all samples)")
        ax.set_xlabel("Ahead Time (hours), [# of samples]")
        ax.xaxis.set_tick_params(rotation=45)
        ax.yaxis.set_major_formatter(matplotlib.ticker.PercentFormatter())
    all_reg_fig.tight_layout()
    all_reg_fig.suptitle(
        f"Price Forecast Errors Above {threshold} $/MWh, 2021", fontsize=24
    )
    all_reg_fig.savefig(
        Path(
            save_dir, f"all_regions_percent_above_{threshold}_2021.png"
        ),
        dpi=600,
    )
    return results


thresh_frac = {}
for thresh in (300.0, 1000.0, 10000.0):
    print(f"Counting price errors above ${thresh}/MWh for all regions")
    counts = count_errors_above_threshold(price_error, thresh, thresh_frac)

# %% [markdown]
# ## Discount Curve Fitting
# Fit counts of errors above a threshold to hyperbolic and exponential functions

# %%
def exponential_discount(times, rate):
    return np.exp(np.multiply(-1 * rate, times))


def hyperbolic_discount(times, rate):
    return np.divide(1, (1 + np.multiply(rate, times)))


# %%

print("Fitting functions to data")
curve_fit_dir = Path("plots", "2021", "discount-curve-fitting")


def fit_and_plot_discount_functions_across_thresholds(
    counts: dict, curve_fit_dir: str
) -> Tuple[list, list, list, list]:
    """
    Only fit for errors within day-ahead
    """
    if not curve_fit_dir.exists():
        curve_fit_dir.mkdir(parents=True)
    (exp_params, hyp_params, exp_rmsds, hyp_rmsds) = ([], [], [], [])
    for threshold in counts.keys():
        df = counts[threshold]["NSW1"]
        # only day-ahead or shorter
        df = df.iloc[1:, :]
        times = df.index.str.extract("([0-9\.]*)", expand=False).astype(float).values
        max_scaled_counts = (1 - df.frac / df.frac.max()).values

        [exp_fit], _ = scipy.optimize.curve_fit(
            exponential_discount, times, max_scaled_counts
        )
        exp_params.append(exp_fit)
        [hyp_fit], _ = scipy.optimize.curve_fit(
            hyperbolic_discount, times, max_scaled_counts
        )
        hyp_params.append(hyp_fit)

        exp_curve = exponential_discount(times, exp_fit)
        hyp_curve = hyperbolic_discount(times, hyp_fit)
        exp_rmsd = np.sqrt(
            np.sum(np.subtract(exp_curve, max_scaled_counts) ** 2)
            / len(max_scaled_counts)
        )
        exp_rmsds.append(exp_rmsd)
        hyp_rmsd = np.sqrt(
            np.sum(np.subtract(hyp_curve, max_scaled_counts) ** 2)
            / len(max_scaled_counts)
        )
        hyp_rmsds.append(hyp_rmsd)
        fig, ax = plt.subplots()
        ax.plot(times, max_scaled_counts, label="Counts (max-scaled)")
        ax.plot(times, exp_curve, label="Exponential discount fit")
        ax.plot(times, hyp_curve, label="Hyperbolic discount fit")
        ax.set_title(
            f"Fitting Discount Functions to Price Error Counts (>= ${threshold}/MWh), NSW 2021"
        )
        ax.set_xlabel("Hours ahead")
        ax.set_ylabel("1 - Max-scaled/Discount factor")
        ax.legend()
        fig.savefig(Path(curve_fit_dir, f"curve_fits_{threshold}.png"), dpi=600)
    return (exp_params, hyp_params, exp_rmsds, hyp_rmsds)


(
    exp_params,
    hyp_params,
    exp_rmsds,
    hyp_rmsds,
) = fit_and_plot_discount_functions_across_thresholds(counts, curve_fit_dir)

summary = pd.DataFrame(
    {
        "threshold": counts.keys(),
        "exp_fit": exp_params,
        "hyp_fit": hyp_params,
        "exp_rmsds": exp_rmsds,
        "hyp_rmsds": hyp_rmsds,
    }
)
summary.to_csv(Path(curve_fit_dir, "curve-fitting-summary.csv"))

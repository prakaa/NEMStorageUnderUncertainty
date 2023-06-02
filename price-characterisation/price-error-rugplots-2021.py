# %% [markdown]
# # Price Error Characterisation, 2021

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
nemosis.cache_compiler(
    analysis_start, analysis_end, "DISPATCHPRICE", nemosis_cache, fformat="parquet"
)
# %% [markdown]
# ### Obtaining forecast price data from `NEMSEER`
#
# We will download `PRICE` to access the `RRP` field in `PREDISPATCH` forecasts, and `REGIONSOLUTION` to access the `RRP` field in `P5MIN` forecasts. We'll cache it so that it's ready for computation.

# %%
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
# ## Price Forecast Error Analysis
#
# ### Across select ah

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
# ### Rugplots of Raw Errors


# %%
def plot_rugplots(price_error: pd.DataFrame) -> None:
    if not (save_dir := Path("plots", "2021", "error-rugs")).exists():
        save_dir.mkdir(parents=True)
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
        fig, ax = plt.subplots()
        sns.stripplot(box_df, x="ahead_time", y="error", ax=ax, size=2, jitter=True)
        fig.suptitle(f"{region} - Price Forecast Error, 2021", fontsize=18)
        ax.set_ylabel("Price Forecast Error ($/MW/hr)")
        ax.set_xlabel("Ahead Time (hours), [# of samples]")
        ax.xaxis.set_tick_params(rotation=45)
        ax.set_title("Error = Actual - Forecast", fontsize=12)
        fig.tight_layout()
        fig.savefig(Path(save_dir, f"{region}_2021.png"), dpi=600)
    return None


print("Plotting rugplots for 2021")
plot_rugplots(price_error)

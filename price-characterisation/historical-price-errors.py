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
# ## Price Convergence/Forecast Error - 2012 to 2021
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
        if "INTERVENTION" in df.columns:
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
dt_str_format = "%Y/%m/%d %H:%M:%S"
analysis_start_dt = datetime.strptime(analysis_start, dt_str_format)
if not (save_dir := Path("price-error")).exists():
    save_dir.mkdir()
for i in range(0, 10, 1):
    start = datetime(
        analysis_start_dt.year + i,
        analysis_start_dt.month,
        analysis_start_dt.day,
        analysis_start_dt.hour,
        analysis_start_dt.minute,
        analysis_start_dt.second,
    )
    fname = f"price-error-{start.year}.parquet"
    if Path(save_dir, fname).exists():
        print(f"Price error {analysis_start_dt.year + i} file exists, continuing")
    else:
        end = datetime(
            start.year + 1,
            start.month,
            start.day,
            start.hour,
            start.minute,
            start.second,
        )
        print(f"Calculating price errors for year {start.year}")
        price_error = calculate_price_error(
            start.strftime(dt_str_format), end.strftime(dt_str_format)
        )
        price_error.to_parquet(Path(save_dir, fname))

# %% [markdown]
# ## Price Forecast Error Analysis

#%%
all_price_errors = []
for parq in save_dir.iterdir():
    df = pd.read_parquet(parq)
    all_price_errors.append(df)
all_price_errors_df = pd.concat(all_price_errors).sort_values("forecasted_time")

# %% [markdown]
# ## Absolute Price Error Count by Severity and Year

# %%


def plot_counts_within_horizon(
    ax: matplotlib.axes.Axes, price_errors_df: pd.DataFrame, horizon_hours: int
):
    colors = plt.rcParams["axes.prop_cycle"].by_key()["color"]
    bottom = np.zeros_like(pd.date_range("2011/12/31", "2021/11/30", freq="1M"), float)
    thresholds = (1000.0, 5000.0, 10000.0, 15500.0)
    lower_threshold = 300.0
    count_df = price_errors_df.set_index("forecasted_time")
    count_df.error = count_df.error.abs()
    count_df = count_df[count_df.ahead_time < timedelta(hours=horizon_hours)]
    for upper_threshold, color in zip(thresholds, colors):
        threshold_df = count_df[
            (lower_threshold < count_df.error) & (upper_threshold >= count_df.error)
        ]
        threshold_count = threshold_df.resample("1M", label="left")["error"].count()
        threshold_count.index += timedelta(days=1)
        threshold_count = threshold_count[:"2021-12-01"]
        ax.bar(
            threshold_count.index,
            threshold_count.values,
            label=f"({int(lower_threshold)}, {int(upper_threshold)}]",
            bottom=bottom,
            color=color,
            width=25,
        )
        bottom += threshold_count.values
        lower_threshold = upper_threshold
    return None


def annotate_ax(
    ax: matplotlib.axes.Axes,
    annotate: bool,
    vline_ymax: float,
    y_annot: float,
    annot_fontsize: float,
):

    annotation_xs = [
        datetime(2016, 5, 1),
        datetime(2016, 9, 1),
        datetime(2017, 4, 11),
        datetime(2017, 12, 1),
        datetime(2018, 8, 1),
        datetime(2020, 2, 1),
        datetime(2021, 5, 1),
        datetime(2021, 10, 1),
    ]
    for x in annotation_xs:
        ax.axvline(
            x,
            0.0,
            vline_ymax,
            ls="--",
            lw=0.5,
            color="black",
        )
    if annotate:
        annotations = [
            "760 MW SA coal exits",
            "SA system black",
            "1600 MW VIC coal exits",
            "First BESS operational",
            "SA & QLD separation\nevent",
            "SA islanded (17 days)",
            "QLD coal unit explosion",
            "5MS commences",
        ]
        for x, text in zip(annotation_xs, annotations):
            ax.text(
                x,
                y_annot,
                text,
                fontsize=annot_fontsize,
                rotation=45,
            )
    return None


fig, axes = plt.subplots(
    2, 1, facecolor=matplotlib.rcParams.get("axes.facecolor"), sharex=True, sharey=True
)
for horizon, ax in zip((24, 1), axes.flatten()):
    plot_counts_within_horizon(ax, all_price_errors_df, horizon)

annotate_ax(axes[0], annotate=True, vline_ymax=1.1, y_annot=29e3, annot_fontsize=6)
annotate_ax(axes[1], annotate=False, vline_ymax=1.1, y_annot=29e3, annot_fontsize=6)
fig.suptitle("NEM-wide Monthly Count of (Absolute Value) Price Forecast Errors", fontsize=16)
axes[0].set_title("Within day-ahead horizon (PD & 5MPD)", loc="left", fontsize=10)
axes[1].set_title("Within hour-ahead horizon (5MPD)", loc="left", fontsize=10)
for ax in axes.flatten():
    ax.set_ylabel("Count of |Price Error| within interval", fontsize=7)
handles, labels = axes[0].get_legend_handles_labels()
fig.legend(
    handles,
    labels,
    title="Absolute Value Price Forecast Error Intervals",
    bbox_to_anchor=(0.5, -0.1),
    ncol=4,
    loc="lower center",
    title_fontsize="small",
    fontsize=8,
)
if not (save_dir := Path("plots", "historical", "errors")).exists():
    save_dir.mkdir()
fig.savefig(
    Path(save_dir, "price_errors_nemwide_2012_2021.pdf"),
    facecolor=fig.get_facecolor(),
    dpi=600,
)

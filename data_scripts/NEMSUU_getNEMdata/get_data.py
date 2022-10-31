from pathlib import Path

from nemosis import cache_compiler
from nemseer import download_raw_data


def main():
    analysis_start = "2020/12/31 23:30:00"
    analysis_end = "2022/01/01 00:00:00"

    nemosis_cache = Path("data/dispatch_price")
    if not nemosis_cache.exists():
        nemosis_cache.mkdir(parents=True)

    nemseer_cache = Path("data/forecast_price")
    if not nemseer_cache.exists():
        nemseer_cache.mkdir(parents=True)

    cache_compiler(
        analysis_start,
        analysis_end,
        "DISPATCHPRICE",
        nemosis_cache,
        fformat="parquet",
    )

    download_raw_data(
        "PREDISPATCH",
        "PRICE",
        nemseer_cache / "PREDISPATCH",
        run_start=analysis_start,
        run_end=analysis_end,
    )

    download_raw_data(
        "P5MIN",
        "REGIONSOLUTION",
        nemseer_cache / "P5MIN",
        run_start=analysis_start,
        run_end=analysis_end,
    )

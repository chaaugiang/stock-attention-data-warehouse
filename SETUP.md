# Running the Project

## 1. Install Python packages

Download or clone this repository, open a terminal in the project folder,
and run:

```powershell
python -m pip install -r requirements.txt
```

## 2. Configure database connections

The notebooks read database credentials from environment variables

In PowerShell, replace the placeholders below with your own connection
details:

```powershell
$env:AWS_DB_HOST = "your-rds-endpoint"
$env:AWS_DB_USER = "your-rds-username"
$env:AWS_DB_PASSWORD = "your-rds-password"

$env:LOCAL_DB_HOST = "localhost"
$env:LOCAL_DB_USER = "your-local-username"
$env:LOCAL_DB_PASSWORD = "your-local-password"
```

Start Jupyter from that same terminal so the notebooks can access
these variables:

```powershell
python -m jupyterlab
```

The cloud and local databases both use the name `stock_attention`
They are separate databases on separate servers

The RDS instance must be running and reachable from your computer
The local MySQL server must also be running

## 3. Prepare the input files

Place the raw tweet dataset at:

```text
data/tweets_raw.csv
```

Source:
https://www.kaggle.com/datasets/h4t3h4k3rs/ticker-tweets-2018-2023

Place the 20 quarterly daily Google Trends CSVs in:

```text
data/trends/
```

The original collection contains:

- Eight AAPL-only files covering 2020–2021
- Eight combined AMZN, GOOGL, MSFT, and TSLA files covering 2020–2021
- Four combined files covering all five tickers in 2022

Each ticker must have daily coverage from January 1, 2020
through December 31, 2022

Place the three-year weekly reference download at:

```text
data/trends_reference_2020_2022.csv
```

The reference includes all five tickers in one Google Trends comparison
Use United States, All categories, and Web Search for all Trends downloads

Raw data files are not included in this repository

## 4. Run the workflow

Keep the notebooks in the main project folder and run them from there

1. Run `01_load_stock_data.ipynb` to download stock data and load AWS RDS
2. Run `02_clean_tweet_data.ipynb` to prepare the tweet CSV
3. Run `03_load_and_analyze_tweets.sql` in local MySQL Workbench
4. Run `04_analyze_google_trends.ipynb` to combine and check daily Trends data
5. Run `05_create_warehouse.sql` in local MySQL Workbench
6. Run `06_build_warehouse.ipynb` to load and calibrate the warehouse data
7. Run `07_analyze_monthly_signals.sql` in local MySQL Workbench

Before running the tweet import SQL, replace its CSV path with the
full path to your own `tweets_clean.csv`

Enable LOAD DATA LOCAL INFILE on both the local MySQL server and
the Workbench connection

Use MySQL 8.0 or later for the regular-expression and window functions

## 5. Expected checks

The original project run produced:

- 5,480 daily Google Trends observations
- 36 rows and 12 columns in the monthly Trends maximum table
- Five companies and 1,096 dates in the warehouse dimensions
- 3,780 daily fact records
- 180 company-month summaries

External data downloads may change, so exact measures can differ
from the original report

Quarterly Google Trends calibration is approximate
The analysis identifies exploratory associations, not causal effects
or validated investment predictions

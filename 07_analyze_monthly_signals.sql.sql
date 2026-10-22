# Compare monthly trading activity with Twitter mentions and search interest
# Run after the warehouse ETL notebook has populated fact_daily
# Use previous-month changes, three-month averages, and within-company rankings
# Identify unusual patterns for further research rather than predict returns

USE stock_attention;

# Combine the daily records into one row per company per month
# All measures use the trading days stored in the fact table
# Search interest uses the calibrated values so quarters are comparable
CREATE OR REPLACE VIEW monthly_summary AS
SELECT
    ticker,
    CAST(DATE_FORMAT(stock_date, '%Y-%m-01') AS DATE)
        AS month_start,
    COUNT(*) AS trading_days,
    SUM(volume) AS monthly_volume,
    SUM(tweet_count) AS monthly_tweets,
    SUM(buy_count) AS monthly_buy_count,
    SUM(sell_count) AS monthly_sell_count,
    AVG(google_interest_calibrated) AS avg_search_interest
FROM fact_daily
WHERE stock_date >= '2020-01-01'
  AND stock_date < '2023-01-01'
GROUP BY
    ticker,
    CAST(DATE_FORMAT(stock_date, '%Y-%m-01') AS DATE);

#Check that there are 180 rows: five companies over 36 months
SELECT COUNT(*) AS company_months
FROM monthly_summary;

# Look at the first company's monthly summary
SELECT *
FROM monthly_summary
ORDER BY ticker, month_start
LIMIT 12;


#Compare each company with its own earlier months
# PARTITION BY ticker keeps the companies separate
CREATE OR REPLACE VIEW monthly_comparisons AS
SELECT
    m.*,

    # Get the previous month's values for calculating changes
    LAG(monthly_volume) OVER (
        PARTITION BY ticker
        ORDER BY month_start
    ) AS previous_volume,

    LAG(monthly_tweets) OVER (
        PARTITION BY ticker
        ORDER BY month_start
    ) AS previous_tweets,

    LAG(avg_search_interest) OVER (
        PARTITION BY ticker
        ORDER BY month_start
    ) AS previous_search_interest,

    #Use the previous three months as a recent baseline
   # The current month is excluded from these averages
    AVG(monthly_volume) OVER (
        PARTITION BY ticker
        ORDER BY month_start
        ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING
    ) AS prior_3month_avg_volume,

    AVG(monthly_tweets) OVER (
        PARTITION BY ticker
        ORDER BY month_start
        ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING
    ) AS prior_3month_avg_tweets,

    AVG(avg_search_interest) OVER (
        PARTITION BY ticker
        ORDER BY month_start
        ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING
    ) AS prior_3month_avg_search,

    #Check how many months actually contributed to the baseline
    #January has none, February has one, and March has two
    COUNT(*) OVER (
        PARTITION BY ticker
        ORDER BY month_start
        ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING
    ) AS prior_months_available

FROM monthly_summary AS m;


# Calculate month-to-month changes and ratios to the recent baseline
# NULLIF avoids division by zero; undefined changes stay NULL
CREATE OR REPLACE VIEW monthly_signals AS
SELECT
    c.*,

    # Percentage changes from the previous month
    100.0 * (monthly_volume - previous_volume)
        / NULLIF(previous_volume, 0)
        AS volume_change_pct,

    100.0 * (monthly_tweets - previous_tweets)
        / NULLIF(previous_tweets, 0)
        AS tweets_change_pct,

    100.0 * (avg_search_interest - previous_search_interest)
        / NULLIF(previous_search_interest, 0)
        AS search_change_pct,

   #A baseline ratio of 1 means activity matched its recent average
   # For example, 1.5 means 50% above and 0.8 means 20% below
    monthly_volume
        / NULLIF(prior_3month_avg_volume, 0)
        AS volume_vs_baseline,

    monthly_tweets
        / NULLIF(prior_3month_avg_tweets, 0)
        AS tweets_vs_baseline,

    avg_search_interest
        / NULLIF(prior_3month_avg_search, 0)
        AS search_vs_baseline,

    # Express Twitter activity relative to shares traded
    1000000.0 * monthly_tweets
        / NULLIF(monthly_volume, 0)
        AS tweets_per_million_shares

FROM monthly_comparisons AS c;


#Check the calculations using Apple's first 12 months
#January's changes should be NULL because no earlier month is available
SELECT
    ticker,
    month_start,
    monthly_volume,
    monthly_tweets,
    ROUND(avg_search_interest, 2) AS avg_search_interest,
    ROUND(volume_change_pct, 2) AS volume_change_pct,
    ROUND(tweets_change_pct, 2) AS tweets_change_pct,
    ROUND(search_change_pct, 2) AS search_change_pct,
    ROUND(volume_vs_baseline, 2) AS volume_vs_baseline,
    ROUND(tweets_vs_baseline, 2) AS tweets_vs_baseline,
    ROUND(search_vs_baseline, 2) AS search_vs_baseline,
    prior_months_available
FROM monthly_signals
WHERE ticker = 'AAPL'
ORDER BY month_start
LIMIT 12;


# Case 1: high Twitter activity relative to trading volume
#Rank tweets per million shares within each company
#Only include months with a complete three-month baseline
WITH ranked_social AS (
    SELECT
        ticker,
        month_start,
        monthly_volume,
        monthly_tweets,
        avg_search_interest,
        tweets_per_million_shares,
        tweets_vs_baseline,
        volume_vs_baseline,
        prior_months_available,

        # A percentile of 1 means the highest ratio for that company
        PERCENT_RANK() OVER (
            PARTITION BY ticker
            ORDER BY tweets_per_million_shares
        ) AS social_ratio_percentile

    FROM monthly_signals
    WHERE prior_months_available = 3
)

SELECT
    ticker,
    month_start,
    monthly_volume,
    monthly_tweets,
    ROUND(avg_search_interest, 2) AS avg_search_interest,
    ROUND(tweets_per_million_shares, 4)
        AS tweets_per_million_shares,
    ROUND(tweets_vs_baseline, 2) AS tweets_vs_baseline,
    ROUND(volume_vs_baseline, 2) AS volume_vs_baseline,
    ROUND(100 * social_ratio_percentile, 1)
        AS social_ratio_percentile

FROM ranked_social

#Require tweets to exceed their recent average so a high ratio
#is not selected based only on low trading volume.
WHERE tweets_vs_baseline > 1

#Show the highest-ranked candidates first
#Break percentile ties using the increase above the tweet baseline
ORDER BY
    social_ratio_percentile DESC,
    tweets_vs_baseline DESC,
    ticker,
    month_start
LIMIT 10;



# Case 2: high trading activity relative to search interest
# Compare both measures with their own three-month averages first
WITH market_search AS (
    SELECT
        ticker,
        month_start,
        monthly_volume,
        monthly_tweets,
        avg_search_interest,
        volume_vs_baseline,
        search_vs_baseline,

        # A larger ratio means volume is more elevated than searches,
       # relative to each measure's recent average
        volume_vs_baseline
            / NULLIF(search_vs_baseline, 0)
            AS market_search_ratio

    FROM monthly_signals
    WHERE prior_months_available = 3
      AND search_vs_baseline > 0
),

ranked_market AS (
    SELECT
        m.*,

     #Compare this ratio with the same company's other months
        PERCENT_RANK() OVER (
            PARTITION BY ticker
            ORDER BY market_search_ratio
        ) AS market_search_percentile

    FROM market_search AS m
)

SELECT
    ticker,
    month_start,
    monthly_volume,
    monthly_tweets,
    ROUND(avg_search_interest, 2) AS avg_search_interest,
    ROUND(volume_vs_baseline, 2) AS volume_vs_baseline,
    ROUND(search_vs_baseline, 2) AS search_vs_baseline,
    ROUND(market_search_ratio, 2) AS market_search_ratio,
    ROUND(100 * market_search_percentile, 1)
        AS market_search_percentile

FROM ranked_market


WHERE volume_vs_baseline > 1


ORDER BY
    market_search_percentile DESC,
    market_search_ratio DESC,
    ticker,
    month_start
LIMIT 10;




#Case 3: a noticeable search change followed by a noticeable trading-volume change in the next month
WITH change_ranks AS (
    SELECT
        ticker,
        month_start,
        monthly_volume,
        monthly_tweets,
        avg_search_interest,
        search_change_pct,
        volume_change_pct,

        #Rank the size of changes, regardless of direction
        
        PERCENT_RANK() OVER (
            PARTITION BY ticker
            ORDER BY ABS(search_change_pct)
        ) AS search_change_percentile,

        PERCENT_RANK() OVER (
            PARTITION BY ticker
            ORDER BY ABS(volume_change_pct)
        ) AS volume_change_percentile

    FROM monthly_signals

   # Exclude months where the percentage changes are undefined
    WHERE search_change_pct IS NOT NULL
      AND volume_change_pct IS NOT NULL
),

adjacent_months AS (
    SELECT
        c.*,

     
        LEAD(month_start) OVER (
            PARTITION BY ticker
            ORDER BY month_start
        ) AS next_month,

        LEAD(monthly_volume) OVER (
            PARTITION BY ticker
            ORDER BY month_start
        ) AS next_month_volume,

        LEAD(monthly_tweets) OVER (
            PARTITION BY ticker
            ORDER BY month_start
        ) AS next_month_tweets,

        LEAD(avg_search_interest) OVER (
            PARTITION BY ticker
            ORDER BY month_start
        ) AS next_month_search_interest,

        LEAD(volume_change_pct) OVER (
            PARTITION BY ticker
            ORDER BY month_start
        ) AS next_month_volume_change_pct,

        LEAD(volume_change_percentile) OVER (
            PARTITION BY ticker
            ORDER BY month_start
        ) AS next_volume_change_percentile

    FROM change_ranks AS c
)

SELECT
    ticker,
    month_start AS online_change_month,
    monthly_volume,
    monthly_tweets,
    ROUND(avg_search_interest, 2) AS avg_search_interest,
    ROUND(search_change_pct, 2) AS search_change_pct,

    next_month AS market_change_month,
    next_month_volume,
    next_month_tweets,
    ROUND(next_month_search_interest, 2)
        AS next_month_search_interest,
    ROUND(next_month_volume_change_pct, 2)
        AS next_month_volume_change_pct,

    ROUND(100 * search_change_percentile, 1)
        AS search_change_percentile,
    ROUND(100 * next_volume_change_percentile, 1)
        AS next_volume_change_percentile

FROM adjacent_months

# Define a noticeable change as one in the company's top quarter of absolute monthly changes. Both changes must meet this rule
WHERE search_change_percentile >= 0.75
  AND next_volume_change_percentile >= 0.75

-- Make sure the paired observations are consecutive calendar months.
  AND next_month = DATE_ADD(month_start, INTERVAL 1 MONTH)


ORDER BY
    LEAST(
        search_change_percentile,
        next_volume_change_percentile
    ) DESC,
    ticker,
    month_start
LIMIT 10;

# Create the local database if it does not already exist
CREATE DATABASE IF NOT EXISTS stock_attention
    CHARACTER SET utf8mb4;

USE stock_attention;

# Create company dimension one row per company
CREATE TABLE IF NOT EXISTS dim_company (
    ticker VARCHAR(10) PRIMARY KEY,
    company_name VARCHAR(100) NOT NULL
);

# Date: every calendar day, including weekends
# Python ETL will populate the dates
CREATE TABLE IF NOT EXISTS dim_date (
    stock_date DATE PRIMARY KEY,
    calendar_year SMALLINT NOT NULL,
    calendar_month TINYINT NOT NULL,
    day_of_month TINYINT NOT NULL,
    day_of_week TINYINT NOT NULL,
    is_weekend BOOLEAN NOT NULL
);

# Fact table: one row per company per trading day
# Python ETL loads daily stock, tweet, and search-interest measures
CREATE TABLE IF NOT EXISTS fact_daily (
    ticker VARCHAR(10) NOT NULL,
    stock_date DATE NOT NULL,

    open_price DOUBLE NOT NULL,
    high_price DOUBLE NOT NULL,
    low_price DOUBLE NOT NULL,
    close_price DOUBLE NOT NULL,
    adjusted_close DOUBLE NOT NULL,
    volume BIGINT NOT NULL,
    

    tweet_count INT NOT NULL,
    buy_count INT NOT NULL,
    sell_count INT NOT NULL,

    # NULL means missing search data 0 means measured zero interest
    google_interest DOUBLE NULL,
    google_interest_calibrated DOUBLE NULL,

    # Preserve the download source because quarterly scales differ
    trends_source_file VARCHAR(255) NULL,

    PRIMARY KEY (ticker, stock_date),

    CONSTRAINT fk_daily_company
        FOREIGN KEY (ticker)
        REFERENCES dim_company(ticker),

    CONSTRAINT fk_daily_date
        FOREIGN KEY (stock_date)
        REFERENCES dim_date(stock_date)
);

# Load the five companies
INSERT INTO dim_company (ticker, company_name)
VALUES
    ('AAPL', 'Apple'),
    ('AMZN', 'Amazon'),
    ('GOOGL', 'Alphabet'),
    ('MSFT', 'Microsoft'),
    ('TSLA', 'Tesla')
ON DUPLICATE KEY UPDATE
    company_name = VALUES(company_name);

# Check the tables
SHOW TABLES;

SELECT *
FROM dim_company
ORDER BY ticker;

SHOW CREATE TABLE fact_daily;



# Check table
USE stock_attention;

SELECT * FROM dim_company;

SELECT * FROM dim_date
ORDER BY stock_date
LIMIT 10;

SELECT * FROM fact_daily
ORDER BY ticker, stock_date
LIMIT 10;


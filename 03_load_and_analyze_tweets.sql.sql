#utf8mb4 lets the table store emojis. The primary key prevents duplicate tweet IDs

# Create the local database and tweet table
CREATE DATABASE IF NOT EXISTS stock_attention
    CHARACTER SET utf8mb4;

USE stock_attention;

CREATE TABLE IF NOT EXISTS tweets (
    tweet_id BIGINT PRIMARY KEY,
    unix_time BIGINT NOT NULL,
    tweet_text LONGTEXT NOT NULL
) CHARACTER SET utf8mb4;

# Load CSV 
USE stock_attention;

# Replace this path with the full path to your cleaned CSV
# Enable local_infile on the server and in Workbench before importing
LOAD DATA LOCAL INFILE
'/path/to/data/tweets_clean.csv'
IGNORE INTO TABLE tweets
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
ESCAPED BY ''
LINES TERMINATED BY 0x0a
IGNORE 1 LINES
(tweet_id, unix_time, tweet_text);



SHOW WARNINGS LIMIT 10;

# Total tweet match
SELECT COUNT(*) AS total_tweets
FROM tweets;

SET SESSION time_zone = '+00:00';

SELECT
    tweet_id,
    FROM_UNIXTIME(unix_time) AS tweet_datetime,
    tweet_text
FROM tweets
LIMIT 5;

#########################################################################
# Create a small list of the five tickers
USE stock_attention;

SET SESSION time_zone = '+00:00';

CREATE TABLE IF NOT EXISTS selected_tickers (
    ticker VARCHAR(10) PRIMARY KEY
);

INSERT IGNORE INTO selected_tickers (ticker)
VALUES ('AAPL'), ('AMZN'), ('GOOGL'), ('MSFT'), ('TSLA');


# Count tweets by company and month

SELECT
    s.ticker,
    YEAR(FROM_UNIXTIME(t.unix_time)) AS year,
    MONTH(FROM_UNIXTIME(t.unix_time)) AS month,
    COUNT(*) AS tweet_count
FROM selected_tickers AS s
JOIN tweets AS t
    ON UPPER(t.tweet_text) REGEXP
       CONCAT('(^|[^A-Z0-9_])', s.ticker, '([^A-Z0-9_]|$)')
WHERE t.unix_time >= 1577836800
  AND t.unix_time < 1672531200
GROUP BY
    s.ticker,
    YEAR(FROM_UNIXTIME(t.unix_time)),
    MONTH(FROM_UNIXTIME(t.unix_time))
ORDER BY s.ticker, year, month;


# REGEXP finds the ticker within tweet text, including forms such as $AAPL.
# The boundary checks prevent AAPL from matching inside a longer identifier.
# A tweet mentioning two companies counts once for each company.
# A tweet repeating the same ticker still counts as one tweet for that company.




# Count whole-word occurrences

DROP FUNCTION IF EXISTS count_word;

DELIMITER $$

CREATE FUNCTION count_word(
    input_text LONGTEXT,
    search_word VARCHAR(10)
)
RETURNS INT
DETERMINISTIC
NO SQL
BEGIN
    DECLARE cleaned_text LONGTEXT;

    IF input_text IS NULL THEN
        RETURN 0;
    END IF;

    -- Turn punctuation and other separators into single spaces.
    SET cleaned_text = CONCAT(
        ' ',
        REGEXP_REPLACE(LOWER(input_text), '[^a-z0-9_]+', ' '),
        ' '
    );

    -- Double spaces so adjacent repeated words can all be counted.
    SET cleaned_text = REPLACE(cleaned_text, ' ', '  ');

    SET search_word = CONCAT(' ', LOWER(search_word), ' ');

    RETURN (
        CHAR_LENGTH(cleaned_text)
        - CHAR_LENGTH(REPLACE(cleaned_text, search_word, ''))
    ) / CHAR_LENGTH(search_word);
END$$

DELIMITER ;



#Test
SELECT
    count_word('Buy, BUY! buying buy sell seller sell.', 'buy')
        AS buy_count,
    count_word('Buy, BUY! buying buy sell seller sell.', 'sell')
        AS sell_count;
        
# Aggregate word counts by ticker and month     

SELECT
    s.ticker,
    YEAR(FROM_UNIXTIME(t.unix_time)) AS year,
    MONTH(FROM_UNIXTIME(t.unix_time)) AS month,
    COUNT(*) AS tweet_count,
    SUM(count_word(t.tweet_text, 'buy')) AS buy_count,
    SUM(count_word(t.tweet_text, 'sell')) AS sell_count
FROM selected_tickers AS s
JOIN tweets AS t
    ON UPPER(t.tweet_text) REGEXP
       CONCAT('(^|[^A-Z0-9_])', s.ticker, '([^A-Z0-9_]|$)')
WHERE t.unix_time >= 1577836800
  AND t.unix_time < 1672531200
GROUP BY
    s.ticker,
    YEAR(FROM_UNIXTIME(t.unix_time)),
    MONTH(FROM_UNIXTIME(t.unix_time))
ORDER BY s.ticker, year, month;


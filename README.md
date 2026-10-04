# Stock Attention Data Warehouse

A Python and MySQL project combining stock trading activity, Twitter mentions, and Google search interest to help investment analysts identify unusual patterns and prioritize further research

## Business Problem

Trading activity and online attention are often analyzed separately
This project brings them together to explore when public attention aligns with trading activity, when the signals diverge, and when changes occur in consecutive months

## Data and Tools

- Companies: Apple, Amazon, Alphabet, Microsoft, and Tesla
- Period: 2020–2022
- Sources: stock prices from yfinance, historical tweets, and Google Trends
- Tools: Python, pandas, SQL, MySQL, and AWS RDS

## Approach

- Loaded stock data into AWS RDS MySQL
- Cleaned and loaded historical tweets into local MySQL
- Combined daily Google Trends downloads and calibrated their quarterly scales against a three-year reference
- Built a star schema with company and date dimensions
- Used Python ETL to create 3,780 company–trading-day records
- Analyzed 180 company-months using SQL window functions and recent activity baselines

## Findings

Three Microsoft cases illustrate the patterns identified:

- August 2022: Twitter mentions were about 136% above their recent average while trading volume was about 25% below
- March 2021: Trading volume was about 25% above its recent average while search interest was about 17% below
- February–March 2020: Search interest increased 66.16% in February, followed by an 81.71% increase in trading volume in March

## Business Value

The workflow provides a repeatable way to flag periods for closer investigation using company news, daily market data, and online discussions

## Limitations

Tweet counts reflect the downloaded dataset rather than all Twitter activity
Google Trends calibration is approximate
The findings are exploratory associations and do not establish causation or predictive investment performance

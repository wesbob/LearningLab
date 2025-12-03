-- ============================================================
-- STEP 4: HELPER FUNCTIONS
-- ============================================================

-- Function to populate dim_date table
-- Run this once to create 5 years of date records
-- Function to populate dim_date table
CREATE OR REPLACE FUNCTION populate_dim_date(
    start_date DATE DEFAULT '2023-01-01',
    end_date DATE DEFAULT '2027-12-31'
)
RETURNS void AS $$
DECLARE
    curr_date DATE := start_date;  -- Changed from current_date to curr_date
BEGIN
    WHILE curr_date <= end_date LOOP
        INSERT INTO dim_date (
            date_key,
            full_date,
            day_of_week,
            day_name,
            day_of_month,
            week_of_year,
            month_number,
            month_name,
            quarter,
            year,
            is_weekend
        )
        VALUES (
            TO_CHAR(curr_date, 'YYYYMMDD')::INT,
            curr_date,
            EXTRACT(DOW FROM curr_date)::INT,
            TO_CHAR(curr_date, 'Day'),
            EXTRACT(DAY FROM curr_date)::INT,
            EXTRACT(WEEK FROM curr_date)::INT,
            EXTRACT(MONTH FROM curr_date)::INT,
            TO_CHAR(curr_date, 'Month'),
            EXTRACT(QUARTER FROM curr_date)::INT,
            EXTRACT(YEAR FROM curr_date)::INT,
            CASE WHEN EXTRACT(DOW FROM curr_date) IN (0, 6) THEN TRUE ELSE FALSE END
        );

        curr_date := curr_date + INTERVAL '1 day';
    END LOOP;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION populate_dim_time()
RETURNS void AS $$
DECLARE
    hour_val INT := 0;
    minute_val INT := 0;
    time_val TIME;
    time_key_val INT;
BEGIN
    WHILE hour_val < 24 LOOP
        minute_val := 0;
        WHILE minute_val < 60 LOOP
            time_val := (LPAD(hour_val::TEXT, 2, '0') || ':' || LPAD(minute_val::TEXT, 2, '0') || ':00')::TIME;
            time_key_val := hour_val * 100 + minute_val;

            INSERT INTO dim_time (
                time_key,
                time_value,
                hour,
                minute,
                time_period,
                business_hour
            )
            VALUES (
                time_key_val,
                time_val,
                hour_val,
                minute_val,
                CASE
                    WHEN hour_val < 12 THEN 'Morning'
                    WHEN hour_val < 17 THEN 'Afternoon'
                    ELSE 'Evening'
                END,
                CASE WHEN hour_val BETWEEN 8 AND 16 THEN TRUE ELSE FALSE END
            );

            minute_val := minute_val + 30; -- 30-minute intervals
        END LOOP;

        hour_val := hour_val + 1;
    END LOOP;
END;
$$ LANGUAGE plpgsql;
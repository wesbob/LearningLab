-- ============================================================
-- HEALTHCARE APPOINTMENT ANALYTICS - STAR SCHEMA (PostgreSQL)
-- Author: Wes Brown
-- Purpose: Data warehouse design for appointment analytics
-- ============================================================

-- ============================================================
-- STEP 1: CREATE DIMENSION TABLES
-- ============================================================

-- Dimension: Patients
-- Contains slowly changing patient demographic information
CREATE TABLE dim_patients (
    patient_key SERIAL PRIMARY KEY,
    patient_id VARCHAR(10) NOT NULL UNIQUE,
    age INT,
    gender CHAR(1),
    zip_code VARCHAR(10),
    insurance_type VARCHAR(20),
    chronic_conditions INT,
    distance_to_clinic_miles DECIMAL(5,1),
    -- Audit columns
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Dimension: Clinics
-- Contains clinic master data
CREATE TABLE dim_clinics (
    clinic_key SERIAL PRIMARY KEY,
    clinic_id VARCHAR(10) NOT NULL UNIQUE,
    clinic_name VARCHAR(100),
    city VARCHAR(50),
    state CHAR(2),
    total_providers INT,
    specialties_offered VARCHAR(200),
    -- Audit columns
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Dimension: Date
-- Pre-populated calendar table for time-based analysis
CREATE TABLE dim_date (
    date_key INT PRIMARY KEY,
    full_date DATE NOT NULL UNIQUE,
    day_of_week INT,
    day_name VARCHAR(10),
    day_of_month INT,
    week_of_year INT,
    month_number INT,
    month_name VARCHAR(10),
    quarter INT,
    year INT,
    is_weekend BOOLEAN,
    is_holiday BOOLEAN DEFAULT FALSE
);

-- Dimension: Time (for appointment times)
CREATE TABLE dim_time (
    time_key INT PRIMARY KEY,
    time_value TIME NOT NULL UNIQUE,
    hour INT,
    minute INT,
    time_period VARCHAR(10), -- Morning, Afternoon, Evening
    business_hour BOOLEAN -- TRUE if during business hours (8 AM - 5 PM)
);

-- ============================================================
-- STEP 2: CREATE FACT TABLE
-- ============================================================

-- Fact: Appointments
-- Central fact table containing appointment events and metrics
CREATE TABLE fact_appointments (
    appointment_key SERIAL PRIMARY KEY,
    
    -- Foreign keys to dimensions
    patient_key INT NOT NULL,
    clinic_key INT NOT NULL,
    appointment_date_key INT NOT NULL,
    scheduled_date_key INT NOT NULL,
    appointment_time_key INT NOT NULL,
    
    -- Degenerate dimensions (kept in fact table)
    appointment_id VARCHAR(10) NOT NULL UNIQUE,
    appointment_type VARCHAR(30),
    status VARCHAR(20),
    
    -- Metrics/Facts
    duration_minutes INT,
    lead_time_days INT, -- Calculated: appointment_date - scheduled_date
    
    -- Flags for easy filtering
    is_no_show BOOLEAN,
    is_cancelled BOOLEAN,
    is_completed BOOLEAN,
    
    -- Audit
    loaded_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Foreign key constraints
    CONSTRAINT fk_fact_patient FOREIGN KEY (patient_key) 
        REFERENCES dim_patients(patient_key),
    CONSTRAINT fk_fact_clinic FOREIGN KEY (clinic_key) 
        REFERENCES dim_clinics(clinic_key),
    CONSTRAINT fk_fact_appt_date FOREIGN KEY (appointment_date_key) 
        REFERENCES dim_date(date_key),
    CONSTRAINT fk_fact_sched_date FOREIGN KEY (scheduled_date_key) 
        REFERENCES dim_date(date_key),
    CONSTRAINT fk_fact_time FOREIGN KEY (appointment_time_key) 
        REFERENCES dim_time(time_key)
);

-- ============================================================
-- STEP 3: CREATE INDEXES FOR QUERY PERFORMANCE
-- ============================================================

-- Indexes on dimension lookup columns
CREATE INDEX idx_dim_patients_id ON dim_patients(patient_id);
CREATE INDEX idx_dim_clinics_id ON dim_clinics(clinic_id);
CREATE INDEX idx_dim_date_full_date ON dim_date(full_date);
CREATE INDEX idx_dim_time_value ON dim_time(time_value);

-- Indexes on fact table foreign keys
CREATE INDEX idx_fact_patient_key ON fact_appointments(patient_key);
CREATE INDEX idx_fact_clinic_key ON fact_appointments(clinic_key);
CREATE INDEX idx_fact_appt_date_key ON fact_appointments(appointment_date_key);
CREATE INDEX idx_fact_status ON fact_appointments(status);

-- Composite index for common query patterns
CREATE INDEX idx_fact_date_clinic ON fact_appointments(appointment_date_key, clinic_key);

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

-- Function to populate dim_time table
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

-- ============================================================
-- STEP 5: POPULATE HELPER TABLES
-- ============================================================

-- Execute these after creating the functions above
-- SELECT populate_dim_date();
-- SELECT populate_dim_time();

-- Verify the data was loaded:
-- SELECT COUNT(*) FROM dim_date;  -- Should be ~1826 rows (5 years)
-- SELECT COUNT(*) FROM dim_time;  -- Should be 48 rows (30-min intervals)

-- ============================================================
-- STEP 6: DATA LOADING TEMPLATE
-- ============================================================

-- First, create a staging schema for raw CSV imports
CREATE SCHEMA IF NOT EXISTS staging;

-- Create staging tables that match your CSV structure exactly
CREATE TABLE staging.appointments (
    appointment_id VARCHAR(10),
    patient_id VARCHAR(10),
    clinic_id VARCHAR(10),
    appointment_date DATE,
    appointment_time TIME,
    scheduled_date DATE,
    status VARCHAR(20),
    appointment_type VARCHAR(30),
    duration_minutes INT
);

CREATE TABLE staging.patients (
    patient_id VARCHAR(10),
    age INT,
    gender CHAR(1),
    zip_code VARCHAR(10),
    insurance_type VARCHAR(20),
    chronic_conditions INT,
    distance_to_clinic_miles DECIMAL(5,1)
);

CREATE TABLE staging.clinics (
    clinic_id VARCHAR(10),
    clinic_name VARCHAR(100),
    city VARCHAR(50),
    state CHAR(2),
    total_providers INT,
    specialties_offered VARCHAR(200)
);

-- ============================================================
-- INSTRUCTIONS FOR CSV IMPORT (Do this in DataGrip):
-- ============================================================
-- 1. Right-click on staging.patients table → Import Data from File
-- 2. Select patients.csv
-- 3. Map columns (should auto-detect)
-- 4. Click "Import"
-- 5. Repeat for staging.clinics and staging.appointments
-- ============================================================

-- After CSV import, load dimension tables
-- Load dim_patients
INSERT INTO dim_patients (
    patient_id,
    age,
    gender,
    zip_code,
    insurance_type,
    chronic_conditions,
    distance_to_clinic_miles
)
SELECT 
    patient_id,
    age,
    gender,
    zip_code,
    insurance_type,
    chronic_conditions,
    distance_to_clinic_miles
FROM staging.patients;

-- Load dim_clinics
INSERT INTO dim_clinics (
    clinic_id,
    clinic_name,
    city,
    state,
    total_providers,
    specialties_offered
)
SELECT 
    clinic_id,
    clinic_name,
    city,
    state,
    total_providers,
    specialties_offered
FROM staging.clinics;

-- Load fact_appointments (with surrogate key lookups)
INSERT INTO fact_appointments (
    patient_key,
    clinic_key,
    appointment_date_key,
    scheduled_date_key,
    appointment_time_key,
    appointment_id,
    appointment_type,
    status,
    duration_minutes,
    lead_time_days,
    is_no_show,
    is_cancelled,
    is_completed
)
SELECT 
    p.patient_key,
    c.clinic_key,
    ad.date_key AS appointment_date_key,
    sd.date_key AS scheduled_date_key,
    t.time_key,
    sa.appointment_id,
    sa.appointment_type,
    sa.status,
    sa.duration_minutes,
    sa.appointment_date - sa.scheduled_date AS lead_time_days,
    CASE WHEN sa.status = 'no_show' THEN TRUE ELSE FALSE END,
    CASE WHEN sa.status = 'cancelled' THEN TRUE ELSE FALSE END,
    CASE WHEN sa.status = 'completed' THEN TRUE ELSE FALSE END
FROM staging.appointments sa
INNER JOIN dim_patients p ON sa.patient_id = p.patient_id
INNER JOIN dim_clinics c ON sa.clinic_id = c.clinic_id
INNER JOIN dim_date ad ON sa.appointment_date = ad.full_date
INNER JOIN dim_date sd ON sa.scheduled_date = sd.full_date
INNER JOIN dim_time t ON sa.appointment_time = t.time_value;

-- ============================================================
-- STEP 7: ANALYTICAL VIEWS (YOUR TASK 1.3)
-- ============================================================

-- View Example 1: Monthly No-Show Rates by Clinic
CREATE OR REPLACE VIEW vw_monthly_no_show_rates AS
SELECT 
    c.clinic_name,
    d.year,
    d.month_name,
    COUNT(*) AS total_appointments,
    SUM(CASE WHEN f.is_no_show THEN 1 ELSE 0 END) AS no_shows,
    ROUND(
        100.0 * SUM(CASE WHEN f.is_no_show THEN 1 ELSE 0 END) / COUNT(*),
        2
    ) AS no_show_rate_pct
FROM fact_appointments f
INNER JOIN dim_clinics c ON f.clinic_key = c.clinic_key
INNER JOIN dim_date d ON f.appointment_date_key = d.date_key
GROUP BY c.clinic_name, d.year, d.month_name, d.month_number
ORDER BY d.year, d.month_number, c.clinic_name;

-- View Example 2: Patient Appointment History Summary
CREATE OR REPLACE VIEW vw_patient_history AS
SELECT 
    p.patient_id,
    p.age,
    p.insurance_type,
    COUNT(*) AS total_appointments,
    SUM(CASE WHEN f.is_completed THEN 1 ELSE 0 END) AS completed_appointments,
    SUM(CASE WHEN f.is_no_show THEN 1 ELSE 0 END) AS no_shows,
    SUM(CASE WHEN f.is_cancelled THEN 1 ELSE 0 END) AS cancellations,
    ROUND(
        100.0 * SUM(CASE WHEN f.is_no_show THEN 1 ELSE 0 END) / COUNT(*),
        2
    ) AS patient_no_show_rate
FROM dim_patients p
INNER JOIN fact_appointments f ON p.patient_key = f.patient_key
GROUP BY p.patient_id, p.age, p.insurance_type
ORDER BY total_appointments DESC;

-- View Example 3: Peak Appointment Hours by Day of Week
CREATE OR REPLACE VIEW vw_peak_appointment_hours AS
SELECT 
    dd.day_name,
    dt.hour,
    dt.time_period,
    COUNT(*) AS appointment_count,
    SUM(CASE WHEN f.is_completed THEN 1 ELSE 0 END) AS completed_count,
    ROUND(
        100.0 * SUM(CASE WHEN f.is_completed THEN 1 ELSE 0 END) / COUNT(*),
        2
    ) AS completion_rate
FROM fact_appointments f
INNER JOIN dim_date dd ON f.appointment_date_key = dd.date_key
INNER JOIN dim_time dt ON f.appointment_time_key = dt.time_key
GROUP BY dd.day_name, dd.day_of_week, dt.hour, dt.time_period
ORDER BY dd.day_of_week, dt.hour;

-- ============================================================
-- VERIFICATION QUERIES
-- ============================================================

-- Check row counts after loading
-- SELECT 'dim_patients' AS table_name, COUNT(*) AS row_count FROM dim_patients
-- UNION ALL
-- SELECT 'dim_clinics', COUNT(*) FROM dim_clinics
-- UNION ALL
-- SELECT 'dim_date', COUNT(*) FROM dim_date
-- UNION ALL
-- SELECT 'dim_time', COUNT(*) FROM dim_time
-- UNION ALL
-- SELECT 'fact_appointments', COUNT(*) FROM fact_appointments;

-- Check for any failed joins (should return 0)
-- SELECT COUNT(*) FROM staging.appointments sa
-- LEFT JOIN dim_patients p ON sa.patient_id = p.patient_id
-- WHERE p.patient_key IS NULL;

-- ============================================================
-- NOTES & DESIGN DECISIONS
-- ============================================================
-- 
-- 1. Star Schema Choice: Chose star over snowflake for simplicity
--    and query performance. Dimension tables are denormalized.
--
-- 2. Surrogate Keys: Using SERIAL (auto-increment) as surrogate keys
--    to protect against source system changes.
--
-- 3. Date Dimension: Separate date table enables time-based analysis
--    without complex date functions in every query.
--
-- 4. Degenerate Dimensions: appointment_id and appointment_type 
--    stored in fact table as they don't need separate dimensions.
--
-- 5. Pre-calculated Flags: is_no_show, is_cancelled, is_completed
--    improve query performance for filtering.
--
-- 6. Staging Schema: Keeps raw CSV data separate from warehouse
--    tables for auditing and troubleshooting.
--
-- ============================================================
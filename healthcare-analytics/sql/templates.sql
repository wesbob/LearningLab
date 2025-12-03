-- ============================================================
-- HEALTHCARE APPOINTMENT ANALYTICS - STAR SCHEMA
-- Author: Wes Brown
-- Purpose: Data warehouse design for appointment analytics
-- ============================================================

-- ============================================================
-- STEP 1: CREATE DIMENSION TABLES
-- ============================================================

-- Dimension: Patients
-- Contains slowly changing patient demographic information
CREATE TABLE dim_patients (
    patient_key INT IDENTITY(1,1) PRIMARY KEY,
    patient_id VARCHAR(10) NOT NULL UNIQUE,
    age INT,
    gender CHAR(1),
    zip_code VARCHAR(10),
    insurance_type VARCHAR(20),
    chronic_conditions INT,
    distance_to_clinic_miles DECIMAL(5,1),
    -- Audit columns
    created_date DATETIME DEFAULT GETDATE(),
    updated_date DATETIME DEFAULT GETDATE()
);

-- Dimension: Clinics
-- Contains clinic master data
CREATE TABLE dim_clinics (
    clinic_key INT IDENTITY(1,1) PRIMARY KEY,
    clinic_id VARCHAR(10) NOT NULL UNIQUE,
    clinic_name VARCHAR(100),
    city VARCHAR(50),
    state CHAR(2),
    total_providers INT,
    specialties_offered VARCHAR(200),
    -- Audit columns
    created_date DATETIME DEFAULT GETDATE()
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
    is_weekend BIT,
    is_holiday BIT DEFAULT 0
);

-- Dimension: Time (for appointment times)
CREATE TABLE dim_time (
    time_key INT PRIMARY KEY,
    time_value TIME NOT NULL UNIQUE,
    hour INT,
    minute INT,
    time_period VARCHAR(10), -- Morning, Afternoon, Evening
    business_hour BIT -- 1 if during business hours (8 AM - 5 PM)
);

-- ============================================================
-- STEP 2: CREATE FACT TABLE
-- ============================================================

-- Fact: Appointments
-- Central fact table containing appointment events and metrics
CREATE TABLE fact_appointments (
    appointment_key INT IDENTITY(1,1) PRIMARY KEY,
    
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
    is_no_show BIT,
    is_cancelled BIT,
    is_completed BIT,
    
    -- Audit
    loaded_date DATETIME DEFAULT GETDATE(),
    
    -- Foreign key constraints
    CONSTRAINT FK_fact_patient FOREIGN KEY (patient_key) 
        REFERENCES dim_patients(patient_key),
    CONSTRAINT FK_fact_clinic FOREIGN KEY (clinic_key) 
        REFERENCES dim_clinics(clinic_key),
    CONSTRAINT FK_fact_appt_date FOREIGN KEY (appointment_date_key) 
        REFERENCES dim_date(date_key),
    CONSTRAINT FK_fact_sched_date FOREIGN KEY (scheduled_date_key) 
        REFERENCES dim_date(date_key),
    CONSTRAINT FK_fact_time FOREIGN KEY (appointment_time_key) 
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
-- STEP 4: HELPER PROCEDURES
-- ============================================================

-- Procedure to populate dim_date table
-- Run this once to create 5 years of date records
CREATE PROCEDURE sp_populate_dim_date
    @start_date DATE = '2023-01-01',
    @end_date DATE = '2027-12-31'
AS
BEGIN
    DECLARE @current_date DATE = @start_date;
    
    WHILE @current_date <= @end_date
    BEGIN
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
            CAST(FORMAT(@current_date, 'yyyyMMdd') AS INT),
            @current_date,
            DATEPART(WEEKDAY, @current_date),
            DATENAME(WEEKDAY, @current_date),
            DAY(@current_date),
            DATEPART(WEEK, @current_date),
            MONTH(@current_date),
            DATENAME(MONTH, @current_date),
            DATEPART(QUARTER, @current_date),
            YEAR(@current_date),
            CASE WHEN DATEPART(WEEKDAY, @current_date) IN (1, 7) THEN 1 ELSE 0 END
        );
        
        SET @current_date = DATEADD(DAY, 1, @current_date);
    END
END;

-- Procedure to populate dim_time table
CREATE PROCEDURE sp_populate_dim_time
AS
BEGIN
    DECLARE @hour INT = 0;
    DECLARE @minute INT = 0;
    DECLARE @time TIME;
    
    WHILE @hour < 24
    BEGIN
        WHILE @minute < 60
        BEGIN
            SET @time = CAST(FORMAT(@hour, '00') + ':' + FORMAT(@minute, '00') + ':00' AS TIME);
            
            INSERT INTO dim_time (
                time_key,
                time_value,
                hour,
                minute,
                time_period,
                business_hour
            )
            VALUES (
                @hour * 100 + @minute,
                @time,
                @hour,
                @minute,
                CASE 
                    WHEN @hour < 12 THEN 'Morning'
                    WHEN @hour < 17 THEN 'Afternoon'
                    ELSE 'Evening'
                END,
                CASE WHEN @hour BETWEEN 8 AND 16 THEN 1 ELSE 0 END
            );
            
            SET @minute = @minute + 30; -- 30-minute intervals
        END;
        
        SET @minute = 0;
        SET @hour = @hour + 1;
    END
END;

-- ============================================================
-- STEP 5: DATA LOADING TEMPLATE
-- ============================================================

-- TODO: Write ETL logic to load data from CSV files
-- Order: 1) Dimensions, 2) Fact table
-- Remember to:
--   - Handle duplicate patient/clinic records
--   - Calculate lead_time_days
--   - Set is_no_show, is_cancelled, is_completed flags
--   - Look up surrogate keys for fact table

-- Example skeleton for loading appointments:
/*
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
    source.appointment_id,
    source.appointment_type,
    source.status,
    source.duration_minutes,
    DATEDIFF(DAY, source.scheduled_date, source.appointment_date) AS lead_time_days,
    CASE WHEN source.status = 'no_show' THEN 1 ELSE 0 END,
    CASE WHEN source.status = 'cancelled' THEN 1 ELSE 0 END,
    CASE WHEN source.status = 'completed' THEN 1 ELSE 0 END
FROM staging.appointments source
INNER JOIN dim_patients p ON source.patient_id = p.patient_id
INNER JOIN dim_clinics c ON source.clinic_id = c.clinic_id
INNER JOIN dim_date ad ON source.appointment_date = ad.full_date
INNER JOIN dim_date sd ON source.scheduled_date = sd.full_date
INNER JOIN dim_time t ON source.appointment_time = t.time_value;
*/

-- ============================================================
-- STEP 6: ANALYTICAL VIEWS (YOUR TASK 1.3)
-- ============================================================

-- TODO: Create views for common analytical queries
-- Examples:
--   - vw_monthly_no_show_rates
--   - vw_patient_appointment_history
--   - vw_peak_appointment_hours

-- View Example 1: Monthly No-Show Rates by Clinic
CREATE VIEW vw_monthly_no_show_rates AS
SELECT 
    -- Your SQL here
    NULL AS placeholder;

-- View Example 2: Patient History Summary
CREATE VIEW vw_patient_history AS
SELECT 
    -- Your SQL here
    NULL AS placeholder;

-- ============================================================
-- NOTES & DESIGN DECISIONS
-- ============================================================
-- 
-- 1. Star Schema Choice: Chose star over snowflake for simplicity
--    and query performance. Dimension tables are denormalized.
--
-- 2. Surrogate Keys: Using IDENTITY columns as surrogate keys
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
-- ============================================================
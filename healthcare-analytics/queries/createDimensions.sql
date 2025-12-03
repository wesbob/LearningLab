-- ============================================================
-- HEALTHCARE APPOINTMENT ANALYTICS - STAR SCHEMA (PostgreSQL)
-- Author: Wes Brown / Claude
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
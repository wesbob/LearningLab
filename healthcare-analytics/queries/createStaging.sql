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
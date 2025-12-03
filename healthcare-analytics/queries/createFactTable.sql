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
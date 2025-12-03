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

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import random

# Set random seed for reproducibility
np.random.seed(42)
random.seed(42)

# Configuration
NUM_PATIENTS = 500
NUM_CLINICS = 5
NUM_APPOINTMENTS = 10000
START_DATE = datetime(2023, 7, 1)
END_DATE = datetime(2024, 12, 31)

print("Generating healthcare appointment dataset...")

# Generate Clinics
clinics_data = {
    'clinic_id': [f'C{str(i).zfill(2)}' for i in range(1, NUM_CLINICS + 1)],
    'clinic_name': [
        'North Dallas Family Clinic',
        'Plano Specialist Center',
        'McKinney Urgent Care',
        'Frisco Medical Group',
        'Allen Health Center'
    ],
    'city': ['Dallas', 'Plano', 'McKinney', 'Frisco', 'Allen'],
    'state': ['TX'] * NUM_CLINICS,
    'total_providers': [8, 12, 5, 10, 7],
    'specialties_offered': [
        'general|pediatrics',
        'cardiology|orthopedics|neurology',
        'urgent_care|general',
        'general|dermatology|pediatrics',
        'general|womens_health'
    ]
}
clinics_df = pd.DataFrame(clinics_data)

# Generate Patients
zip_codes = ['75020', '75021', '75023', '75034', '75035', '75074', '75075']
insurance_types = ['private', 'medicare', 'medicaid', 'uninsured']
insurance_weights = [0.50, 0.25, 0.15, 0.10]

patients_data = {
    'patient_id': [f'P{str(i).zfill(4)}' for i in range(1001, 1001 + NUM_PATIENTS)],
    'age': np.random.randint(18, 85, NUM_PATIENTS),
    'gender': np.random.choice(['M', 'F'], NUM_PATIENTS),
    'zip_code': np.random.choice(zip_codes, NUM_PATIENTS),
    'insurance_type': np.random.choice(insurance_types, NUM_PATIENTS, p=insurance_weights),
    'chronic_conditions': np.random.choice([0, 1, 2, 3], NUM_PATIENTS, p=[0.6, 0.25, 0.10, 0.05]),
    'distance_to_clinic_miles': np.round(np.random.uniform(1, 25, NUM_PATIENTS), 1)
}
patients_df = pd.DataFrame(patients_data)

# Generate Appointments
appointment_types = ['general_checkup', 'follow_up', 'specialist', 'urgent_care', 'preventive']
appointment_type_weights = [0.35, 0.25, 0.20, 0.10, 0.10]
durations = [30, 30, 45, 60, 30]

statuses = ['completed', 'no_show', 'cancelled']

appointments_list = []

for i in range(NUM_APPOINTMENTS):
    # Random appointment date
    days_diff = (END_DATE - START_DATE).days
    appointment_date = START_DATE + timedelta(days=random.randint(0, days_diff))
    
    # Schedule date is 1-30 days before appointment
    lead_time = random.randint(1, 30)
    scheduled_date = appointment_date - timedelta(days=lead_time)
    
    # Appointment time (business hours: 8 AM - 5 PM)
    hour = random.choice([8, 9, 10, 11, 13, 14, 15, 16])
    minute = random.choice([0, 30])
    appointment_time = f"{hour:02d}:{minute:02d}:00"
    
    # Select appointment type
    appt_type = np.random.choice(appointment_types, p=appointment_type_weights)
    duration = durations[appointment_types.index(appt_type)]
    
    # Select patient and clinic
    patient_id = random.choice(patients_df['patient_id'].tolist())
    clinic_id = random.choice(clinics_df['clinic_id'].tolist())
    
    # Get patient info for status prediction
    patient_info = patients_df[patients_df['patient_id'] == patient_id].iloc[0]
    
    # Status logic with realistic patterns
    # Factors: lead_time, age, insurance, distance
    no_show_prob = 0.15  # base rate
    
    # Adjust based on lead time (longer lead = higher no-show)
    if lead_time > 20:
        no_show_prob += 0.08
    elif lead_time > 10:
        no_show_prob += 0.03
    
    # Adjust based on insurance
    if patient_info['insurance_type'] == 'uninsured':
        no_show_prob += 0.10
    elif patient_info['insurance_type'] == 'medicaid':
        no_show_prob += 0.05
    
    # Adjust based on distance
    if patient_info['distance_to_clinic_miles'] > 15:
        no_show_prob += 0.07
    
    # Adjust based on age (younger = higher no-show)
    if patient_info['age'] < 30:
        no_show_prob += 0.05
    
    # Urgent care has lower no-show rate
    if appt_type == 'urgent_care':
        no_show_prob -= 0.10
    
    # Cancellation probability
    cancel_prob = 0.08
    
    # Determine status
    rand_val = random.random()
    if rand_val < no_show_prob:
        status = 'no_show'
    elif rand_val < no_show_prob + cancel_prob:
        status = 'cancelled'
    else:
        status = 'completed'
    
    appointments_list.append({
        'appointment_id': f'A{str(i+1).zfill(5)}',
        'patient_id': patient_id,
        'clinic_id': clinic_id,
        'appointment_date': appointment_date.strftime('%Y-%m-%d'),
        'appointment_time': appointment_time,
        'scheduled_date': scheduled_date.strftime('%Y-%m-%d'),
        'status': status,
        'appointment_type': appt_type,
        'duration_minutes': duration
    })

appointments_df = pd.DataFrame(appointments_list)

# Save to CSV files
print("\nSaving files...")
clinics_df.to_csv('clinics.csv', index=False)
print("✓ clinics.csv created")

patients_df.to_csv('patients.csv', index=False)
print("✓ patients.csv created")

appointments_df.to_csv('appointments.csv', index=False)
print("✓ appointments.csv created")

# Print summary statistics
print("\n" + "="*50)
print("DATASET SUMMARY")
print("="*50)
print(f"\nClinics: {len(clinics_df)}")
print(f"Patients: {len(patients_df)}")
print(f"Appointments: {len(appointments_df)}")
print(f"\nDate Range: {appointments_df['appointment_date'].min()} to {appointments_df['appointment_date'].max()}")
print(f"\nAppointment Status Breakdown:")
print(appointments_df['status'].value_counts())
print(f"\nOverall No-Show Rate: {(appointments_df['status'] == 'no_show').mean() * 100:.1f}%")
print(f"Overall Cancellation Rate: {(appointments_df['status'] == 'cancelled').mean() * 100:.1f}%")
print(f"Overall Completion Rate: {(appointments_df['status'] == 'completed').mean() * 100:.1f}%")
print("\n" + "="*50)
print("Data generation complete! Files ready for analysis.")
print("="*50)
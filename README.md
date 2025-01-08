# Hospital-Data-Analysis
An analysis of hospital data using SQL and Tableau.

## OVERVIEW

The project uses hospital data containing five tables: patient, doctor, appointment, billing, and medical procedure.

### OBJECTIVE

There are a few questions I aimed to answer from the analysis:

1. What trends are observed in the appointment dates? and are there specific times of the year when appointments peak?

2. Which doctors handle the most appointments and is there a correlation between a doctor's specialization and the billing amount?

3. Which medical procedures are most frequently performed? Is there a particular specialization associated with the procedures? 

4. What is the distribution of billing amounts?

5. How does the total billing amount vary by doctor specialization?

### DATA

The dataset was obtained from Kaggle
[Healthcare management dataset](https://www.kaggle.com/datasets/anouskaabhisikta/healthcare-management-system/data)

### TOOLS

MySQL and Tableau Public

### DATA CLEANING
- Concatenated two columns to create the email address column and dropped the irrelevant column from the doctor table.

````
  CREATE TABLE doctor_copy
(DoctorID INT,
DoctorName TEXT,
Specialization TEXT,
DoctorContact TEXT,
Email VARCHAR(250)
);
````
````
INSERT INTO doctor_copy 
SELECT * FROM doctor;
````
SET SQL_SAFE_UPDATES = 0;
````
UPDATE doctor_copy 
SET Email = CONCAT(DoctorName, DoctorContact);
````
````
ALTER TABLE doctor_copy
DROP COLUMN DoctorContact;
````
- Concatenated two columns - the first and last name to create a name column in the patient table.

````
ALTER TABLE patient
ADD COLUMN Patientname VARCHAR(250) AFTER lastname;

UPDATE patient
SET Patientname = concat(firstname," ",lastname);

ALTER TABLE patient
DROP COLUMN lastname ;

````
- Renamed the medical procedure column to medical_procedure for ease of use.

````
RENAME TABLE `medical procedure` TO medical_procedure;
````
- Found and replaced 22 unnamed items with NULL on the billing table to exclude them from the analysis.

````
SELECT *
FROM billing
WHERE NULLIF(Items, '') IS NULL;

UPDATE billing
SET Items = Null
WHERE NULLIF(Items, '') IS NULL;

````

### EXPLORATORY DATA ANALYSIS

````
-- Records run from January 2020 to December 2023

SELECT 
MAX(`Date`) as last_date,
MIN(`Date`) AS first_date
FROM appointment;
````
````
-- Billing procedures by revenue generated

SELECT Items,
COUNT(Items) AS Items_count,
SUM(Amount) AS Total_revenue
FROM patient_management.billing
GROUP BY Items
ORDER BY Total_revenue DESC;
````
````
-- Count of doctors by specialization

SELECT Specialization,
COUNT(Specialization) AS doctors_per_speciality
FROM doctor
GROUP BY Specialization
ORDER BY doctors_per_speciality DESC;
````
````
-- Exploring medical procedures(count)

SELECT 
ProcedureName,
COUNT(ProcedureName) AS number_of_procedures
FROM medical_procedure
GROUP BY ProcedureName
ORDER BY number_of_procedures DESC;
````
````
-- Appointment/doctor table join to explore by specialty and appointments

SELECT 
    D.Specialization,
    COUNT(A.AppointmentID) AS Appointments_count
FROM
    appointment A
        JOIN
    doctor D ON D.DoctorID = A.DoctorID
GROUP BY  D.Specialization
ORDER BY appointments_count DESC;
````
````
-- Appointments count per doctor

SELECT 
D.DoctorName,
D.Specialization,
COUNT(DAYNAME(`Date`)) AS Appointments
FROM appointment A 
JOIN medical_procedure MP
ON A.AppointmentID = MP.AppointmentID
JOIN doctor D 
ON A.DoctorID = D.DoctorID 
JOIN patient P
ON A.PatientID = P.PatientID
GROUP BY D.DoctorName, D.Specialization
ORDER BY Appointments DESC;
````
````
-- Average appointment calculation

WITH Appointments_per_doctor AS (SELECT 
D.DoctorName,
D.Specialization,
COUNT(DAYNAME(`Date`)) AS Appointments
FROM appointment A 
JOIN medical_procedure MP
ON A.AppointmentID = MP.AppointmentID
JOIN doctor D 
ON A.DoctorID = D.DoctorID 
JOIN patient P
ON A.PatientID = P.PatientID
GROUP BY D.DoctorName, D.Specialization
ORDER BY Appointments DESC)
SELECT 
ROUND(AVG(Appointments)) AS Avg_appointments
FROM Appointments_per_doctor;
````
````
-- Joining multiple tables and using a CTE to extract appointments by year and specialization

WITH Time_breakdown AS( 
SELECT 
MP.ProcedureName,
D.DoctorName,
D.Specialization,
P.Patientname,
YEAR(`Date`) AS Appointment_year,
MONTHNAME(`Date`) AS Month_name,
DAYNAME(`Date`) AS Appointment_day
FROM appointment A 
JOIN medical_procedure MP
ON A.AppointmentID = MP.AppointmentID
JOIN doctor D 
ON A.DoctorID = D.DoctorID 
JOIN patient P
ON A.PatientID = P.PatientID)
SELECT
Specialization,
Appointment_Year,
COUNT(DoctorName) AS Appointments
FROM Time_breakdown
GROUP BY Specialization, Appointment_Year
ORDER BY Appointment_Year,Appointments DESC;
````
````
-- Multiple joins to obtain a CTE with comprehensive information for further querying

WITH Amount_per_doctor AS (
    SELECT 
        A.AppointmentID,
        A.`Date`,
        A.`Time`,
        MP.ProcedureName,
        D.DoctorName,
        D.Specialization,
        P.Patientname,
        B.Amount
    FROM Appointment A 
    JOIN medical_procedure MP
        ON A.AppointmentID = MP.AppointmentID
    JOIN doctor D 
        ON A.DoctorID = D.DoctorID 
    JOIN patient P
        ON A.PatientID = P.PatientID
    JOIN billing B 
        ON P.PatientID = B.PatientID
) -- To rank doctors by revenue and obtain average per specialization window
SELECT 
    Specialization,
    DoctorName,
    SUM(Amount) AS Doctor_total,
    ROUND(AVG(SUM(Amount)) OVER(PARTITION BY Specialization))AS Speciality_avg,
    RANK() OVER(PARTITION BY Specialization ORDER BY SUM(Amount) DESC) AS Rank_by_speciality
FROM Amount_per_doctor
GROUP BY Specialization, DoctorName;
````
````
-- Multiple CTEs get the doctors ranked number 1 per specialty by amount billed

WITH Amount_per_doctor AS
(
SELECT 
A.AppointmentID,
A.`Date`,
A.`Time`,
MP.ProcedureName,
D.DoctorName,
D.Specialization,
P.Patientname,
B.Amount
FROM Appointment A 
JOIN medical_procedure MP
ON A.AppointmentID = MP.AppointmentID
JOIN doctor D 
ON A.DoctorID = D.DoctorID 
JOIN patient P
ON A.PatientID = P.PatientID
JOIN billing B 
ON P.PatientID = B.PatientID
),
Ranking AS
( -- Partitioning doctors by specialty then ranking by total bill per doctor
SELECT 
Specialization,
DoctorName,
SUM(Amount) AS doctor_total,
RANK() OVER(PARTITION BY Specialization ORDER BY SUM(Amount) DESC) as rank_by_speciality
FROM Amount_per_doctor
GROUP BY Specialization, DoctorName
)
SELECT * FROM Ranking 
WHERE rank_by_speciality = 1
ORDER BY doctor_total DESC; -- Gives top billing doctors by specialization over the period 
````
````
-- To extract days, months, and years of appointment.

SELECT 
MP.ProcedureName,
D.DoctorName,
D.Specialization,
P.Patientname,
YEAR(`Date`) AS Appointment_year,
MONTHNAME(`Date`) AS Month_name,
DAYNAME(`Date`) AS Appointment_day
FROM appointment A 
JOIN medical_procedure MP
ON A.AppointmentID = MP.AppointmentID
JOIN doctor D 
ON A.DoctorID = D.DoctorID 
JOIN patient P
ON A.PatientID = P.PatientID;
````

### DATA VISUALISATION

![Hospital data analysis dashboard](https://github.com/user-attachments/assets/0b3d72e9-bd53-4129-93ba-888fc145c253)

### INSIGHTS

1. Appointments distribution:

November is the peak month and Thursday is the peak day, whereas October and February are the least popular months for appointments.

2. Doctor Performance:

Radiologists handle the most number of appointments overall and geriatric specialists the least.
There isn’t a discernible pattern in specialty and billing, but the top two doctors are critical care specialists tied at $ 20,776,809.
17 is the highest number of observed appointments per doctor while 1 is the lowest at an average of 4 per doctor.
Oncology has the highest number of specialists at 54 and Hospice and Palliative care has the lowest at 26.

3. Procedure Popularity:

Insulin pump management is the most popular with 25 cases, and the highest revenue at $14,083,138.
X-rays, CT scans, and MRI scans are the highest number of billed items which corresponds to the number of radiology appointments.

4. Billing Analysis:

The top-performing doctors per specialty are outliers contributing to raising the average billing rate per specialization,
and as a result, most other doctors in the category bill below average.
Critical care and psychiatry have the top-billing doctors, while ophthalmology and infectious diseases are the bottom two.

### RECOMMENDATION 

1. The number of appointments by specialization can inform disease and condition trends over time.

2. Specializations' staffing can be restructured based on billing, procedures, and appointments.

3. The most common procedures can be used to predict patient needs and to inform public health awareness.

4. The top billing doctors can be investigated further to see if they are outliers in their categories or if there are discrepancies in remuneration.

5. A review of doctors with below-average appointments can be done to determine if patient demand or doctor performance is the problem.


CREATE DATABASE patient_management;
USE patient_management;
SHOW TABLES FROM patient_management;

SELECT 
MIN(`Date`) start_date,
MAX(`Date`) AS finish_date
FROM patient_management.appointment;

-- Data cleaning 

SELECT * FROM patient_management.doctor;

-- Created a new column with the complete Email address and dropped the "DoctorContact" column
SELECT 
    DoctorID,
    DoctorName,
    Specialization,
    DoctorContact,
    Email,
    CONCAT(DoctorName, DoctorContact) AS Email
FROM
    doctor;
    
-- Checking data types on the doctor table so as to create a copy of the same.    
SELECT DATA_TYPE 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_SCHEMA = 'patient_management' AND TABLE_NAME = 'doctor'; 

CREATE TABLE doctor_copy
(DoctorID INT,
DoctorName TEXT,
Specilization TEXT,
DoctorContact TEXT,
Email VARCHAR(250)
);

INSERT INTO doctor_copy 
SELECT * FROM doctor;

SET SQL_SAFE_UPDATES = 0;

UPDATE doctor_copy 
SET Email = CONCAT(DoctorName, DoctorContact);

ALTER TABLE doctor_copy
DROP COLUMN DoctorContact;

SELECT * FROM doctor_copy;

RENAME TABLE `medical procedure` TO medical_procedure;

SELECT
PatientID,
firstname,
lastname,
concat(firstname," ",lastname) AS Patientname,
email
FROM patient;

ALTER TABLE patient
ADD COLUMN Patientname VARCHAR(250) AFTER lastname;

SET SQL_SAFE_UPDATES = 0;

UPDATE patient
SET Patientname = concat(firstname," ",lastname);

ALTER TABLE patient
DROP COLUMN lastname ;

-- Checking for missing values. 22 found and replaced with NULL
SELECT *
FROM billing
WHERE NULLIF(Items, '') IS NULL;

UPDATE billing
SET Items = Null
WHERE NULLIF(Items, '') IS NULL;

DELETE FROM  billing 
WHERE ITEMS ="Null";

-- Exploratory data analysis
-- First and last appointment dates

SELECT 
MAX(`Date`) as last_date,
MIN(`Date`) AS first_date
FROM appointment;

-- Billing procedures by revenue generated
SELECT Items,
COUNT(Items) AS Items_count,
SUM(Amount) AS Total_revenue
FROM patient_management.billing
GROUP BY Items
ORDER BY Total_revenue DESC;

-- Count of doctors by specialization
SELECT Specialization,
COUNT(Specialization) AS doctors_per_speciality
FROM doctor
GROUP BY Specialization
ORDER BY doctors_per_speciality DESC;

-- Medical procedure table exploring popular vs unpopular procedures
SELECT 
ProcedureName ,
COUNT(ProcedureName) AS number_of_procedures
FROM medical_procedure
GROUP BY ProcedureName
ORDER BY number_of_procedures DESC;

-- Appointments count per doctor
SELECT 
D.Specialization,
COUNT(DAYNAME(`Date`)) AS Appointments
FROM appointment A 
JOIN medical_procedure MP
ON A.AppointmentID = MP.AppointmentID
JOIN doctor D 
ON A.DoctorID = D.DoctorID 
JOIN patient P
ON A.PatientID = P.PatientID
GROUP BY D.Specialization
ORDER BY Appointments DESC;

-- Appointments per doctor per specialization and average appointments

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
GROUP BY D.DoctorName,D.Specialization
ORDER BY Appointments DESC)
SELECT 
ROUND(AVG(Appointments)) AS Avg_appointments
FROM Appointments_per_doctor;

-- Appointment/doctor table join to explore by speciality and appointments
SELECT 
	D.DoctorName,
    D.Specialization,
    COUNT(A.AppointmentID) AS Appointments_count
FROM
    appointment A
        JOIN
    doctor D ON D.DoctorID = A.DoctorID
GROUP BY D.DoctorName, D.Specialization
ORDER BY appointments_count DESC;
 
-- Joining multiple tables to extract appointments by year and specialization
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
GROUP BY Specialization,Appointment_Year
ORDER BY Appointment_Year,Appointments DESC;


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
) -- To rank doctors by revenue and obtain average per specialization
SELECT 
    Specialization,
    DoctorName,
    SUM(Amount) AS Doctor_total,
    ROUND(AVG(SUM(Amount)) OVER(PARTITION BY Specialization))AS Speciality_avg,
    RANK() OVER(PARTITION BY Specialization ORDER BY SUM(Amount) DESC) AS Rank_by_speciality
FROM Amount_per_doctor
GROUP BY Specialization, DoctorName;

-- To get the doctors ranked 1 only per speciality(including tied)
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
( -- Partitioning doctors by speciality then ranking by total bill per doctor
SELECT 
Specialization,
DoctorName,
SUM(Amount) AS Doctor_total,
ROUND(AVG(SUM(Amount)) OVER(PARTITION BY Specialization))AS Speciality_avg,
RANK() OVER(PARTITION BY Specialization ORDER BY SUM(Amount) DESC) as Rank_by_speciality
FROM Amount_per_doctor
GROUP BY Specialization,DoctorName
)
SELECT * FROM Ranking 
WHERE rank_by_speciality = 1
ORDER BY doctor_total DESC
LIMIT 10; -- Gives top billing doctors by specialization over the period 

-- To extract days,months and years of appointment.
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

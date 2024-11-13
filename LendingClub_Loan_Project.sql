/* Part 1: Data Wrangling for Lending Club Project
 Data set: https://www.kaggle.com/datasets/ethon0426/lending-club-20072020q1
 A raw subset for the 2018 year was created from the linked dataset and now I will clean it

 loan_data_2018_RAW.csv is imported as a flat file with Microsoft SQL Server Management Studio
	where no primary key is selected, and where NULL values are allowed in every column

Data cleaning steps:
1: Remove all duplicates
2: Standardize data
3: Manage NULL values and remove unnecessary rows/columns
*/

USE loan_data_database -- select the database we named after importing the raw CSV file

--------------------------------------------------------------------------------------
/*
1: Remove all duplicates
*/
--------------------------------------------------------------------------------------

-- NOTE: N is written before every string to declare 
--		it as nvarchar as opposed to varchar for unicode
--		this is done here with the staging table and in every procedure created further below

-- create staging table by duplicating the raw table format and copying all raw data into it
-- this way if any mistakes are made, the untouched raw data table will still exist to reference 
IF NOT EXISTS (SELECT * FROM sys.objects 
WHERE [object_id] = OBJECT_ID(N'[dbo].[loan_data_2018_staging]') AND type in (N'U'))
SELECT * INTO loan_data_2018_staging FROM loan_data_2018_RAW

-- used to check the compatibility level of the database and prevents SQL Server Management Studio
-- from issuing a warning for the cte_duplicates common table expression below
SELECT	name, compatibility_level
FROM	sys.databases
WHERE   name LIKE '%loan_data_database%'

-- create a CTE to isolate duplicate entries, where the data in all columns is exactly the same
-- 8 duplicate rows exist
WITH cte_duplicates AS 
(
	SELECT *, 
	ROW_NUMBER() OVER (
		PARTITION BY id, loan_amount, term, interest_rate, installment, grade, sub_grade, employee_length, home_ownership, 
			annual_income, issue_date, loan_status, purpose, purpose2, address_state, debt_to_income, total_payment ORDER BY (SELECT NULL)) AS row_num
	FROM loan_data_2018_staging
) 
SELECT * 
FROM cte_duplicates
WHERE row_num > 1

-- create a derived table with row_num column to count and delete duplicate rows that were isolated in the CTE above 
-- 8 duplicate rows removed
DELETE dt_duplicates
FROM
(
	SELECT *, row_num = ROW_NUMBER() OVER (PARTITION BY id, loan_amount, term, interest_rate, installment, 
		grade, sub_grade, employee_length, home_ownership, annual_income, issue_date, loan_status, purpose, purpose2, 
		address_state, debt_to_income, total_payment ORDER BY (SELECT NULL))
	FROM loan_data_2018_staging
) AS dt_duplicates
WHERE row_num > 1 

-- 57171 rows in raw table, 57163 rows in staging table, 8 duplicate rows removed
SELECT *
FROM loan_data_2018_staging

--------------------------------------------------------------------------------------
/*
2: Standardize Data
*/
--------------------------------------------------------------------------------------

-- removing any potential trailing spaces from string fields
/*
UPDATE loan_data_2018_staging2
SET term = TRIM(term),
	grade = TRIM(grade),
	... etc ... manually list out all string columns to trim
*/

/*
NOTE:
	the above approach for trimming string fields works, but it would
	become impractical when dealing with a table with a large number
	of string fields, therefore I will write a script to trim all
	string fields to solve this efficiency issue
*/

-------------------------------------------------------------------------
/*
	stored procedure to trim all columns in a table
*/
-------------------------------------------------------------------------
IF EXISTS 
(
	SELECT type_desc, type
    FROM sys.procedures WITH(NOLOCK)
    WHERE NAME = 'trim_string_fields' AND type = 'P'
)	
DROP PROCEDURE trim_string_fields
GO
CREATE PROCEDURE trim_string_fields @table nvarchar(max) AS DECLARE @query AS nvarchar(max)

-- trim all string values in every column and show which columns were trimmed in output
SET @query = STUFF((SELECT N', ' + QUOTENAME([name]) + N' = TRIM(' + QUOTENAME([name]) + N')' 
FROM sys.columns 
WHERE [object_id] = OBJECT_ID(@table) AND [system_type_id] IN(29,35,99,167,175,231)
FOR XML PATH('')),1,1,'')
 
SET @query = N'UPDATE ' + @table + N' SET' + @query
PRINT @query

EXEC(@query)
GO
-------------------------------------------------------------------------
-- test the script by adding trailing/leading spaces to all 'PA' state values
-- (1880 rows affected) trailing space address_state
UPDATE loan_data_2018_staging
SET address_state = '  PA   '
WHERE address_state = 'PA'

-- we can see that all 'PA' values now have the trailing/leading spaces added
SELECT * FROM loan_data_2018_staging

-- run procedure to trim all columns including our test above
EXEC trim_string_fields loan_data_2018_staging

-- after executing the trim script above, we see that it works
SELECT * FROM loan_data_2018_staging
-------------------------------------------------------------------------

-- visually inspect all string field categories to check for errors/inconsistencies

-- it appears the purpose field was split into two columns
SELECT DISTINCT purpose, purpose2
FROM loan_data_2018_staging
ORDER BY purpose2

-- by joining purpose1 with purpose2 on the id, we prove that 6 categories need to be merged, namely:
--	"Credit Card", "Debt Consolidation", "Home Improvement", "Major Purchase",
--	"Renewable Energy", and "Small Business"
SELECT DISTINCT t1.purpose, t2.purpose2
FROM loan_data_2018_staging t1
FULL OUTER JOIN loan_data_2018_staging t2
ON t1.id = t2.id

-- purpose_merged gives us the merged columns as they should be 
SELECT DISTINCT purpose, purpose2, ISNULL(purpose,'') + ' ' + ISNULL(purpose2,'') AS purpose_merged
FROM loan_data_2018_staging

-- create a second staging table with a consolidated purpose column (in the same position) to store the merged values
IF NOT EXISTS (SELECT * FROM sys.objects 
WHERE [object_id] = OBJECT_ID(N'[dbo].[loan_data_2018_staging2]') AND type in (N'U'))
CREATE TABLE [dbo].[loan_data_2018_staging2](
	[id] [int] NULL,
	[loan_amount] [int] NULL,
	[term] [nvarchar](50) NULL,
	[interest_rate] [float] NULL,
	[installment] [float] NULL,
	[grade] [nvarchar](50) NULL,
	[sub_grade] [nvarchar](50) NULL,
	[employee_length] [nvarchar](50) NULL,
	[home_ownership] [nvarchar](50) NULL,
	[annual_income] [float] NULL,
	[issue_date] [date] NULL,
	[loan_status] [nvarchar](50) NULL,
	[purpose] [nvarchar](50) NULL,
	[address_state] [nvarchar](50) NULL,
	[debt_to_income] [float] NULL,
	[total_payment] [float] NULL,
) ON [PRIMARY]

-- copy all needed fields from the original staging table into the second staging table
INSERT INTO loan_data_2018_staging2
SELECT id, loan_amount, term, interest_rate, installment, grade, sub_grade, employee_length, home_ownership, 
			annual_income, issue_date, loan_status, ISNULL(purpose,'') + ' ' + ISNULL(purpose2,'') AS purpose, 
			address_state, debt_to_income, total_payment
FROM loan_data_2018_staging

-- rerun procedure to trim all columns on the newly created loan_data_2018_staging2
-- since values in the first purpose column that didn't have any corressponding value in the
-- 2nd purpose column will be left with a trailing ' ' space
EXEC trim_string_fields loan_data_2018_staging2

-- all purpose categories have been merged into one and only 1 purpose column remains
SELECT DISTINCT purpose
FROM loan_data_2018_staging2
ORDER BY purpose

-- I will continue working with the 2nd staging table that has the most cleaned data

-- purpose has some rows where the Other category has leading/trailing punctuation '.' marks 
SELECT DISTINCT purpose
FROM loan_data_2018_staging2
ORDER BY purpose

-- remove all leading/trailing '.' dots from the purpose field and rerun query above to confirm
UPDATE loan_data_2018_staging2
SET purpose = TRIM('.' FROM purpose)

SELECT DISTINCT term
FROM loan_data_2018_staging2
ORDER BY term

SELECT DISTINCT grade
FROM loan_data_2018_staging2
ORDER BY grade

SELECT DISTINCT sub_grade
FROM loan_data_2018_staging2
ORDER BY sub_grade

SELECT DISTINCT employee_length
FROM loan_data_2018_staging2
ORDER BY employee_length

-- home_ownership has 2 redundant Rent labels as 'Renter/Renting' which need to be consolidated to Rent
SELECT DISTINCT home_ownership
FROM loan_data_2018_staging2
ORDER BY home_ownership

-- fixed 14 rows showing as Renter or Renting and renamed to Rent, rerun query above to confirm only Rent remains
UPDATE loan_data_2018_staging2
SET home_ownership = 'Rent'
WHERE home_ownership IN ('Renter', 'Renting')

SELECT DISTINCT loan_status
FROM loan_data_2018_staging2
ORDER BY loan_status

SELECT DISTINCT address_state
FROM loan_data_2018_staging2
ORDER BY address_state

-- issue dates are already standardized so the part below will be commented out
SELECT DISTINCT issue_date
FROM loan_data_2018_staging2
ORDER BY issue_date

/*
-- format all date entries to MMMM-yyyy format
SELECT DISTINCT FORMAT(issue_date, 'MMMM-yyyy') AS formatted_issue_date
FROM loan_data_2018_staging2
ORDER BY formatted_issue_date

-- update issue_date field to standardize date format
UPDATE loan_data_2018_staging2
SET issue_date = FORMAT(issue_date, 'MMMM-yyyy')
WHERE issue_date IS NOT NULL -- to ensure we don't try to format NULL values
*/

-- ensure there aren't any negative numerical values present; 0 found
SELECT loan_amount, interest_rate, installment, debt_to_income, total_payment
FROM loan_data_2018_staging2
WHERE loan_amount < 0 OR interest_rate < 0 OR installment < 0 OR debt_to_income < 0 OR total_payment < 0

/*
3: Manage NULL values and remove unnecessary rows/columns

NOTE:
	I will write a script to find any potential NULL and/or
	empty values for the same efficiency reason that I wrote
	one to trim all columns
*/

-------------------------------------------------------------------------
/*
	stored procedure to display all null values in a table
*/
-------------------------------------------------------------------------
IF EXISTS 
(
	SELECT type_desc, type
    FROM sys.procedures WITH(NOLOCK)
    WHERE NAME = 'select_null_values' AND type = 'P'
)	
DROP PROCEDURE select_null_values
GO
CREATE PROCEDURE select_null_values @table nvarchar(max) AS DECLARE @query AS nvarchar(max)

-- extract the table schema without extracting any data within
SET @query = N'SELECT * FROM ' + @table + N' WHERE 1 = 0'

-- check for NULL values in every column
SELECT @query += N' OR ' + QUOTENAME(name) + N' IS NULL'
FROM sys.columns
WHERE [object_id] = OBJECT_ID(@table)

EXEC(@query)
GO
-------------------------------------------------------------------------
-- run procedure to select NULL values in all columns, 3 rows with NULL data exist
EXEC select_null_values loan_data_2018_staging2

-- delete 3 rows with NULL data
-- these same 3 rows were also causing the NULL value to appear in several columns
DELETE
FROM loan_data_2018_staging2
WHERE id = 131407188 OR id = 137917888 OR id = 139305488

-- running one more time shows that no NULL values remain in the table
EXEC select_null_values loan_data_2018_staging2

-- the annual_income column is not needed for my analysis so it must be removed
ALTER TABLE loan_data_2018_staging2
DROP COLUMN IF EXISTS annual_income

/*
-- this portion is optional and was used for further testing of the above procedure
-- test the script by nullifying all D grade values
-- (13245 rows affected) NULL grade values
UPDATE loan_data_2018_staging2
SET grade = NULL
WHERE grade IN ('D')

EXEC select_null_values loan_data_2018_staging2

-- (13245 rows affected) Undo NULL change after confirming that the script above works
UPDATE loan_data_2018_staging2
SET grade = 'D'
WHERE grade IS NULL

EXEC select_null_values loan_data_2018_staging2
*/
-------------------------------------------------------------------------
/*
	stored procedure to display all empty '' values in a table
*/
-------------------------------------------------------------------------
IF EXISTS 
(
	SELECT type_desc, type
    FROM sys.procedures WITH(NOLOCK)
    WHERE NAME = 'select_empty_values' AND type = 'P'
)
DROP PROCEDURE select_empty_values
GO
CREATE PROCEDURE select_empty_values @table nvarchar(max) AS DECLARE @query AS nvarchar(max)

SET @query = N'SELECT * FROM ' + @table + N' WHERE 1 = 0'

-- check for empty '' values (written as '''' since escape characters are needed) in every column
SELECT @query += N' OR ' + QUOTENAME(name) + N' LIKE '''''
FROM sys.columns
WHERE [object_id] = OBJECT_ID(@table)

EXEC(@query)
GO
-------------------------------------------------------------------------

-- no empty values remain in the table
EXEC select_empty_values loan_data_2018_staging2

/*
-- this portion is optional and was used for further testing of the above procedure
-- test the script by emptying the value of Rent values
-- (18274 rows affected) '' Rent values
UPDATE loan_data_2018_staging2
SET home_ownership = ''
WHERE home_ownership IN ('Rent')

EXEC select_empty_values loan_data_2018_staging2

--18274 Undo empty '' values change after confirming that the corresponding script works
UPDATE loan_data_2018_staging2
SET home_ownership = 'Rent'
WHERE home_ownership = ''

EXEC select_empty_values loan_data_2018_staging2
*/

-- drop intermediate staging table
--DROP TABLE loan_data_2018_staging -- commented out for the purposes of reviewing the previous queries

-- rename final cleaned staging table
EXEC sp_rename 'loan_data_2018_staging2', 'loan_data_2018'
--EXEC sp_rename 'loan_data_2018', 'loan_data_2018_staging2' -- undo name change to review previous queries 

-- 57160 rows with 15 columns in final cleaned table
SELECT * FROM loan_data_2018
ORDER BY id


-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------

/* Part 2: Exploratory Data Analysis for Lending Club Project
 Data set: https://www.kaggle.com/datasets/ethon0426/lending-club-20072020q1
 A raw subset for the 2018 year was cleaned in Part 1 of the Project

 Now I will perform exploratory data analysis on the cleaned subset
*/

USE loan_data_database

-- 57160 total loan applications issued, 3253 issued in December alone, and 3606 in November
SELECT COUNT(id) AS total_loan_applications FROM loan_data_2018  
SELECT COUNT(id) AS MTD_total_loan_applications FROM loan_data_2018 WHERE MONTH(issue_date) = 12  
SELECT COUNT(id) AS prior_MTD_total_loan_applications FROM loan_data_2018 WHERE MONTH(issue_date) = 11  

-- $1,138.2M in total funded loans, $65M funded in December alone, and $74M in November
SELECT FORMAT(SUM(loan_amount), 'C', 'en-US') AS total_funded_amount FROM loan_data_2018 
SELECT FORMAT(SUM(loan_amount), 'C', 'en-US') AS MTD_total_funded_amount FROM loan_data_2018 WHERE MONTH(issue_date) = 12 
SELECT FORMAT(SUM(loan_amount), 'C', 'en-US') AS prior_MTD_total_funded_amount FROM loan_data_2018 WHERE MONTH(issue_date) = 11

-- $840M in total payments received, $38.5M received in December alone, and $45.5M in November
-- 2018 has not seen overall profitability as the total payments received are 73.8% of the total funded loans
SELECT FORMAT(SUM(total_payment), 'C', 'en-US') AS total_amount_received FROM loan_data_2018 
SELECT FORMAT(SUM(total_payment), 'C', 'en-US') AS MTD_total_amount_received FROM loan_data_2018 WHERE MONTH(issue_date) = 12
SELECT FORMAT(SUM(total_payment), 'C', 'en-US') AS prior_MTD_total_amount_received FROM loan_data_2018 WHERE MONTH(issue_date) = 11 

-- avg interest rate of 14.75% for 2018, avg 14.33% interest rate in December alone, and 14.29% in in November
SELECT ROUND(AVG(interest_rate) * 100, 2) AS avg_interest_rate FROM loan_data_2018 
SELECT ROUND(AVG(interest_rate) * 100, 2) AS MTD_avg_interest_rate FROM loan_data_2018 WHERE MONTH(issue_date) = 12
SELECT ROUND(AVG(interest_rate) * 100, 2) AS prior_MTD_avg_interest_rate FROM loan_data_2018 WHERE MONTH(issue_date) = 11

-- avg DTI of 20.97% for 2018, 20.84% avg DTI in December alone, and 20.89% in November
SELECT ROUND(AVG(debt_to_income) * 100, 2) AS avg_debt_to_income FROM loan_data_2018
SELECT ROUND(AVG(debt_to_income) * 100, 2) AS MTD_avg_debt_to_income FROM loan_data_2018 WHERE MONTH(issue_date) = 12
SELECT ROUND(AVG(debt_to_income) * 100, 2) AS prior_MTD_avg_debt_to_income FROM loan_data_2018 WHERE MONTH(issue_date) = 11

-----------------------------------------------------------------------
-- 12.6% of all loans issued have been charged off, where this accounts for 7200 loans and $145.3M in funds where $54.5M was paid 
-- hence $90.8M total was charged off in 2018
SELECT
	(SELECT (COUNT(CASE WHEN loan_status = 'Charged Off' THEN id END) * 100.0) / COUNT(id) FROM loan_data_2018) AS bad_loan_percentage,
	COUNT(id) AS bad_loan_applications,
	FORMAT(SUM(loan_amount), 'C', 'en-US') AS bad_loan_funded_amount,
	FORMAT(SUM(total_payment), 'C', 'en-US') AS bad_loan_amount_received,
	FORMAT(SUM(loan_amount)-SUM(total_payment), 'C', 'en-US') AS total_charged_off
FROM loan_data_2018
WHERE loan_status = 'Charged Off'

-- 87.4% of all loans issued have been fully paid or are current, where this accounts for 50000 loans and $992.9M in funds where $785.5M was paid 
-- hence $237.1M is the approximate total outstanding loan balance for 2018 ($207.4M remaining * avg annual interest of 14.7%)
-- outstanding loan balance does not account for fees, penalties, compounding, and other hidden charges as we don't have that data in the subset
SELECT
	(SELECT (COUNT(CASE WHEN loan_status = 'Current' OR loan_status = 'Fully Paid' THEN id END) * 100.0) / COUNT(id) FROM loan_data_2018) AS good_loan_percentage,
	COUNT(id) AS good_loan_applications,
	FORMAT(SUM(loan_amount), 'C', 'en-US') AS good_loan_funded_amount,
	FORMAT(SUM(total_payment), 'C', 'en-US') AS good_loan_amount_received,
	FORMAT((SUM(loan_amount)-SUM(total_payment))*(1+AVG(interest_rate)), 'C', 'en-US') AS total_outstanding_balance
FROM loan_data_2018
WHERE loan_status = 'Current' OR loan_status = 'Fully Paid'

-----------------------------------------------------------------------
-- the average interest rate for bad loans at 17.45% is only slightly higher than the rates for good loans averaging 14.43%
-- of the 50000 loans in good standing: 17525 are fully paid and 32458 are current
-- of the loans that are current about 63.2% of the total funded amount (not including interest) has been repaid
-- all loan applicants had similar average DTI levels at around 21%
SELECT
        loan_status AS Loan_Status,
        COUNT(id) AS Total_Loan_Applications,
		FORMAT(SUM(loan_amount), 'C', 'en-US') AS Total_Funded_Amount,
        FORMAT(SUM(total_payment), 'C', 'en-US') AS Total_Amount_Received,
        AVG(interest_rate * 100) AS Avg_Interest_Rate,
        AVG(debt_to_income * 100) AS Avg_Debt_to_Income
FROM loan_data_2018
GROUP BY loan_status 
ORDER BY loan_status ASC

SELECT 
	loan_status AS Loan_Status,
	FORMAT(SUM(total_payment), 'C', 'en-US') AS MTD_Total_Amount_Received,
	FORMAT(SUM(loan_amount), 'C', 'en-US') AS MTD_Total_Funded_Amount
FROM loan_data_2018
WHERE MONTH(issue_date) = 12 AND YEAR(issue_date) = 2018
GROUP BY loan_status
ORDER BY loan_status ASC

-- Loans which were fully paid resulted in a profit of 12% (which is less than avg interest of 14.6%) or $39M, whereas chargeoffs were a loss of 62.5% or $90.8M
-- hence net loss was $51.8M among Fully Paid and Charged Off loans
SELECT 
	loan_status AS Loan_Status,
	(SUM(total_payment) / SUM(loan_amount)-1) AS Profit_Multiple,
	FORMAT((SUM(loan_amount) * (SUM(total_payment) / SUM(loan_amount)-1)), 'C', 'en-US') AS Profit 
FROM loan_data_2018 WHERE loan_status = 'Fully Paid' OR loan_status = 'Charged Off'
GROUP BY loan_status 

-----------------------------------------------------------------------

-- the purpose of most loans was for debt consolidation (58.5% of all loans) and credit cards (21.5% of all loans)
SELECT 
	purpose AS Loan_Purpose,
	COUNT(id) AS Total_Loan_Applications,
	COUNT(id) * 100.0 / (SELECT COUNT(id) FROM loan_data_2018) AS Total_Loan_Applications_Percentage,
	FORMAT(SUM(loan_amount), 'C', 'en-US') AS Total_Funded_Amount,
	FORMAT(SUM(total_payment), 'C', 'en-US') AS Total_Received_Amount
FROM loan_data_2018
-- WHERE loan_status = 'Charged Off' -- used to compare between charged off loans only and all loans to see if the distribution of loans in each category varies
GROUP BY purpose
ORDER BY Total_Loan_Applications DESC

-- 40% of all loans issued were to those who had 10+ years employment history
SELECT 
	employee_length AS Employee_Length,
	COUNT(id) AS Total_Loan_Applications,
	COUNT(id) * 100.0 / (SELECT COUNT(id) FROM loan_data_2018) AS Total_Loan_Applications_Percentage,
    FORMAT(SUM(loan_amount), 'C', 'en-US') AS Total_Funded_Amount,
    FORMAT(SUM(total_payment), 'C', 'en-US') AS Total_Received_Amount
FROM loan_data_2018
-- WHERE loan_status = 'Charged Off'
GROUP BY employee_length
ORDER BY Total_Loan_Applications DESC

-- 58% of loans issued to those who have a mortgage on their house, 32% to renters, and 10% to those who own their house outright
SELECT 
	home_ownership AS Home_Ownership,
	COUNT(id) AS Total_Loan_Applications,
	COUNT(id) * 100.0 / (SELECT COUNT(id) FROM loan_data_2018) AS Total_Loan_Applications_Percentage,
	FORMAT(SUM(loan_amount), 'C', 'en-US') AS Total_Funded_Amount,
	FORMAT(SUM(total_payment), 'C', 'en-US') AS Total_Received_Amount
FROM loan_data_2018
-- WHERE loan_status = 'Charged Off'
GROUP BY home_ownership
ORDER BY Total_Loan_Applications DESC

-- CA is the top state with issued loans at 12.3% of all loans, followed by TX at 8.7%, and FL and NY tied for third at 6.8%
-- IA is the only state with no loans issued
SELECT 
	address_state AS State,
	COUNT(id) AS Total_Loan_Applications,
	COUNT(id) * 100.0 / (SELECT COUNT(id) FROM loan_data_2018) AS Total_Loan_Applications_Percentage,
	FORMAT(SUM(loan_amount), 'C', 'en-US') AS Total_Funded_Amount,
	FORMAT(SUM(total_payment), 'C', 'en-US') AS Total_Received_Amount
--	(SUM(loan_amount)-SUM(total_payment))/SUM(loan_amount) AS funding_gap_percent
FROM loan_data_2018
-- WHERE loan_status = 'Charged Off'
GROUP BY address_state
ORDER BY Total_Loan_Applications DESC

-- May is the month with most loans issued at 10% of all loans, while December is the month with the least at 5.7%
-- Loan applications trended up from Jan. through May, then trended down from May through the rest of the year
SELECT 
	MONTH(issue_date) AS Mnth,
	DATENAME(MONTH, issue_date) AS 'Month',
	COUNT(id) AS Total_Loan_Applications,
	COUNT(id) * 100.0 / (SELECT COUNT(id) FROM loan_data_2018) AS Total_Loan_Applications_Percentage,
	FORMAT(SUM(loan_amount), 'C', 'en-US') AS Total_Funded_Amount,
	FORMAT(SUM(total_payment), 'C', 'en-US') AS Total_Received_Amount
FROM loan_data_2018
-- WHERE loan_status = 'Charged Off'
GROUP BY MONTH(issue_date), DATENAME(MONTH, issue_date)
ORDER BY Mnth

-- 58% of loans issued for a 36 month term while 42% issued for a 60 month term
SELECT 
	term AS Term,
	COUNT(id) AS Total_Loan_Applications,
	COUNT(id) * 100.0 / (SELECT COUNT(id) FROM loan_data_2018) AS Total_Loan_Applications_Percentage,
	FORMAT(SUM(loan_amount), 'C', 'en-US') AS Total_Funded_Amount,
	FORMAT(SUM(total_payment), 'C', 'en-US') AS Total_Received_Amount
FROM loan_data_2018
-- WHERE loan_status = 'Charged Off'
GROUP BY Term
ORDER BY Term

/*
-- 62% of all loans issued were to C - G graded applicants which represent moderate through very high risk loans (and therefore carry higher average interest rates)
	since all applicants in the dataset have manageable DTI levels, these C-G grades have average through very low credit scores, 
	may have a history of missed payments, and potentially carry significant risk factors
-- 38% of all loans issued were to A and B graded applicants having high to good credit scores with overall positive credit history representing low risk loans 
-- While the average interest rate only jumps by about 4% from A to B grades, the interest rate more than doubles from A to C grades, and more than doubles from C to G grades
-- Only 2.3% of all A and B graded loans issued were charged off (about 18% of all bad loans),  
	meaning 82% of all charge offs came from C - G graded loans, hence there is a strong negative correlation between grade and bad loans issued
*/
SELECT 
	grade AS Grade,
	COUNT(id) AS Total_Loan_Applications,
	COUNT(id) * 100.0 / (SELECT COUNT(id) FROM loan_data_2018) AS Total_Loan_Applications_Percentage,
	AVG(interest_rate) AS Average_Interest_Rate,
	AVG(debt_to_income) AS Average_DTI
FROM loan_data_2018
WHERE loan_status = 'Charged Off'
GROUP BY grade
ORDER BY grade ASC

-----------------------------------------------------------------------
/*
Overall Findings:
-	Even in the best case scenario where the roughly 237.1M outstanding loan balance had been paid off for current loans by the end of 2018,
		2018 would've still seen a loss of (1-((total_amount_received + total_outstanding_balance) / total_funded_amount))*100 = 3.86%
			indicating that far too many loans were charged off at 12.6% of all loans issued
-	The distribution of all loans issued by fields like purpose, employee length, home ownership, apps by state, apps by month, and apps by term
		remain consistent regardless of the loan status, hence there is no significant correlation between loan status and these other fields
-	As the loan grade increases (A being the highest) the likelihood of a charge off significantly decreases (especially after increasing from C to B),
		hence there is a strong negative correlation between grade and bad loans issued
-	The first half of the year is the most opportune for capturing as much business as possible
*/

SELECT
    (1 - ((SUM(total_payment) + ((SUM(loan_amount) - SUM(total_payment)) * (1 + AVG(interest_rate)))) 
		/ SUM(loan_amount))) * 100 AS best_case_scenario_net_profit_percent
FROM loan_data_2018

-- contingency table (cross-tabulation) of the categorical loan_status and grade variables to analyze correlation
-- 4th column added to view Bad_Good Ratio of loans per grade for easy interpretation
-- as the Bad_Good_Ratio increases the loan grade decreases (G being the lowest) 
	-- overall risk profile of the corressponding loans increases
SELECT 
    COALESCE(bad_loans.grade, good_loans.grade) AS Grade,
    COALESCE(bad_loans.Total_Bad_Loans, 0) AS Total_Bad_Loans,
    COALESCE(good_loans.Total_Good_Loans, 0) AS Total_Good_Loans,
    CASE 
        WHEN COALESCE(good_loans.Total_Good_Loans, 0) = 0 THEN NULL
        ELSE CAST(COALESCE(bad_loans.Total_Bad_Loans, 0) AS FLOAT) / 
             CAST(COALESCE(good_loans.Total_Good_Loans, 1) AS FLOAT)
    END AS Bad_Good_Ratio
FROM 
    (SELECT 
        grade AS grade,
        COUNT(id) AS Total_Bad_Loans
     FROM loan_data_2018
     WHERE loan_status = 'Charged Off' 
     GROUP BY grade) AS bad_loans
FULL OUTER JOIN 
    (SELECT 
        grade AS grade,
        COUNT(id) AS Total_Good_Loans
     FROM loan_data_2018
     WHERE loan_status = 'Current' OR loan_status = 'Fully Paid'
     GROUP BY grade) AS good_loans
ON 
	bad_loans.grade = good_loans.grade
ORDER BY 
	Grade ASC


-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------

/* Part 3: Tableau Dashboard for Lending Club Project

https://public.tableau.com/app/profile/alexander.j.porter/viz/2018LendingClubDashboard/Summary

*/


-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------

/* Part 4: Presentation for Lending Club Project

https://github.com/Alexander-J-Porter/LendingClub-Loan-End-to-End-Project-using-Excel-SQL-Tableau/blob/main/LendingClub_Loan_Presentation.pdf

*/
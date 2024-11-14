### **NOTE:** The problem statement for this project is defined below. All of the parts **(including SQL output)** are accessible from one PDF file in this repository which is **`LendingClub_Loan_Project.pdf`**..

Parts 1 and 2 utilize SQL and involve data wrangling and exploratory analysis. The code-only file with comments is accessible from `LendingClub_Loan_Project.sql`.
Part 3 is the dashboard **(designed for non-mobile devices)** created with Tableau, accessible from the URL in the PDF file.
Part 4 is the presentation, accessible from **`LendingClub_Loan_Presentation.pdf`**. All tables used in the presentation were created with Excel.

**For Parts 1, 2 and 4: GitHub does not provide previews of PDF files therefore they must be downloaded and viewed on your local device.**

This project uses a subset (57,160 loans from year 2018) of a real-world multi-year dataset sourced from LendingClub available on Kaggle, accessible from **`loan_data_2018.csv`**. Dataset field definitions are accessible from **`LendingClub_Dataset_Information.pdf`**. The original complete dataset is linked in the project PDF file.
All project resources including the raw (dirty) dataset, contingecy table spreadsheet, and dashboard graphics are accessible from `LendingClub_Loan_archive.zip`.

#### **Assumptions:**
* The problem statement is defined under the assumption that the 57,160 loan sample represents all of LendingClub's loans for the entire year of 2018. This assumption is placed to minimize the size of the subset as the approach and methodologies used would remain consistent even if the size of the subset were augmented further.
* For the purposes of this project, LendingClub is to be interpreted in the context of a traditional lending institution (like a bank), rather than as a peer-to-peer lending platform (as it is in the real world).

# **Problem Statement: Analysis of LendingClub Portfolio Performance in 2018**

**Background:** The performance of an institution's loan portfolio is pivotal in understanding its financial health and strategic positioning. In 2018, LendingClub issued a total of 57,160 loans, and by thoroughly analyzing this dataset, we can uncover critical insights related to lending activities, borrower profiles, and prevailing trends. This comprehensive analysis will encompass various key performance indicators (KPIs), such as total loan applications, funded amounts, and repayment behavior. This information will enable informed data-driven decisions that will enhance operational efficiency and profitability.

**Objectives:**

1. **Total Loan Metrics Analysis**: Calculate and analyze the total number of loan applications received, funded amounts, and total amounts received on a monthly and year-to-date basis to identify trends in consumer lending behavior.
1. **Quality Assessment**: Differentiate between 'Good Loans' and 'Bad Loans' by analyzing key performance indicators (KPIs) related to loan status, including good and bad loan application percentages, funded amounts, and total received amounts.
1. **Exploration of Borrower Profiles**: Examine borrower characteristics like employment length, home ownership status, and loan purpose to understand correlation with loan outcomes, including default rates and repayment patterns.
1. **Regional Performance Analysis**: Conduct geographic analyses of lending activities by state to identify regional disparities in lending performance and opportunities for growth in underserved areas.
1. **Financial Health Metrics**: Analyze the average interest rate and average debt-to-income (DTI) ratio to gauge the cost of loans and the financial stability of borrowers.

**Expected Outcome:** By the end of this analysis, LendingClub will:

* Achieve a clear understanding of lending trends and performance metrics, facilitating targeted marketing and loan offerings.
* Develop comprehensive borrower profiles to enhance their ability to evaluate loan applications and reduce default rates.
* Identify regions with high lending activity and potential growth opportunities, increasing loan diversification across states.
* Gain insights into lending strategy adjustments resulting in a minimum net profitability of 6% the following year.

**Data Sources:**

* Loan application data, including metrics such as loan status, funded amounts, and received amounts.
* Geographic data to analyze lending performance by region and identify market opportunities.
* Borrower profile data, including employment and debt-to-income ratios to evaluate borrower suitability and risk factors.

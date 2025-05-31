/*
===================================================================================
Stored Procedure: Load Silver Tables (from Bronze Layer)
===================================================================================
Script Purpose:
	This stored procedure performs the ETL (Extract, Transform, Load) process to 
	populate the 'silver' schema tables from the 'bronze' schema.
		Actions Performed;
			- Truncates Silver tables.
			- Inserts transformed and cleaned data from Bronze into Silver tables.

Parameters:
	None.
		This stored procedure does not accept any parameters or return any values.

Usage Example:
	EXEC silver.load_silver;
===================================================================================
*/

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
	DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME;
	BEGIN TRY
		SET @batch_start_time = GETDATE();
		PRINT '===========================================';
		PRINT 'Loading Silver Layer';
		PRINT '===========================================';

			PRINT '-------------------------------------------';
			PRINT 'Loading CRM Tables';
			PRINT '-------------------------------------------';

			--- Loading silver.crm_cust_info
		SET @start_time = GETDATE();
				PRINT '>> Truncating Table: silver.crm_cust_info';
				TRUNCATE TABLE silver.crm_cust_info;
				PRINT '>> Inserting Data Into: silver.crm_cust_info';
				INSERT INTO silver.crm_cust_info (
					cst_id,
					cst_key,
					cst_firstname,
					cst_lastname,
					cst_marital_status,
					cst_gndr,
					cst_create_date
				)
				SELECT
					cst_id,
					cst_key,
					TRIM(cst_firstname) AS cst_firstname, -- Accounts for unwanted spaces
					TRIM(cst_lastname) AS cst_lastname,
					CASE UPPER(TRIM(cst_marital_status))
						 WHEN 'S' THEN 'Single'
						 WHEN 'M' THEN 'Married'
						 ELSE 'n/a'
					END cst_marital_status, --- Sets marital status to full word rather than abbreviation
					CASE UPPER(TRIM(cst_gndr))
						 WHEN 'F' THEN 'Female'
						 WHEN 'M' THEN 'Male'
						 ELSE 'n/a'
					END cst_gndr, --- Sets gender to full word rather than abbreviation
					cst_create_date
				FROM (
					SELECT
						*,
						ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
					FROM bronze.crm_cust_info
					WHERE cst_id IS NOT NULL
				)t 
				WHERE flag_last = 1 -- Get rid of cst_id NULLs, and select the most recent record of cst_id
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> --------------'

			--- Loading silver.crm_prd_info
		SET @start_time = GETDATE();
				PRINT '>> Truncating Table: silver.crm_prd_info';
				TRUNCATE TABLE silver.crm_prd_info;
				PRINT '>> Inserting Data Into: silver.crm_prd_info';
				INSERT INTO silver.crm_prd_info (
					prd_id,
					cat_id,
					prd_key,
					prd_nm,
					prd_cost,
					prd_line,
					prd_start_dt,
					prd_end_dt
				)
				SELECT
					prd_id,
					REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id, --- Extract category ID so it matches with other tables
					SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key,        --- Extract product key so it matches with other tables
					prd_nm,
					ISNULL(prd_cost, 0) AS prd_cost,
					CASE UPPER(TRIM(prd_line))
						 WHEN 'M' THEN 'Mountain'
						 WHEN 'R' THEN 'Road'
						 WHEN 'S' THEN 'Other Sales'
						 WHEN 'T' THEN 'Touring'
						 ELSE 'n/a'
					END AS prd_line, --- Sets product line values to full word rather than abbreviation
					CAST (prd_start_dt AS DATE) AS prd_start_dt,
					CAST(
							LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) -1
							AS DATE
					) AS prd_end_dt --- Sets end date as one day before the next start date
									--- There were many cases where the start date came after the end date
				FROM bronze.crm_prd_info
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> --------------'

		--- Loading crm_sales_details
		SET @start_time = GETDATE();
				PRINT '>> Truncating Table: silver.crm_sales_details';
				TRUNCATE TABLE silver.crm_sales_details;
				PRINT '>> Inserting Data Into: silver.crm_sales_details';
				INSERT INTO silver.crm_sales_details (
					sls_ord_num,
					sls_prd_key,
					sls_cust_id,
					sls_order_dt,
					sls_ship_dt,
					sls_due_dt,
					sls_sales,
					sls_quantity,
					sls_price
				)
				SELECT
					sls_ord_num,
					sls_prd_key,
					sls_cust_id,
					CASE 
						WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL --- Set invalid date values to NULL
						ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)           --- Change Sale Order Date from INT to DATE
					END AS sls_order_dt,										   
					CASE 
						WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL   --- Set invalid date values to NULL
						ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)			   --- Change Sale Ship Date from INT to DATE
					END AS sls_ship_dt,
					CASE 
						WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL	   --- Set invalid date values to NULL
						ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)             --- Change Sale Due Date from INT to DATE
					END AS sls_due_dt,
					CASE 
						WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price) --- Sales = Quantity * Price
							THEN sls_quantity * ABS(sls_price) --- Set Sales to Sales = Quantity * Price when there is an invalid Sale value
						ELSE sls_sales
					END AS sls_sales,      
					sls_quantity,  --- No errors in Quantity data (surprisingly)
					CASE 
						WHEN sls_price IS NULL or sls_price <= 0  --- Set Price to Price = Sales / Quantity if there is an invalid Price value
							THEN sls_sales / NULLIF(sls_quantity, 0)  --- If Quantity is 0 then NULL-ifying it will still make this run
						ELSE sls_price
					END AS sls_price
				FROM bronze.crm_sales_details
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> --------------'

		--- Loading silver.erp_cust_az12
		SET @start_time = GETDATE();
				PRINT '>> Truncating Table: silver.erp_cust_az12';
				TRUNCATE TABLE silver.erp_cust_az12;
				PRINT '>> Inserting Data Into: silver.erp_cust_az12';
				INSERT INTO silver.erp_cust_az12 (
					cid,
					bdate,
					gen
				)

				SELECT
					CASE 
						WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid)) --- Remove 'NAS' prefix if present to ease future table merges
						ELSE cid
					END cid,
					CASE 
						WHEN bdate > GETDATE() THEN NULL  --- Birthdate cannot be in the future
						ELSE bdate
					END AS bdate,
					CASE 
						WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'  --- Standardize gender to full word
						WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
						ELSE 'n/a'
					END AS gen
				FROM bronze.erp_cust_az12
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> --------------'
				
				PRINT '-------------------------------------------';
				PRINT '>> Loading ERP Tables';
				PRINT '-------------------------------------------';

		--- Loading silver.erp_loc_a101
		SET @start_time = GETDATE();
				PRINT '>> Truncating Table: silver.erp_loc_a101';
				TRUNCATE TABLE silver.erp_loc_a101
				PRINT '>> Inserting Data Into: silver.erp_loc_a101';
				INSERT INTO silver.erp_loc_a101 (
					cid,
					cntry
				)
				SELECT
					REPLACE(cid, '-', '') cid,
					CASE 
						 WHEN TRIM(cntry) = 'DE' THEN 'Germany'
						 WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
						 WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
						 ELSE TRIM(cntry)
					END AS cntry   --- Normalize Country values and handle missing/blank entries
				FROM bronze.erp_loc_a101
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> --------------'

				--- Loading silver.erp_px_cat_g1v2
		SET @start_time = GETDATE();
				PRINT '>> Truncating Table: silver.erp_px_cat_g1v2';
				TRUNCATE TABLE silver.erp_px_cat_g1v2
				PRINT '>> Inserting Data Into: silver.erp_px_cat_g1v2';
				INSERT INTO silver.erp_px_cat_g1v2 (
					id,
					cat,
					subcat,
					maintenance
				)
				SELECT
					id,
					cat,
					subcat,
					maintenance
				FROM bronze.erp_px_cat_g1v2
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> --------------'
		
		SET @batch_end_time = GETDATE();
		PRINT '===========================================';
		PRINT 'Loading Silver Layer is Completed';
		PRINT ' - Total Duration: ' + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
		PRINT '===========================================';

	END TRY
	BEGIN CATCH
		PRINT '===========================================';
		PRINT 'ERROR OCCURED DURING LOADING SILVER LAYER';
		PRINT 'Error Message' + ERROR_MESSAGE();
		PRINT 'Error Message' + CAST(ERROR_NUMBER() AS NVARCHAR);
		PRINT 'Error Message' + CAST(ERROR_STATE() AS NVARCHAR);
		PRINT '===========================================';
	END CATCH
END

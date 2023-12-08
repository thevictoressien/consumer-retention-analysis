/*Check shape*/
-- 541,909 records in table
select count(*)
from retail.online_retail;

/*Data Cleaning*/

-- Check for nulls
do $$ 
declare 
    col_name text;
    null_count integer;
begin
    for col_name in (select column_name from information_schema.columns where table_name = 'online_retail') 
    loop
        execute 'SELECT COUNT(*) FROM online_retail WHERE ' || col_name || ' IS NULL' into null_count;
        raise notice 'Column % has % null values', col_name, null_count;
    end loop;
end $$;

-- Customer_id field has 135,080 null values
-- Explore to see
select *
from retail.online_retail
where customer_id is null;



-- Remove records with nulls in the customer_id field, 
-- 0 values in the qunatity field and 
-- 0 values in the unit_price field
-- Check for and remove duplicates
-- Save results to a temp table
create temp table c_online_retail 
as
with online_retail_1 as (
	select *
	from retail.online_retail
	where customer_id is not null and quantity > 0 and unit_price > 0

), 
duplicate_check as(
-- check for duplicates, 5215 are duplicates
	select *, row_number() over (partition by invoice_no, stock_code, quantity order by invoice_date) as duplicate_flag
	from online_retail_1
)
select * 
from duplicate_check
where duplicate_flag = 1;

/* Prepare retention analysis data for export */
-- Create cohort and store in a temp table
create temp table cohort_data 
as 
select  customer_id, min(invoice_date) as first_purchase, date_trunc('month' ,min(invoice_date)) as cohort
from c_online_retail
group by customer_id;

-- Create cohort index
-- Save result set to temporary table
create temp table retention_data
as
with year_month as (
	select 
			r.*,
			c.cohort,
			date_part('year', r.invoice_date) as invoice_year,
			date_part('month', r.invoice_date) as invoice_month,
			date_part('year', c.cohort) as cohort_year,
			date_part('month', c.cohort) as cohort_month
	from c_online_retail r
	left join cohort_data c
	on r.customer_id = c.customer_id
),
diffs as (
	select *, (invoice_year - cohort_year) as year_diff, 
			(invoice_month - cohort_month) as month_diff
	from year_month
)
select *, (year_diff *12 + month_diff + 1) as cohort_index 
from diffs;

-- This output is saved for tableau in a csv
select *
from retention_data;
 

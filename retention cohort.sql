select * from retail_data_for_sql;
select count(Stock_Code) from retail_data_for_sql;
ALTER TABLE retail_data_for_sql
CHANGE COLUMN `ï»¿Invoice` Invoice text;

select customer_id,min(date_format(invoice_date, '%Y-%m')) as cohort_month
from  retail_data_for_sql 
group by customer_id;

-- Customer’s first purchase month (cohort_month)
with cohort as (
    select Customer_ID,min(date_format(Invoice_Date, '%Y-%m')) as cohort_month
    from retail_data_for_sql
    group by Customer_ID
)
select * from cohort;


-- Every purchase month (activity_month)
with activity as (
    select 
        Customer_ID,
        date_format(Invoice_Date, '%Y-%m') as activity_month
    from retail_data_for_sql)
select * from activity;


-- Combine Cohort + Activity
with cohort as (
    select 
        Customer_ID,
        min(date_format(Invoice_Date, '%Y-%m')) as cohort_month
    from retail_data_for_sql
    group by Customer_ID
),
activity as (
    select 
        Customer_ID,
        date_format(Invoice_Date, '%Y-%m') as activity_month
    from retail_data_for_sql
)
select 
    a.Customer_ID,
    c.cohort_month,
    a.activity_month
from activity a
join cohort c
on a.Customer_ID = c.Customer_ID;

-- Add Month Difference (Retention Index)
with cohort as (
    select 
        Customer_ID,
        min(Invoice_Date) as first_date
    from retail_data_for_sql
    group by Customer_ID
),
base as (
    select 
        r.Customer_ID,
        date_format(c.first_date, '%Y-%m') as cohort_month,
        date_format(r.Invoice_Date, '%Y-%m') as activity_month,
        
        (year(r.Invoice_Date) - year(c.first_date)) * 12 +
        (month(r.Invoice_Date) - month(c.first_date)) as month_index

    from retail_data_for_sql r
    join cohort c
    on r.Customer_ID = c.Customer_ID
)
select * from base;

-- This shows how many customers came back each month after first purchase.
with cohort as (
    select 
        Customer_ID,
        min(Invoice_Date) as first_date
    from retail_data_for_sql
    group by Customer_ID
),
base as (
    select 
        r.Customer_ID,
        (year(r.Invoice_Date) - year(c.first_date)) * 12 +
        (month(r.Invoice_Date) - month(c.first_date)) as month_index,
        
        date_format(c.first_date, '%Y-%m') as cohort_month

    from retail_data_for_sql r
    join cohort c
    on r.Customer_ID = c.Customer_ID
)

select
    cohort_month,
    month_index,
    count(distinct Customer_ID) as active_users
from base
group by cohort_month, month_index
order by cohort_month, month_index;

-- How to read this
-- month_index = 0 → first purchase month (cohort size)
-- month_index = 1 → customers who returned next month
-- month_index = 2+ → long-term retention

-- calculate how many users joined each cohort.
with cohort as (
    select 
        Customer_ID,
        min(Invoice_Date) as first_date
    from retail_data_for_sql
    group by Customer_ID
)
select 
    date_format(first_date, '%Y-%m') as cohort_month,
    count(Customer_ID) as cohort_size
from cohort
group by cohort_month;


-- combine cohort size + retention table:
with cohort as (
    select
        Customer_ID,
        min(Invoice_Date) as first_date
    from retail_data_for_sql
    group by Customer_ID
),
base as (
    select 
        r.Customer_ID,
        date_format(c.first_date, '%Y-%m') as cohort_month,
        (year(r.Invoice_Date) - year(c.first_date)) * 12 +
        (month(r.Invoice_Date) - month(c.first_date)) as month_index
    from retail_data_for_sql r
    join cohort c
    on r.Customer_ID = c.Customer_ID
),
cohort_size as (
    select
        date_format(first_date, '%Y-%m') as cohort_month,
        count(Customer_ID) as total_users
    from cohort
    group by cohort_month
),
retention as (
    select 
        cohort_month,
        month_index,
        count(distinct Customer_ID) as active_users
    from base
    group by cohort_month, month_index
)

select  
    r.cohort_month,
    r.month_index,
    r.active_users,
    c.total_users,
    
    round((r.active_users / c.total_users) * 100, 2) as retention_percentage
from retention r
join cohort_size c
on r.cohort_month = c.cohort_month
order by r.cohort_month, r.month_index;

-- final 
create table retention_final as
with cohort as (
    select
        Customer_ID,
        min(Invoice_Date) as first_date
    from retail_data_for_sql
    group by Customer_ID
),
base as (
    select 
        r.Customer_ID,
        date_format(c.first_date, '%Y-%m') as cohort_month,
        (year(r.Invoice_Date) - year(c.first_date)) * 12 +
        (month(r.Invoice_Date) - month(c.first_date)) as month_index
    from retail_data_for_sql r
    join cohort c
    on r.Customer_ID = c.Customer_ID
),
cohort_size as (
    select 
        date_format(first_date, '%Y-%m') as cohort_month,
        count(Customer_ID) as total_users
    from cohort
    group by cohort_month
),
retention as (
    select 
        cohort_month,
        month_index,
        count(distinct Customer_ID) as active_users
    from base
    group by cohort_month, month_index
)
select 
    r.cohort_month,
    r.month_index,
    r.active_users,
    c.total_users,
    round((r.active_users / c.total_users) * 100, 2) as retention_percentage
from retention r
join cohort_size c
on r.cohort_month = c.cohort_month;
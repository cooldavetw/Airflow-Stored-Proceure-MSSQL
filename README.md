# Airflow Stored Procedure MSSQL

This repository contains an Airflow DAG that executes Microsoft SQL Server stored procedures for the `demo01` batch flow.

## Stored Procedures

The stored procedure definitions are in [sql/stored_procedures.sql](sql/stored_procedures.sql).

Install these stored procedures manually in SQL Server before running the Airflow DAG. The DAG calls the procedures, but it does not create or update them automatically.

Run the SQL script against the `cdp` database using SQL Server Management Studio, Azure Data Studio, or `sqlcmd`.

```bash
sqlcmd -S <server> -d cdp -i sql/stored_procedures.sql
```

The script creates or alters:

- `[dbo].[sp_DEMO01_GET_BATCH_RANGE]`
- `[dbo].[sp_DEMO01_UPSERT_TGT]`
- `[dbo].[sp_DEMO01_UPDATE_CTRL]`

## Database Staging

Before running the DAG, manually stage the demo database tables and control data using [sql/stage_database.sql](sql/stage_database.sql).

Run this script against the `cdp` database:

```bash
sqlcmd -S <server> -d cdp -i sql/stage_database.sql
```

The staging script recreates and seeds:

- `[dbo].[table_src]`
- `[dbo].[table_tgt]`
- `[dbo].[CDP_JOB_CTRL]`

Recommended setup order:

1. Run [sql/stage_database.sql](sql/stage_database.sql).
2. Run [sql/stored_procedures.sql](sql/stored_procedures.sql).
3. Trigger the Airflow DAG.

## Airflow DAG

The DAG is defined in [dags/run_mssql_sp.py](dags/run_mssql_sp.py). It expects an Airflow connection named `mssql` and runs the stored procedures in this order:

1. Get the batch date range.
2. Upsert records from `[dbo].[table_src]` to `[dbo].[table_tgt]`.
3. Update the control table.

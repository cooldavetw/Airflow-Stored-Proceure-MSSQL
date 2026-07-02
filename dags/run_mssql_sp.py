from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator
from airflow.providers.microsoft.mssql.hooks.mssql import MsSqlHook


CONN_ID = "mssql"
CONTROL_TABLE_NAME = "CDP_JOB_CTRL"
DAG_NAME_IN_CTRL = "demo01"

# 1. 定義預設參數
default_args = {
    "owner": "data_engineer",
    "start_date": datetime(2026, 7, 2),
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
}


def get_batch_range(**context):
    """呼叫第一支 stored procedure，取得 begin_dt / end_dt，並透過 XCom 傳給後續 task。"""
    hook = MsSqlHook(mssql_conn_id=CONN_ID)

    sql = """
        EXEC [cdp].[dbo].[sp_DEMO01_GET_BATCH_RANGE]
            @control_table_name = %s,
            @dag_name = %s;
    """

    row = hook.get_first(sql, parameters=(CONTROL_TABLE_NAME, DAG_NAME_IN_CTRL))

    if not row or len(row) < 2:
        raise ValueError("sp_DEMO01_GET_BATCH_RANGE did not return begin_dt and end_dt.")

    begin_dt, end_dt = row[0], row[1]

    if not begin_dt or not end_dt:
        raise ValueError(f"Invalid batch range returned: begin_dt={begin_dt}, end_dt={end_dt}")

    return {
        "begin_dt": str(begin_dt),
        "end_dt": str(end_dt),
    }


# 2. 宣告 DAG 流程
with DAG(
    dag_id="execute_mssql_stored_procedure",
    default_args=default_args,
    description="依序執行 cdp 的批次 Stored Procedures",
    schedule=None,       # 設定為 None 代表手動觸發 (Manual Trigger)
    catchup=False,
    tags=["mssql", "dmp"],
) as dag:

    get_batch_range_task = PythonOperator(
        task_id="get_batch_range",
        python_callable=get_batch_range,
    )

    upsert_tgt_task = SQLExecuteQueryOperator(
        task_id="upsert_table_tgt",
        conn_id=CONN_ID,
        sql="""
            EXEC [cdp].[dbo].[sp_DEMO01_UPSERT_TGT]
                @begin_dt = '{{ ti.xcom_pull(task_ids="get_batch_range")["begin_dt"] }}',
                @end_dt   = '{{ ti.xcom_pull(task_ids="get_batch_range")["end_dt"] }}';
        """,
        autocommit=True,
    )

    update_ctrl_task = SQLExecuteQueryOperator(
        task_id="update_control_table",
        conn_id=CONN_ID,
        sql="""
            EXEC [cdp].[dbo].[sp_DEMO01_UPDATE_CTRL]
                @control_table_name = 'CDP_JOB_CTRL',
                @begin_dt = '{{ ti.xcom_pull(task_ids="get_batch_range")["begin_dt"] }}',
                @end_dt   = '{{ ti.xcom_pull(task_ids="get_batch_range")["end_dt"] }}',
                @dag_name = 'demo01';
        """,
        autocommit=True,
    )

    get_batch_range_task >> upsert_tgt_task >> update_ctrl_task

from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator

# 1. 定義預設參數
default_args = {
    'owner': 'data_engineer',
    'start_date': datetime(2026, 1, 1),
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

# 2. 宣告 DAG 流程
with DAG(
    dag_id='execute_mssql_stored_procedure',
    default_args=default_args,
    description='使用通用連線執行 DMP_CHNL 的 Stored Procedure',
    schedule=None,       # 設定為 None 代表手動觸發 (Manual Trigger)
    catchup=False,
    tags=['mssql', 'dmp'],
) as dag:

    # 3. 宣告執行的 Task
    run_sp_task = SQLExecuteQueryOperator(
        task_id='exec_sp_cntc_lst',
        conn_id='mssql',  # 必須與你剛才在 Airflow UI 建立的 Connection Id 完全一致（全小寫）
        sql="""
            EXEC [DMP_CHNL].[dbo].[sp_CNTC_LST_TMP1_TMP2] '20260607', '20260608';
        """,
        autocommit=True,      # 確保預存程序內部的 Insert/Update 變更會立即生效並提交
    )

    run_sp_task
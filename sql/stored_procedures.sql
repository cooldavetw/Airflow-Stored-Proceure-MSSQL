USE [cdp];
GO

/* =====================================================
   1. 取得本次批次處理日期區間
   - begin_dt：control table 內的 batch_sts / lst_scs_dt
   - end_dt：執行當天日期
   - 若 lst_scs_dt 為 NULL，預設從 19700101 開始
   ===================================================== */
CREATE OR ALTER PROCEDURE [dbo].[sp_DEMO01_GET_BATCH_RANGE]
    @control_table_name SYSNAME,
    @dag_name           VARCHAR(30) = 'demo01'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @sql NVARCHAR(MAX);
    DECLARE @begin_dt VARCHAR(8);
    DECLARE @end_dt VARCHAR(8) = CONVERT(VARCHAR(8), SYSDATETIME(), 112);

    SET @sql = N'
        SELECT @begin_dt_out =
            CASE
                WHEN PARAMETER_VALUE IS NULL OR LTRIM(RTRIM(PARAMETER_VALUE)) = ''''
                    THEN ''19700101''
                ELSE CONVERT(VARCHAR(8), CONVERT(DATE, PARAMETER_VALUE, 112), 112)
            END
        FROM [dbo].' + QUOTENAME(@control_table_name) + N'
        WHERE DAG_NAME = @dag_name_in
          AND PARAMETER_TYPE = ''batch_sts''
          AND PARAMETER_NAME = ''lst_scs_dt'';
    ';

    EXEC sp_executesql
        @sql,
        N'@dag_name_in VARCHAR(30), @begin_dt_out VARCHAR(8) OUTPUT',
        @dag_name_in = @dag_name,
        @begin_dt_out = @begin_dt OUTPUT;

    IF @begin_dt IS NULL
        SET @begin_dt = '19700101';

    SELECT
        @begin_dt AS begin_dt,
        @end_dt   AS end_dt;
END;
GO

/* =====================================================
   2. 依日期區間從 table_src upsert 到 table_tgt
   - 條件：txn_dt >= begin_dt AND txn_dt < end_dt
   - 已存在：更新 txn_amt 與 lst_cdp_mtn_dt
   - 不存在：新增資料
   ===================================================== */
CREATE OR ALTER PROCEDURE [dbo].[sp_DEMO01_UPSERT_TGT]
    @begin_dt VARCHAR(8),
    @end_dt   VARCHAR(8)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @mtn_dt VARCHAR(8) = CONVERT(VARCHAR(8), SYSDATETIME(), 112);

    BEGIN TRAN;

    MERGE [dbo].[table_tgt] AS tgt
    USING (
        SELECT
            act_no,
            txn_dt,
            txn_amt
        FROM [dbo].[table_src]
        WHERE txn_dt >= @begin_dt
          AND txn_dt <  @end_dt
    ) AS src
    ON  tgt.act_no = src.act_no
    AND tgt.txn_dt = src.txn_dt
    WHEN MATCHED THEN
        UPDATE SET
            tgt.txn_amt = src.txn_amt,
            tgt.lst_cdp_mtn_dt = @mtn_dt
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (act_no, txn_dt, txn_amt, lst_cdp_mtn_dt)
        VALUES (src.act_no, src.txn_dt, src.txn_amt, @mtn_dt);

    COMMIT TRAN;
END;
GO

/* =====================================================
   3. 更新 control table
   - batch_sts / lst_scs_dt = 今天，也就是 end_dt
   - task_par / batch_dt    = 今天，也就是 end_dt
   - task_par / begin_dt    = 本次開始日期
   - task_par / end_dt      = 今天，也就是 end_dt
   ===================================================== */
CREATE OR ALTER PROCEDURE [dbo].[sp_DEMO01_UPDATE_CTRL]
    @control_table_name SYSNAME,
    @begin_dt           VARCHAR(8),
    @end_dt             VARCHAR(8),
    @dag_name           VARCHAR(30) = 'demo01'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @sql NVARCHAR(MAX);

    SET @sql = N'
        UPDATE [dbo].' + QUOTENAME(@control_table_name) + N'
        SET PARAMETER_VALUE = @end_dt_in
        WHERE DAG_NAME = @dag_name_in
          AND PARAMETER_TYPE = ''batch_sts''
          AND PARAMETER_NAME = ''lst_scs_dt'';

        UPDATE [dbo].' + QUOTENAME(@control_table_name) + N'
        SET PARAMETER_VALUE = @end_dt_in
        WHERE DAG_NAME = @dag_name_in
          AND PARAMETER_TYPE = ''task_par''
          AND PARAMETER_NAME = ''batch_dt'';

        UPDATE [dbo].' + QUOTENAME(@control_table_name) + N'
        SET PARAMETER_VALUE = @begin_dt_in
        WHERE DAG_NAME = @dag_name_in
          AND PARAMETER_TYPE = ''task_par''
          AND PARAMETER_NAME = ''begin_dt'';

        UPDATE [dbo].' + QUOTENAME(@control_table_name) + N'
        SET PARAMETER_VALUE = @end_dt_in
        WHERE DAG_NAME = @dag_name_in
          AND PARAMETER_TYPE = ''task_par''
          AND PARAMETER_NAME = ''end_dt'';
    ';

    EXEC sp_executesql
        @sql,
        N'@dag_name_in VARCHAR(30), @begin_dt_in VARCHAR(8), @end_dt_in VARCHAR(8)',
        @dag_name_in = @dag_name,
        @begin_dt_in = @begin_dt,
        @end_dt_in = @end_dt;
END;
GO

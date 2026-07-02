USE [cdp];
GO

DROP TABLE IF EXISTS table_src;
CREATE TABLE table_src
(
    act_no  VARCHAR(5),
    txn_dt  VARCHAR(8),
    txn_amt DECIMAL(10, 0), -- 或是使用 INT (最大支援到 21 億)
    CONSTRAINT PK_table_src PRIMARY KEY (act_no, txn_dt) -- 修正拼字並加上 PK 命名
);

DROP TABLE IF EXISTS table_tgt;
CREATE TABLE table_tgt
(
    act_no  VARCHAR(5),
    txn_dt  VARCHAR(8),
    txn_amt DECIMAL(10, 0), -- 或是使用 INT (最大支援到 21 億)
    lst_cdp_mtn_dt VARCHAR(8),
    CONSTRAINT PK_table_tgt PRIMARY KEY (act_no, txn_dt) -- 修正拼字並加上 PK 命名
);

TRUNCATE TABLE table_src;
INSERT INTO table_src VALUES ('A', '20260629', 100);
INSERT INTO table_src VALUES ('A', '20260630', 150);
INSERT INTO table_src VALUES ('A', '20260701', 220);
INSERT INTO table_src VALUES ('A', '20260702', 25);

TRUNCATE TABLE table_tgt;
INSERT INTO table_tgt VALUES ('A', '20260629', 0, NULL);

DROP TABLE IF EXISTS CDP_JOB_CTRL;

CREATE TABLE CDP_JOB_CTRL
(
    DAG_NAME        VARCHAR(30),
    PARAMETER_TYPE  VARCHAR(30),
    PARAMETER_NAME  VARCHAR(60),
    PARAMETER_VALUE VARCHAR(60),
    CONSTRAINT PK_CDP_JOB_CTRL PRIMARY KEY (DAG_NAME, PARAMETER_TYPE, PARAMETER_NAME)
);

INSERT INTO CDP_JOB_CTRL VALUES ('demo01', 'batch_sts', 'lst_scs_dt', NULL);
INSERT INTO CDP_JOB_CTRL VALUES ('demo01', 'task_par', 'batch_dt', NULL);
INSERT INTO CDP_JOB_CTRL VALUES ('demo01', 'task_par', 'begin_dt', NULL);
INSERT INTO CDP_JOB_CTRL VALUES ('demo01', 'task_par', 'end_dt', NULL);

DECLARE @batch_dt VARCHAR(8);
DECLARE @begin_dt VARCHAR(8);
DECLARE @end_dt VARCHAR(8);

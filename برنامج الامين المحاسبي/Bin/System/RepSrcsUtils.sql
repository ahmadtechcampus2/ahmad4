#######################################################
CREATE PROC prcRSCreateAll
	@srcGuid UNIQUEIDENTIFIER
AS
BEGIN
	-- سند القيد
	INSERT INTO RepSrcs (IdTbl, IdType, IdSubType)
	SELECT @srcGuid, 0x0, 0

	-- سندات القبض والدفع
	INSERT INTO RepSrcs (IdTbl, IdType, IdSubType)
	SELECT @srcGuid, etGUID, 4
	FROM vwEt

	-- الفواتير
	INSERT INTO RepSrcs (IdTbl, IdType, IdSubType)
	SELECT @srcGuid, btGUID, 2
	FROM vwBt

	-- الأوراق المالية
	INSERT INTO RepSrcs (IdTbl, IdType)
	SELECT @srcGuid, ntGUID
	FROM vwnt
END
#######################################################
CREATE PROC prcRSCreateEntry
	@srcGuid UNIQUEIDENTIFIER
AS
BEGIN
	-- سند القيد
	INSERT INTO RepSrcs (IdTbl, IdType, IdSubType)
	SELECT @srcGuid, 0x0, 0

	-- سندات القبض والدفع
	INSERT INTO RepSrcs (IdTbl, IdType, IdSubType)
	SELECT @srcGuid, etGUID, 4
	FROM vwEt
END
#######################################################
CREATE PROC prcRSCreateBill
	@srcGuid UNIQUEIDENTIFIER
AS
BEGIN
	INSERT INTO RepSrcs (IdTbl, IdType, IdSubType)
	SELECT @srcGuid, btGUID, 2
	FROM vwBt
END
#######################################################
CREATE PROC prcRSCreateSale
	@srcGuid UNIQUEIDENTIFIER
AS
BEGIN
	INSERT INTO RepSrcs (IdTbl, IdType, IdSubType)
	SELECT @srcGuid, btGUID, 2
	FROM vwBt 
	WHERE btBillType = 1
END
#######################################################
CREATE PROC prcRSCreateRetSale
	@srcGuid UNIQUEIDENTIFIER
AS
BEGIN
	INSERT INTO RepSrcs (IdTbl, IdType, IdSubType)
	SELECT @srcGuid, btGUID, 2
	FROM vwBt 
	WHERE btBillType = 3
END
#######################################################
CREATE PROC prcRSCreatePurchase
	@srcGuid UNIQUEIDENTIFIER
AS
BEGIN
	INSERT INTO RepSrcs (IdTbl, IdType, IdSubType)
	SELECT @srcGuid, btGUID, 2
	FROM vwBt 
	WHERE btBillType = 0
END
#######################################################
CREATE PROC prcRSCreateRetPurchase
	@srcGuid UNIQUEIDENTIFIER
AS
BEGIN
	INSERT INTO RepSrcs (IdTbl, IdType, IdSubType)
	SELECT @srcGuid, btGUID, 2
	FROM vwBt 
	WHERE btBillType = 2
END
#######################################################
CREATE PROC prcRSCreateInBill
	@srcGuid UNIQUEIDENTIFIER
AS
BEGIN
	INSERT INTO RepSrcs (IdTbl, IdType, IdSubType)
	SELECT @srcGuid, btGUID, 2
	FROM vwBt 
	WHERE btBillType = 4
END
#######################################################
CREATE PROC prcRSCreateOutBill
	@srcGuid UNIQUEIDENTIFIER
AS
BEGIN
	INSERT INTO RepSrcs (IdTbl, IdType, IdSubType)
	SELECT @srcGuid, btGUID, 2
	FROM vwBt 
	WHERE btBillType = 5
END
#######################################################
CREATE PROC prcRSAddEntry
	@srcGuid	UNIQUEIDENTIFIER,
	@typeName	NVARCHAR(256)
AS
BEGIN
	INSERT INTO RepSrcs (IdTbl, IdType, IdSubType)
	SELECT @srcGuid, etGUID, 4
	FROM vwEt
	WHERE etName like @typeName
END
#######################################################
CREATE PROC prcRSAddBill
	@srcGuid	UNIQUEIDENTIFIER,
	@typeName	NVARCHAR(256)
AS
BEGIN
	INSERT INTO RepSrcs (IdTbl, IdType, IdSubType)
	SELECT @srcGuid, btGUID, 2
	FROM vwBt
	WHERE btName like @typeName
END
#######################################################
CREATE PROC prcRSAddCheck
	@srcGuid	UNIQUEIDENTIFIER,
	@typeName	NVARCHAR(256)
AS
BEGIN
	INSERT INTO RepSrcs (IdTbl, IdType, IdSubType)
	SELECT @srcGuid, ntGUID, 5
	FROM vwnt
	WHERE ntName like @typeName
END
#######################################################
CREATE PROC prcRSOrderStatusCreateAll
	@srcGuid	UNIQUEIDENTIFIER
AS
BEGIN
	INSERT INTO RepSrcs (IdTbl, IdType, IdSubType)
	SELECT @srcGuid, [Guid], 2
	FROM fnGetOrderItemTypes()
END
#######################################################
CREATE PROC prcRSAddOrderStatus
	@srcGuid	UNIQUEIDENTIFIER,
	@statusName	NVARCHAR(256)
AS
BEGIN
	INSERT INTO RepSrcs (IdTbl, IdType, IdSubType)
	SELECT @srcGuid, [Guid], 2
	FROM fnGetOrderItemTypes()
	WHERE Name like @statusName
END
#######################################################
CREATE PROC prcRSClean
	@srcGuid	UNIQUEIDENTIFIER
AS
BEGIN
	DELETE RepSrcs WHERE IdTbl = @srcGuid
END
#######################################################
#End
------------------------------
------ Sample ----------------
--DECLARE @srcGuid UNIQUEIDENTIFIER
--SET @srcGuid = NEWID()

--exec UTCreateAllSrcType @srcGuid
--exec UTAddBillSrcType @srcGuid , '%مبيع%'
----------------------------
----exec stored procedure
----------------------------
--exec UTCleanSrcType @srcGuid

exec prcRSAddCheck @srcGuid , '%%'


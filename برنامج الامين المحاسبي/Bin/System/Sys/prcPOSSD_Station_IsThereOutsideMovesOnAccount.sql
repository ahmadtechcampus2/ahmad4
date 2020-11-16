#################################################################
CREATE PROCEDURE prcPOSSD_Station_IsThereOutsideMovesOnAccount
(
  @posGuid UNIQUEIDENTIFIER,
  @Result BIT  OUTPUT
)
AS
BEGIN
	SET @Result = 0
	DECLARE @count INT, @controlAccount UNIQUEIDENTIFIER, @floatAccount UNIQUEIDENTIFIER,
	@openingDate DATETIME, @closeDate DATETIME, @res BIT = 0
	DECLARE @MovesOutPOS Table 
	(EnDate	DATETIME,
	CeNumber INT,
	CeGuid	UNIQUEIDENTIFIER,
	EnGuid	UNIQUEIDENTIFIER,
	BuGuid	UNIQUEIDENTIFIER,
	ChGuid	UNIQUEIDENTIFIER,
	EnNotes	NVARCHAR(MAX),
	AccountGuid	UNIQUEIDENTIFIER,
	Debit	FLOAT,
	Credit	FLOAT,
	MoveBalance	FLOAT,
	Name	NVARCHAR(256),
	EnCurrencyVal	FLOAT,
	EnCurrencyCode	NVARCHAR(256),
	CeParentType	INT,
	BillType	INT,
	ParentGuid	UNIQUEIDENTIFIER,
	ParentNumber	INT,
	CeTypeGuid	UNIQUEIDENTIFIER
	)
	SELECT @controlAccount = ShiftControlGUID From POSSDStation000 WHERE GUID = @posGuid
	SELECT @floatAccount = ContinuesCashGUID From POSSDStation000 WHERE GUID = @posGuid
	SELECT @openingDate = CONVERT(DATETIME, Value) From op000 WHERE Name = 'AmnCfg_FPDate'
	SELECT @closeDate = CONVERT(DATETIME, Value) From op000 WHERE Name = 'AmnCfg_EPDate'
	
	INSERT INTO @MovesOutPOS
	  EXEC prcPOSSD_Station_ControlAccountOutsideMoves @posGuid, @controlAccount, @openingDate, @closeDate
	
	INSERT INTO @MovesOutPOS
	  EXEC prcPOSSD_Station_ControlAccountOutsideMoves @posGuid, @floatAccount, @openingDate, @closeDate
	
	SELECT @count = COUNT(*) FROM @MovesOutPOS
	
	IF(@count > 0)
	 SET @Result = 1
   
END
#################################################################
#END

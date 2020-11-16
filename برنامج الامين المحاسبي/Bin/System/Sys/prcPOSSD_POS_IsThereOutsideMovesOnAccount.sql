#################################################################
CREATE PROCEDURE IsTherePOSAccountOutsidePosMoves
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
	SELECT @controlAccount = ShiftControl From POSCard000 WHERE Guid = @posGuid
	SELECT @floatAccount = ContinuesCash From POSCard000 WHERE Guid = @posGuid
	SELECT @openingDate = CONVERT(DATETIME, Value) From op000 WHERE Name = 'AmnCfg_FPDate'
	SELECT @closeDate = CONVERT(DATETIME, Value) From op000 WHERE Name = 'AmnCfg_EPDate'
	
	INSERT INTO @MovesOutPOS
	  EXEC prcPOSControlAccountOutsideMoves @posGuid, @controlAccount, @openingDate, @closeDate
	
	INSERT INTO @MovesOutPOS
	  EXEC prcPOSControlAccountOutsideMoves @posGuid, @floatAccount, @openingDate, @closeDate
	
	SELECT @count = COUNT(*) FROM @MovesOutPOS
	
	IF(@count > 0)
	 SET @Result = 1
   
END
#################################################################
#END

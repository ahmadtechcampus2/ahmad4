################################################################################
CREATE FUNCTION fnPOSSD_Station_AccountIsUsed()
RETURNS @POSSDAccounts TABLE 
(
		[GUID]	UNIQUEIDENTIFIER
)
AS 
BEGIN
	
	INSERT INTO @POSSDAccounts
	SELECT ShiftControlGUID
	FROM POSSDStation000

	INSERT INTO @POSSDAccounts
	SELECT ContinuesCashGUID
	FROM POSSDStation000

	INSERT INTO @POSSDAccounts
	SELECT AccFN.[GUID]
	FROM 
		POSSDStation000 S
		CROSS APPLY (SELECT [GUID] FROM dbo.fnGetAccountsList(S.CentralAccGUID, 0)) AS AccFN
	WHERE S.CentralAccGUID <> 0x0
	EXCEPT SELECT * FROM @POSSDAccounts


	INSERT INTO @POSSDAccounts
	SELECT AccFN.[GUID]
	FROM 
		POSSDStation000 S
		CROSS APPLY (SELECT [GUID] FROM dbo.fnGetAccountsList(S.DebitAccGUID, 0)) AS AccFN
	WHERE S.DebitAccGUID <> 0x0
	EXCEPT SELECT * FROM @POSSDAccounts
		

	INSERT INTO @POSSDAccounts
	SELECT AccFN.[GUID]
	FROM 
		POSSDStation000 S
		CROSS APPLY (SELECT [GUID] FROM dbo.fnGetAccountsList(S.CreditAccGUID, 0)) AS AccFN
	WHERE S.CreditAccGUID <> 0x0
	EXCEPT SELECT * FROM @POSSDAccounts


	INSERT INTO @POSSDAccounts
	SELECT AccFN.[GUID]
	FROM 
		POSSDStation000 S
		CROSS APPLY (SELECT [GUID] FROM dbo.fnGetAccountsList(S.ExpenseAccGUID, 0)) AS AccFN
	WHERE S.ExpenseAccGUID <> 0x0
	EXCEPT SELECT * FROM @POSSDAccounts


	INSERT INTO @POSSDAccounts
	SELECT AccFN.[GUID]
	FROM 
		POSSDStation000 S
		CROSS APPLY (SELECT [GUID] FROM dbo.fnGetAccountsList(S.IncomeAccGUID, 0)) AS AccFN
	WHERE S.IncomeAccGUID <> 0x0
	EXCEPT SELECT * FROM @POSSDAccounts

	RETURN
END
#################################################################
#END

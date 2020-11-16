##########################
CREATE PROCEDURE repVoucherAges 
	@CurrentDate	DATETIME, 
	@CurrentTime	DATETIME, 
	@AgeType		INT, -- 0 CashAge, 1 NotifyAge, 2 PayAge 
	--@ShowCompleted	INT, -- /* 0 or 1 */ShowCashed or ShowNotified or ShowPaid 
	@AgeUnit		INT,	-- 0 AGE_HOUR, 1 AGE_DAY, 2 AGE_WEEK, 3 AGE_MONTH 
	@SourceGuid		UNIQUEIDENTIFIER, -- repSrc    
	@DestGuid               UNIQUEIDENTIFIER, -- repDst    
	@AgeValue		INT--= -1 
AS 
	SET NOCOUNT ON 
	
	CREATE TABLE [#TransfersSourceTbl] ( [Guid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER])     
        CREATE TABLE [#TransfersDestTbl] ( [Guid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER])     
        INSERT INTO [#TransfersSourceTbl]EXEC [prcGetTransfersTypesList] @SourceGuid     
        INSERT INTO [#TransfersDestTbl]  EXEC [prcGetTransfersTypesList] @DestGuid 
	
	
	
	CREATE TABLE [#Result]
	(
		Age			FLOAT,
		TVDate		DATETIME,
		TVTrnTime	DATETIME,
		TVGuid		UNIQUEIDENTIFIER,
		TVNumber	FLOAT,
		TVMustPaidAmount	FLOAT,
		TVPayCurrency   UNIQUEIDENTIFIER,
		SenderName	NVARCHAR(256)       COLLATE ARABIC_CI_AI,
		ReceivName  	NVARCHAR(256)       COLLATE ARABIC_CI_AI,
		SourceBranchName  NVARCHAR(256)     COLLATE ARABIC_CI_AI,
		DestinationBranchName NVARCHAR(256) COLLATE ARABIC_CI_AI,
		TVCode          NVARCHAR(256) COLLATE ARABIC_CI_AI
	)
	
	IF @AgeType = 0  --CashAge ...Cashed , but Not paid
	BEGIN
		INSERT INTO [#Result] 
		SELECT
			CASE 	 WHEN @AgeUnit = 0 /*Hour */ THEN  DATEDIFF ( hour, TVTrnTime, @CurrentTime)
				 WHEN @AgeUnit = 1 /*Day */  THEN DATEDIFF ( day,   TVTrnTime, @CurrentTime)
				 WHEN @AgeUnit = 2 /*Week */ THEN DATEDIFF ( week,  TVTrnTime, @CurrentTime)
				 WHEN @AgeUnit = 3 /*Month*/ THEN DATEDIFF ( month, TVTrnTime, @CurrentTime)
			END AS Age,
			TVDate, TVTrnTime, TVGuid, TVNumber, TVMustPaidAmount/ISNULL(TVPayCurrencyVal,1), 
			TVPayCurrency, SenderName, ReceivName ,SourcBranchName, DestBranchName, TVCode 
		FROM [vwTrnTransferVoucher] AS vt
		INNER JOIN [#TransfersSourceTbl] AS Src ON Src.GUID = vt.TVSourceBranch 
		INNER JOIN [#TransfersDestTbl]   AS Dst ON Dst.GUID = vt.TVDestinationBranch 
		WHERE (TVCashed = 1 OR TVFromStatement = 1) AND (TVpaid = 0) AND (TVState <> 15)--«·ÕÊ«·… ·Ì”  „·€Ì…
				AND NOT (TVDestinationType = 2 AND TVState = 20) AND NOT (TVSourceType = 2 AND TVState = 7) 

	END

	IF @AgeType = 1  --NotifiedAge ...Notified To Reciever , but Not paid
	BEGIN
		INSERT INTO [#Result] 
		SELECT
			CASE 	 WHEN @AgeUnit = 0 /*Hour */ THEN  DATEDIFF ( hour, TVTrnTime, @CurrentTime)
				 WHEN @AgeUnit = 1 /*Day */  THEN DATEDIFF ( day,   TVTrnTime, @CurrentTime)
				 WHEN @AgeUnit = 2 /*Week */ THEN DATEDIFF ( week,  TVTrnTime, @CurrentTime)
				 WHEN @AgeUnit = 3 /*Month*/ THEN DATEDIFF ( month, TVTrnTime, @CurrentTime)
			END AS Age,
			TVDate, TVTrnTime, TVGuid, TVNumber, TVMustPaidAmount/ISNULL(TVPayCurrencyVal,1), 
			TVPayCurrency, SenderName, ReceivName ,SourcBranchName, DestBranchName, TVCode 
		FROM [vwTrnTransferVoucher] AS vt
		INNER JOIN [#TransfersSourceTbl] AS Src ON Src.GUID = vt.TVSourceBranch 
		INNER JOIN [#TransfersDestTbl]   AS Dst ON Dst.GUID = vt.TVDestinationBranch  
		WHERE TVNotified = 1 AND TVpaid = 0  AND (TVState <> 15)--«·ÕÊ«·… ·Ì”  „·€Ì…

	END

	IF @AgeType = 2  --PayAge ...Paied , but Not Clousered
	BEGIN
		INSERT INTO [#Result] 
		SELECT
			CASE 	 WHEN @AgeUnit = 0 /*Hour */ THEN  DATEDIFF ( hour, TVTrnTime, @CurrentTime)
				 WHEN @AgeUnit = 1 /*Day */  THEN DATEDIFF ( day,   TVTrnTime, @CurrentTime)
				 WHEN @AgeUnit = 2 /*Week */ THEN DATEDIFF ( week,  TVTrnTime, @CurrentTime)
				 WHEN @AgeUnit = 3 /*Month*/ THEN DATEDIFF ( month, TVTrnTime, @CurrentTime)
			END AS Age,
			TVDate, TVTrnTime, TVGuid, TVNumber, TVMustPaidAmount/ISNULL(TVPayCurrencyVal,1),
			TVPayCurrency, SenderName, ReceivName ,SourcBranchName, DestBranchName, TVCode 
		FROM [vwTrnTransferVoucher] AS vt
		INNER JOIN [#TransfersSourceTbl] AS Src ON Src.GUID = vt.TVSourceBranch 
		INNER JOIN [#TransfersDestTbl]   AS Dst ON Dst.GUID = vt.TVDestinationBranch  
		WHERE TVpaid = 1 AND TVState = 8 AND TVDestinationType = 1 AND TVSourceType = 1

	END

	SELECT * FROM [#Result] WHERE Age >= @AgeValue 

##########################
#END
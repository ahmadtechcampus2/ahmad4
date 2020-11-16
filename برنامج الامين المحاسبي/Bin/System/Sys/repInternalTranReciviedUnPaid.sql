##########################################
CREATE PROCEDURE repInternalTranReciviedUnPaid
	@State NVARCHAR(150),
	@CurrencyGuid UNIQUEIDENTIFIER,
	@SenderBranchSrc UNIQUEIDENTIFIER,
	@ReciverBranchSrc UNIQUEIDENTIFIER,
	@StartDate DATETIME,
	@EndDate DATETIME
AS
	SET NOCOUNT ON

	CREATE TABLE #TransfersSourceTbl ([Guid] UNIQUEIDENTIFIER, UserSecurity INTEGER)     
    CREATE TABLE #TransfersDestTbl ([Guid] UNIQUEIDENTIFIER, UserSecurity INTEGER)  
    INSERT INTO #TransfersSourceTbl EXEC prcGetTransfersTypesList @SenderBranchSrc     
    INSERT INTO #TransfersDestTbl EXEC prcGetTransfersTypesList @ReciverBranchSrc   

	SELECT
		NEWID() AS [GUID],
		T.GUID as transferguid,
		InternalNum,
		T.CODE as Number,
		SenderGUID,
		S.Name AS SenderName,
		Receiver1_GUID,
		R.Name AS ReciverName,
		T.Date,
		SourceBranch,
		SB.Name AS SourceBranchName,
		DestinationBranch,
		DB.Name AS DestinationBranchName,	
		T.[State],
		(MustPaidAmount/t.PayCurrencyVal) as MustPaidAmount,
		(T.Amount + T.NetWages)/t.PayCurrencyVal AS PaidAmount
	INTO #T
	FROM 
		TrnTransferVoucher000 AS T
		JOIN #TransfersSourceTbl AS srcBr ON srcBr.Guid = T.SourceBranch
		JOIN #TransfersDestTbl AS desBr ON desBr.Guid = T.DestinationBranch
		JOIN TrnSenderReceiver000 AS S ON T.SenderGUID = S.GUID
		JOIN TrnSenderReceiver000 AS R ON T.Receiver1_GUID = R.GUID
		JOIN TrnBranch000 AS SB ON T.SourceBranch = SB.GUID
		JOIN TrnBranch000 AS DB ON T.DestinationBranch = DB.GUID
	WHERE 
		SourceType = 1  AND DestinationType = 1 
		AND T.[State] IN (SELECT CAST(Data AS INT) FROM [dbo].[fnTextToRows](@State))
		AND T.PayCurrency = @CurrencyGuid
		AND Date BETWEEN @StartDate AND @EndDate

	SELECT * FROM #T
	ORDER BY DATE

	SELECT DISTINCT
		B.Number,
		B.[GUID],
		Name,
		SUM(CASE WHEN T.DestinationBranch = B.[GUID] THEN T.MustPaidAmount ELSE 0 END) AS MustPaid--,
		--SUM(CASE WHEN T.DestinationBranch = B.[GUID] THEN T.PaidAmount ELSE 0 END) AS Paid
	FROM
		TrnBranch000 AS B
		JOIN #T AS T ON T.SourceBranch = B.GUID OR T.DestinationBranch = B.GUID
	GROUP BY
		B.GUID,
		Name,
		B.Number
	ORDER BY
		B.Number
#####################################################################################
#END
##########################################
CREATE PROC prcTrn_InStamentRep
	@SourceRepGuid UNIQUEIDENTIFIER,
	@StartDate DATETIME,
	@EndDate DATETIME,
	@StmVoucherType INT
	--@FromNo varchar(100),
	--@ToNo varchar(100)
	--@OrderBy  INT
	--@ShowOperation int,
	--@Grouping int = 0
	
AS
	/*
	@StmVoucherType √‰Ê«⁄ «·ﬂ‘Ê›« 
	-1 «·ﬂ·
	-2 «·„Ê·œ… ÕÊ«·« Â«
	-3 «·€Ì— „Ê·œ… ÕÊ«·« Â«
	*/

	SET NOCOUNT ON	
	---SELECT * FROM TrnStatementItems000
	--DECLARE @Stm TABLE
	CREATE TABLE #RESULT
		(
			StmType		NVARCHAR(250) COLLATE ARABIC_CI_AI,
			StmGuid		UNIQUEIDENTIFIER,
			StmCode		NVARCHAR(250) COLLATE ARABIC_CI_AI,
			IsVoucherGen 	INT,
			VoucherGuid	UNIQUEIDENTIFIER,
			VoucherTypeGuid	UNIQUEIDENTIFIER,
			VoucherCode	NVARCHAR(250) COLLATE ARABIC_CI_AI,
			[Date] 		DATETIME,

			Sender		UNIQUEIDENTIFIER,
			SenderName		NVARCHAR(250) COLLATE ARABIC_CI_AI,
			SenderPhone	NVARCHAR(250) COLLATE ARABIC_CI_AI,
			Receiver	UNIQUEIDENTIFIER,
			ReceiverName	NVARCHAR(250) COLLATE ARABIC_CI_AI,
			ReceiverPhone	NVARCHAR(250) COLLATE ARABIC_CI_AI,

			Amount		FLOAT,
			Currency	UNIQUEIDENTIFIER,
			CurrVal 	FLOAT,
			NetWages	FLOAT,

			PayAmount	FLOAT,
			PayCurrency	UNIQUEIDENTIFIER,
			PayCurVal 	FLOAT,
			Notes		NVARCHAR(250) COLLATE ARABIC_CI_AI,
			Reason		NVARCHAR(250) COLLATE ARABIC_CI_AI
		)

	INSERT INTO #RESULT	
	SELECT  
		stmType.[ttName],
		--Stmtype.[IsOut],
		stm.Guid,
		stm.Code,
		Item.IsVoucherGenerated,
		ISNULL(V.TVGUID, 0x0),
		ISNULL(V.TVGUID, 0x0),--Item.TransferTypeGuid,
		ISNULL(V.TVCODE, 0),
		Item.DUEDATE,
		Sender.SRGuid,
		Sender.SRName,
		Sender.SRPhone1, 
		Res.SRGuid,
		Res.SRName,
		Res.SRPhone1,
		CASE ISNULL(V.TVAmount, -1) WHEN -1 THEN Item.Amount ELSE V.TVAmount/V.TVCurrencyVal END,-- ISNULL(V.TVAmount, Item.Amount),
		ISNULL(V.TVCurrencyGUID, Item.CurrencyGuid),
		ISNULL(V.TVCurrencyVal, Item.CurrencyVal),

		ISNULL(V.TVNetWages, Item.NetWages),
		CASE ISNULL(V.TVMustPaidAmount, -1) WHEN -1 THEN Item.Amount2 ELSE V.TVMustPaidAmount/V.TVPayCurrencyVal END,-- ISNULL(V.TVMustPaidAmount, Item.Amount2),
		ISNULL(V.TVPayCurrency, Item.CurrencyGuid2),
		ISNULL(V.TVPayCurrencyVal, Item.CurrencyVal2),
		ISNULL(V.TVNOTES, Item.NOTES),
		V.TVReason
	FROM	
		vwTrnStatement AS stm
		INNER JOIN vwTrnStatementTypes  AS Stmtype ON
				stm.TypeGUID = Stmtype.ttGuid AND Stmtype.IsOut = 0

		INNER JOIN TrnStatementItems000 AS item ON item.ParentGuid = stm.Guid
		INNER JOIN RepSrcs AS src ON src.IdType = stm.TypeGUID
		INNER JOIN vwTrnSenderReceiver  AS Sender ON Sender.SRGuid = item.SenderGuid
		INNER JOIN vwTrnSenderReceiver  AS Res ON Res.SRGuid = item.Receiver1_GUID
		LEFT  JOIN vwTrnTransferVoucher AS V ON V.TVGUID =  item.TransferVoucherGuid
			
	WHERE
		stm.[Date] BETWEEN @StartDate AND @EndDate  
		And src.IdTbl = @SourceRepGuid
		
	IF (@StmVoucherType = 1)--ﬂ· «·ﬂ‘Ê›« 
		SELECT * FROM #result ORDER BY Date, StmCode, VoucherCode

	ELSE IF (@StmVoucherType = 2)--«·ﬂ‘Ê›«  «·„Ê·œ…
		SELECT #result.* FROM #result INNER JOIN vwTrnTransferVoucher AS V ON V.TVGUID =  #result.VoucherGuid
		ORDER BY #result.Date, #result.StmCode, #result.VoucherCode
	
	ELSE --«·ﬂ‘Ê›«  €Ì— «·„Ê·œ…
		SELECT #result.* FROM #result INNER JOIN TrnStatementItems000 AS NonGenerated ON NonGenerated.TransferVoucherGuid = 0x0 AND NonGenerated.parentGUID = #result.StmGuid				
		ORDER BY #result.Date, #result.StmCode, #result.VoucherCode


######################################################################
CREATE  PROC prcTrn_OutStamentRep
	@SourceRepGuid UNIQUEIDENTIFIER,
	@StartDate DATETIME,
	@EndDate DATETIME
	
AS

	SET NOCOUNT ON	
	CREATE TABLE #RESULT
		(
			StmType		NVARCHAR(250) COLLATE ARABIC_CI_AI,
			StmGuid		UNIQUEIDENTIFIER,
			StmCode		NVARCHAR(250) COLLATE ARABIC_CI_AI,
			IsVoucherGen 	INT,
			VoucherGuid	UNIQUEIDENTIFIER,
			VoucherTypeGuid	UNIQUEIDENTIFIER,
			VoucherCode	NVARCHAR(250) COLLATE ARABIC_CI_AI,
			[Date] 		DATETIME,

			Sender		UNIQUEIDENTIFIER,
			SenderName		NVARCHAR(250) COLLATE ARABIC_CI_AI,
			SenderPhone	NVARCHAR(250) COLLATE ARABIC_CI_AI,
			Receiver	UNIQUEIDENTIFIER,
			ReceiverName	NVARCHAR(250) COLLATE ARABIC_CI_AI,
			ReceiverPhone	NVARCHAR(250) COLLATE ARABIC_CI_AI,

			Amount		FLOAT,
			Currency	UNIQUEIDENTIFIER,
			CurrVal 	FLOAT,
			NetWages	FLOAT,

			PayAmount	FLOAT,
			PayCurrency	UNIQUEIDENTIFIER,
			PayCurVal 	FLOAT,
			Notes		NVARCHAR(250) COLLATE ARABIC_CI_AI
		)

	INSERT INTO #RESULT	
	SELECT  
		stmType.[ttName],
		--Stmtype.[IsOut],
		stm.Guid,
		stm.Code,1,
		V.TVGUID,
		0x0,--V.TVParentGUID,
		V.TVCODE,
		v.TVDueDate,
		Sender.SRGuid,
		Sender.SRName,
		Sender.SRPhone1, 
		Res.SRGuid,
		Res.SRName,
		Res.SRPhone1,
		V.TVAmount/ISNULL(V.TVCurrencyVal, 1),
		V.TVCurrencyGUID, 
		V.TVCurrencyVal, 
		V.TVNetWages, 
		V.TVMustPaidAmount/ISNULL(V.TVPayCurrencyVal, 1),
		V.TVPayCurrency, 
		V.TVPayCurrencyVal,
		V.TVNOTES
	FROM	
		vwTrnStatement AS stm
		INNER JOIN vwTrnStatementTypes  AS Stmtype ON
				stm.TypeGUID = Stmtype.ttGuid AND Stmtype.IsOut = 1
		INNER JOIN RepSrcs AS src ON src.IdType = stm.TypeGUID
		INNER  JOIN vwTrnTransferVoucher AS V ON OutStatementGuid = stm.Guid
		INNER JOIN vwTrnSenderReceiver  AS Sender ON Sender.SRGuid = V.TVSenderGUID
		INNER JOIN vwTrnSenderReceiver  AS Res ON Res.SRGuid = V.TVReceiver1_GUID

			
	WHERE
		stm.[Date] BETWEEN @StartDate AND @EndDate  
		And src.IdTbl = @SourceRepGuid
	
	SELECT * FROM #result 
	ORDER BY [Date], StmCode, VoucherCode
#####################################################################################
#END
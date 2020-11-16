############################################
CREATE PROCEDURE PrcTrnBlackListRep
(
	@RepSrcsMask	INT
)
AS
	SET NOCOUNT ON
	CREATE TABLE #Result
	(
		
		[PersonName]		NVARCHAR(100) COLLATE ARABIC_CI_AI,
		[PersonNumber]		NVARCHAR(100) COLLATE ARABIC_CI_AI,
		[ProcessDate]		DateTime,
		[ProcessNumber]		INT,
		[ProcessParent]		NVARCHAR(50) COLLATE ARABIC_CI_AI,
		[ProcessOwner]		NVARCHAR(50) COLLATE ARABIC_CI_AI,
		[ProcessGuid]		UNIQUEIDENTIFIER,
		[ProcessType]		INT	--0 Exchange, 1 ExchangeDetail, 2 Voucher, 3 PayVoucher, 4 Statement
	)
	
	IF (@RepSrcsMask & 1/*Exchaneg*/ <> 0)
	BEGIN
		INSERT INTO #Result 
		SELECT ex.CustomerName, ex.CutomerIdentityNo, ex.Date, ex.Number, 
			   (CASE WHEN EXISTS(SELECT * FROM TrnExchangeDetail000 WHERE ExchangeGuid = ex.Guid) THEN '›« Ê—… ’—«›…' ELSE '≈Ì’«· ’—«›…' END), 
			    exType.Name, 
			    ex.Guid, 
			   (CASE WHEN EXISTS(SELECT * FROM TrnExchangeDetail000 WHERE ExchangeGuid = ex.Guid) THEN 1 ELSE 0 END)
		FROM TrnExchange000 ex
		INNER JOIN TrnExchangeTypes000 exType ON ex.TypeGuid = exType.GUID
		INNER JOIN TrnBlackList000 BlackList ON BlackList.bIsActivated = 1 AND (BlackList.CustomerName LIKE ex.CustomerName OR BlackList.CustomerNumber LIKE ex.CutomerIdentityNo)
		LEFT JOIN 
				 (
				  SELECT TOP 1 Detail.* 
				  FROM TrnExchangeDetail000 Detail
				  INNER JOIN TrnExchange000 exchange ON exchange.Guid = Detail.ExchangeGuid
				  INNER JOIN TrnBlackList000 BList ON BList.bIsActivated = 1 AND (BList.CustomerName LIKE exchange.CustomerName OR BList.CustomerNumber LIKE exchange.CutomerIdentityNo)
				 ) 
				 AS exDetail ON ex.GUID = exDetail.ExchangeGUID
	END
	
	IF (@RepSrcsMask & 2/*Voucher*/ <> 0)
	BEGIN
		INSERT INTO #Result
		SELECT Sender.Name, Sender.IdentityNo, Voucher.Date, Voucher.Number, '≈Ì’«· ÕÊ«·…', ProcessOwner.LoginName, Voucher.GUID, 2
		FROM TrnTransferVoucher000	Voucher
		INNER JOIN TrnSenderReceiver000 Sender ON Voucher.SenderGUID = Sender.GUID
		INNER JOIN us000 ProcessOwner ON ProcessOwner.GUID = Voucher.SenderUserGuid	
		INNER JOIN TrnBlackList000 BlackList ON BlackList.bIsActivated = 1 AND (BlackList.CustomerName LIKE Sender.Name OR BlackList.CustomerNumber LIKE Sender.IdentityNo)
		
		UNION
		
		SELECT Reciever.Name, Reciever.IdentityNo, Voucher.Date, Voucher.Number, '≈Ì’«· ÕÊ«·…', ProcessOwner.LoginName, Voucher.GUID, 2
		FROM TrnTransferVoucher000	Voucher
		INNER JOIN TrnSenderReceiver000 Reciever ON Reciever.GUID IN (Voucher.Receiver1_GUID, Voucher.Receiver2_GUID, Voucher.UpdatedReciever1, Voucher.UpdatedReciever2) 
		INNER JOIN us000 ProcessOwner ON ProcessOwner.GUID = Voucher.SenderUserGuid	
		INNER JOIN(
					 SELECT TOP 1 blist.* 
					 FROM TrnTransferVoucher000 V
					 INNER JOIN TrnSenderReceiver000 rec ON rec.GUID IN (V.Receiver1_GUID, V.Receiver2_GUID, V.UpdatedReciever1, V.UpdatedReciever2) 
					 INNER JOIN TrnBlackList000 blist ON blist.bIsActivated = 1 AND (blist.CustomerName LIKE rec.Name OR blist.CustomerNumber LIKE rec.IdentityNo)
				  ) 
				   AS BlackList ON BlackList.bIsActivated = 1 AND (BlackList.CustomerName LIKE Reciever.Name OR BlackList.CustomerNumber LIKE Reciever.IdentityNo)										   
											   
	END
	
	IF (@RepSrcsMask & 4/*Pay Voucher*/ <> 0)
	BEGIN
		INSERT INTO #Result
		SELECT ActualReciever.Name, PayInfo.IdentityCard, PayInfo.Date, Voucher.Number, 'œ›⁄ ÕÊ«·…', ProcessOwner.LoginName, Voucher.GUID, 3
		FROM TrnTransferVoucher000	Voucher
		INNER JOIN TrnVoucherPayInfo000 PayInfo ON Voucher.GUID = PayInfo.VoucherGuid
		INNER JOIN TrnSenderReceiver000 ActualReciever ON ActualReciever.GUID = PayInfo.ActualReceiverGUID
		INNER JOIN us000 ProcessOwner ON ProcessOwner.GUID = Voucher.RecieverUserGuid
		INNER JOIN TrnBlackList000 BlackList ON BlackList.bIsActivated = 1 AND (BlackList.CustomerName LIKE ActualReciever.Name OR BlackList.CustomerNumber LIKE PayInfo.IdentityCard)
	END
	
	IF (@RepSrcsMask & 8/*InStatement*/ <> 0)
	BEGIN
		INSERT INTO #Result
		SELECT Sender.Name, Sender.IdentityNo, InStatement.Date, InStatement.Number, 'ﬂ‘› Ê«—œ', stType.Name, InStatement.ParentGUID, 4
		FROM TrnStatementItems000 InStatement
		INNER JOIN TrnStatement000 stParent ON InStatement.ParentGUID = stParent.GUID
		INNER JOIN TrnStatementTypes000 stType ON stParent.TypeGUID = stType.GUID
		INNER JOIN TrnSenderReceiver000 Sender ON InStatement.SenderGUID = Sender.GUID
		INNER JOIN TrnBlackList000 BlackList ON BlackList.bIsActivated = 1 AND (BlackList.CustomerName LIKE Sender.Name OR BlackList.CustomerNumber LIKE Sender.IdentityNo)
		
		UNION 
		
		SELECT Reciever.Name, Reciever.IdentityNo, InStatement.Date, InStatement.Number, 'ﬂ‘› Ê«—œ', stType.Name, InStatement.ParentGUID, 4
		FROM TrnStatementItems000 InStatement
		INNER JOIN TrnStatement000 stParent ON InStatement.ParentGUID = stParent.GUID
		INNER JOIN TrnStatementTypes000 stType ON stParent.TypeGUID = stType.GUID
		INNER JOIN TrnSenderReceiver000 Reciever ON Reciever.GUID IN (InStatement.Receiver1_GUID, InStatement.Receiver2_GUID) 
		INNER JOIN(
					 SELECT TOP 1 blist.* 
					 FROM TrnStatementItems000 st
					 INNER JOIN TrnSenderReceiver000 rec ON rec.GUID IN (st.Receiver1_GUID, st.Receiver2_GUID)
					 INNER JOIN TrnBlackList000 blist ON blist.bIsActivated = 1 AND (blist.CustomerName LIKE rec.Name OR blist.CustomerNumber LIKE rec.IdentityNo)
				  ) 
				   AS BlackList ON BlackList.bIsActivated = 1 AND (BlackList.CustomerName LIKE Reciever.Name OR BlackList.CustomerNumber LIKE Reciever.IdentityNo)										   
	END
	
	SELECT * FROM #Result order by ProcessType,ProcessNumber
############################################
#END
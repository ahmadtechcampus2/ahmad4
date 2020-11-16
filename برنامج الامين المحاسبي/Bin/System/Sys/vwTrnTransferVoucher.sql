#########################################################
CREATE VIEW vtTrnTransferVoucher
AS
	SELECT * FROM  TrnTransferVoucher000 
#########################################################
CREATE VIEW vbTrnTransferVoucher
AS
	SELECT v.*
	FROM vtTrnTransferVoucher AS v
	INNER JOIN fnBranch_GetCurrentUserReadMask(DEFAULT) AS f ON v.branchMask & f.Mask <> 0
#########################################################
CREATE VIEW vcTrnTransferVoucher
AS
	SELECT 
		* 
	FROM vbTrnTransferVoucher
	--UNION 
	--SELECT *
	--FROM vtTrnTransferVoucher 
	--WHERE vtTrnTransferVoucher.bPayedAnyBranch = 1
#########################################################
CREATE VIEW vdTrnTransferVoucher
AS
	SELECT DISTINCT * FROM vcTrnTransferVoucher
#########################################################
CREATE VIEW vwTrnTransferVoucher
AS   
	SELECT DISTINCT
 		V.GUID 				AS TVGUID,
		--V.Type 			AS TVType, 
		V.Number			AS TVNumber, 
		V.Code				AS TVCode, 
		V.OriginalCode		AS TVOriginalCode, 
		V.SourceType		AS TVSourceType,
		V.DestinationType	AS TVDestinationType,
		V.SourceBranch		AS TVSourceBranch, 
		V.AgentBranch		AS TVAgentBranch,
		V.Date				AS TVDate, 
		V.DueDate			AS TVDueDate, 
		IsNull(pay.[pDate], '')		AS TvPayDate,
		IsNull(ny.[DateTime], '')	AS TVNotifyDate,
		V.StatementNumber	AS TVStatementNumber, 
		V.DestinationBranch	AS TVDestinationBranch, 	
		
		V.SenderGUID		AS TVSenderGUID,
		V.Receiver1_GUID	AS TVReceiver1_GUID,
		V.Receiver2_GUID	AS TVReceiver2_GUID, 
		V.Receiver3_GUID	AS TVReceiver3_GUID,
		V.UpdatedReciever1	AS TVUpdatedReciever1,
		V.UpdatedReciever2	AS TVUpdatedReciever2,
		V.PayType		AS TVPayType, 
		V.AccountGUID		AS TVAccountGUID, 
		V.State			AS TVState, 
		
		V.Amount		AS TVAmount, 
		V.MustPaidAmount	AS TVMustPaidAmount, 
		V.Wages			AS TVWages, 
		V.PaidWages		AS TVPaidWages, 
		V.WagesDisc		AS TVWagesDisc, 
		V.WagesExtra		AS TVWagesExtra, 
		V.ReturnWages		AS TVReturnWages, 
		V.NotPaidWages		AS TVNotPaidWages, 
		V.NetWages		AS TVNetWages,	
		V.CurrencyGUID		AS TVCurrencyGUID, 
		V.CurrencyVal		AS TVCurrencyVal, 
		V.WagesType		AS TVWagesType, 
		V.SendDate		AS TVSendDate, 
		V.Approved		AS TVApproved, 
		V.Notes			AS TVNotes, 
		V.Security		AS TVSecurity, 
		V.InternalNum		AS TVInternalNum,
		--V.IsSent		AS TVIsSent,
		V.TrnTime		AS TVTrnTime,
		V.Cashed		AS TVCashed, 
		V.paid			AS TVpaid,
		V.Notified		AS TVNotified,
		v.IsFromStatement	AS TVFromStatement,
		ISNULL(pCurrencyGuid, V.PayCurrency)	AS TVPayCurrency,
		ISNULL(pCurrencyVal, V.PayCurrencyVal)	AS TVPayCurrencyVal,
		v.Reason		AS TVReason,
		--V.ReciverBankguid AS TVReciverBankguid,
		--V.RecieverBankAccountNum AS TVRecieverBankAccountNum,
		V.MustCashedAmount AS TVMustCashedAmount,
		V.DestRecordedAmount AS TVDestRecordedAmount,
		V.exchangeCurrency AS TVexchangeCurrency,
		V.exchangeCurrencyVal AS TVexchangeCurrencyVal,
		V.PrintTimes AS TVPrintTimes,
		V.CashRecieptCode AS TVCashRecieptCode,
		brS.GUID 		AS SourceAmnBranchGuid,
		brD.GUID 		AS DestAmnBranchGuid,
		brS.[Name] 		AS SourcBranchName,
		brD.[Name] 		AS DestBranchName,
		Send.Name 		AS SenderName,
		Send.IdentityNo 	AS SenderIdentityNo,
		Send.IdentityType 	AS SenderIdentityType,
		Send.IdentityDate	AS SenderIdentityDate,
		Send.Nation		AS SenderNation,	
		Send.DocumentExpiryDate AS SenderDocumentExpiryDate,
		Rec.Name AS ReceivName,
		UpdatedRec.Name AS UpdatedRecName,
		--CASE WHEN v.updatedReciever1 = 0x0 THEN Rec.Name ELSE Rec.Name END AS ReceivName,
		CASE WHEN v.updatedReciever2 = 0x0 THEN (CASE WHEN v.Receiver2_GUID = 0x0 THEN '' ELSE Rec2.Name END) ELSE UpdatedRec2.Name END AS Receiv2Name,
		Send.Phone1 		AS SenderPhone1, 
		Send.Phone2 		AS SenderPhone2,
		Rec.Phone1 AS RecPhone1,
		Rec.Phone2 AS RecPhone2,
		Rec.DocumentExpiryDate AS RecDocumentExpiryDate,
		UpdatedRec.Phone1 as UpdatedRecPhone1,
		UpdatedRec.Phone2 as UpdatedRecPhone2,
		--CASE WHEN v.updatedReciever1 = 0x0 THEN Rec.Phone1 ELSE UpdatedRec.Phone1 END AS RecPhone1,
		--CASE WHEN v.updatedReciever1 = 0x0 THEN Rec.Phone2 ELSE UpdatedRec.Phone2 END AS RecPhone2,
		CASE WHEN v.updatedReciever2 = 0x0 THEN (CASE WHEN v.Receiver2_GUID = 0x0 THEN '' ELSE Rec2.Phone1 END) ELSE UpdatedRec2.Phone1 END AS Rec2Phone1,
		CASE WHEN v.updatedReciever2 = 0x0 THEN (CASE WHEN v.Receiver2_GUID = 0x0 THEN '' ELSE Rec2.Phone2 END) ELSE UpdatedRec2.Phone2 END AS Rec2Phone2,
		Send.Address			AS SenderAddress,
		myCash.Name 			AS CurrencyName	,
		myPay.Name 			AS PayCurrencyName,
		myExchange.Name 		AS ExchangeCurrencyName,
		ISNULL(Pay.pRecevierName,'')	AS TVActualReceiverName,
		ISNULL(Pay.pMothername,'')   AS TVActualReceiverMothername,
		ISNULL(Pay.pIdentityCard,'')	AS TVActualIdentityCard,
		ISNULL(Pay.pIdentityCardType,'')	AS TVActualIdentityCardType,
		ISNULL(Pay.pIdentityDate,'01-01-1980')	AS TVActualIdentityDate,
		ISNULL(Pay.pIdentityPlace,'')   AS TVActualReceiverIdentityPlace,
		--ISNULL(Pay.pRecevierNation,'')	AS TVActualRecevierNation,	
		ISNULL(Pay.pActualReceiverNation,'')	AS TVActualRecevierNation,	
		ISNULL(Pay.pActualReceiverAddress,'')	AS TVActualReceiverAddress,
		ISNULL(Pay.pActualReceiverBirthplace,'') AS TVActualReceiverBirthplace,
		ISNULL(Pay.pActualReceiverBirthDate,'01-01-1900')	AS TVActualReceiverBirthDate,
		ISNULL(Pay.pPayNotes,'')	AS TVPayNotes,
		ISNULL(Pay.pPayRecieptCode,'') AS TVPayRecieptCode,
		
		ISNULL(inStm.Guid, 0x0) AS InStatementGuid, 
		ISNULL(inStm.Code, 0)	AS InStatementCode,
		ISNULL(OutStm.Guid, 0x0)AS OutStatementGuid,
		ISNULL(OutStm.Code, 0) 	AS OutStatementCode,
		V.SenderCenterGuid AS TVSenderCenterGuid,
		V.RecieverCenterGuid AS TVRecieverCenterGuid,
		ISNULL(SendCenter.Name,'') AS TVSenderCenterName,
		ISNULL(RecieverCenter.Name,'') AS TVRecieverCenterName,
		V.BankOrderGuid AS TVBankOrderGuid

	FROM  
		vcTrnTransferVoucher AS V
		INNER JOIN vtMy myCash ON v.CurrencyGuid = myCash.GUID
		INNER JOIN vtMy myPay ON v.PayCurrency = myPay.GUID
		INNER JOIN vtMy myExchange ON v.ExchangeCurrency = myExchange.GUID
		INNER JOIN(
			SELECT Guid, Name, 1 AS type FROM TrnBranch000
			UNION ALL
			SELECT Guid, Name, 2 FROM TrnOffice000
		) AS brS ON v.SourceBranch = brS.GUID
		INNER JOIN(
			SELECT Guid, Name, 1 AS type FROM TrnBranch000
			UNION ALL
			SELECT Guid, Name, 2 FROM TrnOffice000
		) AS brD ON v.DestinationBranch = brD.GUID
		INNER JOIN vwTrnSendRec Send ON v.SenderGuid = Send.GUID
		INNER JOIN vwTrnSendRec Rec On v.Receiver1_GUID = Rec.GUID
		LEFT JOIN vwTrnVoucherPayInfo AS pay ON pay.pVouvherGuid = V.guid
		LEFT JOIN TrnNotify000 AS ny on ny.VoucherGuid = V.Guid
		LEFT JOIN vwTrnStatement AS inStm on InStm.Guid = V.StatementGuid 
		LEFT JOIN vwTrnStatement AS OutStm on OutStm.Guid = V.OutStatementGuid
		LEFT JOIN vwTrnSendRec AS Rec2 On v.Receiver2_GUID = Rec2.GUID
		LEFT JOIN vwTrnSendRec AS UpdatedRec  On v.updatedReciever1 = UpdatedRec.GUID
		LEFT JOIN vwTrnSendRec AS UpdatedRec2 On v.updatedReciever2 = UpdatedRec2.GUID
		LEFT JOIN vwTrnCenter AS SendCenter ON SendCenter.Guid = v.SenderCenterGuid
		LEFT JOIN vwTrnCenter AS RecieverCenter ON RecieverCenter.Guid = v.RecieverCenterGuid
#########################################################
CREATE FUNCTION fbTrnTransferVoucher
	( @TypeGUID UNIQUEIDENTIFIER)
	RETURNS TABLE
	AS
		RETURN (SELECT * FROM vcTrnTransferVoucher AS bu )
#########################################################
CREATE FUNCTION fbTrnInternal_VoucherOut
	( @SourceBranchGUID UNIQUEIDENTIFIER)
RETURNS TABLE
AS
	RETURN 
	(
		SELECT 
			* 
		FROM vcTrnTransferVoucher 
		WHERE 
			SourceBranch = @SourceBranchGUID
			AND 
			SourceType = 1
			AND
			DestinationType = 1
	)
#########################################################
CREATE FUNCTION fbTrnInternal_VoucherOutNumber()
RETURNS TABLE
AS
	RETURN 
	(
		SELECT 
			* 
		FROM vcTrnTransferVoucher 
		WHERE 
			SourceType = 1
			AND
			DestinationType = 1
	)
#########################################################	
CREATE FUNCTION fbTrnInternal_VoucherIn( @DestBranchGUID UNIQUEIDENTIFIER)
RETURNS @Result TABLE(
	GUID				UNIQUEIDENTIFIER,
	TYPE				INT,
	Number2				INT,
	Number				INT,
	Code				NVARCHAR(100),
	SourceBranch		UNIQUEIDENTIFIER,
	DestinationBranch	UNIQUEIDENTIFIER,
	SourceType			INT,
	DestinationType		INT
)
AS
BEGIN
	Declare @CanBePayidAtAnyBranch bit
	SELECT @CanBePayidAtAnyBranch  = CAST(value AS BIT) from op000 where name = 'TrnCfg_TrnCanBePayidAtAnyBranch'
	SET @CanBePayidAtAnyBranch = ISNULL(@CanBePayidAtAnyBranch, 0)

INSERT INTO @Result
	SELECT 
		GUID,
		TYPE,
		InternalNum, -- AS Number2,
		Number, -- AS Number,
		Code, 
		SourceBranch, --SourceBranch,
		DestinationBranch,
		SourceType,
		DestinationType
	FROM vcTrnTransferVoucher
	WHERE 
		--SourceBranch <> @DestBranchGUID
		(DestinationBranch = @DestBranchGUID
			OR (@CanBePayidAtAnyBranch = 1 AND CanbepayidAtDistBranchOnly = 0)
		)
		AND SourceType = 1
		AND DestinationType = 1
	
	RETURN
END
#########################################################
CREATE FUNCTION fbTrnInternal_VoucherInNumber()
RETURNS @Result TABLE(
	GUID				UNIQUEIDENTIFIER,
	TYPE				INT,
	Number2				INT,
	Number				INT,
	SourceBranch		varchar(200),
	DestinationBranch	UNIQUEIDENTIFIER,
	SourceType			INT,
	DestinationType		INT
)
AS
BEGIN
	Declare @CanBePayidAtAnyBranch bit
	SELECT @CanBePayidAtAnyBranch  = CAST(value AS BIT) from op000 where name = 'TrnCfg_TrnCanBePayidAtAnyBranch'
	SET @CanBePayidAtAnyBranch = ISNULL(@CanBePayidAtAnyBranch, 0)
INSERT INTO @Result
	SELECT 
		GUID,
		TYPE,
		Number, -- AS Number2,
		Number2, -- AS Number,
		Code, --SourceBranch,
		DestinationBranch,
		SourceType,
		DestinationType
	FROM vcTrnTransferVoucher
	WHERE 
		(SourceBranch <> DestinationBranch
		OR (@CanBePayidAtAnyBranch = 1 AND CanbepayidAtDistBranchOnly = 0)
		)
		AND SourceType = 1
		AND DestinationType = 1
	
	RETURN
END
#########################################################
CREATE FUNCTION fbTrnExternal_VoucherOut
	( @SourceBranchGUID UNIQUEIDENTIFIER)
RETURNS TABLE
AS
	RETURN 
	(
		SELECT 
			* 
		FROM vcTrnTransferVoucher 
		WHERE 
			(
				SourceType <> 1
				OR
				DestinationType <> 1
			)	
			AND
			(
				SourceBranch = @SourceBranchGUID
				OR 
				(AgentBranch =  @SourceBranchGUID AND (SourceType <> 1 AND DestinationType <> 1 ))
			)
	)
#########################################################
CREATE FUNCTION fbTrnExternal_VoucherIn
( @DestBranchGUID UNIQUEIDENTIFIER)
RETURNS TABLE
AS
RETURN (
		SELECT 
			[GUID],
			Number AS Number2,
			Number2 AS Number,
			Code
			SourceBranch,
			DestinationBranch,
			SourceType,
			DestinationType
		FROM vcTrnTransferVoucher
		WHERE 
			(
				SourceType <> 1
				OR
				DestinationType <> 1
			)	
			AND
			(
				DestinationBranch = @DestBranchGUID
				OR 
				(AgentBranch =  @DestBranchGUID AND (SourceType <> 1 AND DestinationType <> 1 ))
			)
		)	
#########################################################
CREATE FUNCTION fbTrnTransferSenderRecievers
	( @TransferGUID UNIQUEIDENTIFIER)
	RETURNS TABLE
	AS
		RETURN (
				SELECT
					v.GUID							AS TransferGUID, 
					Send.Name 						AS SenderName,
					Send.IdentityNo 				AS SenderIdentityNo,
					Send.IdentityType 				AS SenderIdentityType,
					Send.IdentityDate				AS SenderIdentityDate,
					Send.Nation						AS SenderNation,
					Send.Phone1						AS SenderPhone1,
					Send.Address					AS SenderAddress,
					Rec.Name						AS ReceivName,
					Rec.Phone1						AS RecPhone1,
					ISNULL(Rec2.Name, '')			AS Receiv2Name,
					ISNULL(Rec2.Phone1, '')			AS Rec2Phone1,
					ISNULL(UpdatedRec.Name, '')		AS UpdatedRecName,
					ISNULL(UpdatedRec.Phone1, '') 	AS UpdatedRecPhone1,
					ISNULL(UpdatedRec2.Name, '')	AS UpdatedRec2Name,
					ISNULL(UpdatedRec2.Phone1, '') 	AS UpdatedRec2Phone1

				FROM vcTrnTransferVoucher AS v
					INNER JOIN vwTrnSendRec Send ON v.SenderGuid = Send.GUID
					INNER JOIN vwTrnSendRec Rec On v.Receiver1_GUID = Rec.GUID
					LEFT JOIN vwTrnSendRec AS Rec2 On v.Receiver2_GUID = Rec2.GUID
					LEFT JOIN vwTrnSendRec AS UpdatedRec  On v.updatedReciever1 = UpdatedRec.GUID
					LEFT JOIN vwTrnSendRec AS UpdatedRec2 On v.updatedReciever2 = UpdatedRec2.GUID
				WHERE (@TransferGUID = 0x0 OR v.GUID = @TransferGUID)
				)
#########################################################
#END

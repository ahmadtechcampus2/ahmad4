######################################################
CREATE VIEW vwTrnVoucherPayInfo
AS
	SELECT	
		Pay.GUID				pGUID,
		Pay.VoucherGuid			pVouvherGuid,
		Pay.ActualReceiverGUID	pActualReceiverGUID,
		Pay.IdentityCard		pIdentityCard,
		Pay.IdentityCardType	pIdentityCardType,
		Pay.IdentityDate		pIdentityDate,
		Pay.IdentityPlace       pIdentityPlace,
		Pay.MotherName          pMothername,
		Pay.[Date]				pDate,
		pay.ActualReceiverNation   pActualReceiverNation,
		pay.ActualReceiverAddress  pActualReceiverAddress,
		Pay.BirthPlace          pActualReceiverBirthplace,
		Pay.BirthDate           pActualReceiverBirthDate,
		Pay.PayNotes            pPayNotes,
		Pay.CurrencyGuid		pCurrencyGuid,
		Pay.CurrencyVal			pCurrencyVal,
		Pay.PayRecieptCode      pPayRecieptCode,
		recevier.[Name]			pRecevierName,
		recevier.IdentityNo		pRecevierIdentityNo,
		recevier.IdentityType	pRecevierIdentityType,
		recevier.IdentityDate	pRecevierIdentityDate,
		recevier.Address		pRecevierAddress,
		recevier.Nation			pRecevierNation
	FROM
		TrnVoucherPayInfo000 AS Pay 
		INNER JOIN vwTrnSendRec AS recevier ON Pay.ActualReceiverGUID = recevier.GUID
######################################################
#END
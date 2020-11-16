################################################################################
CREATE VIEW vwPOSSDExternalOperationDebitCreditType
AS 
		SELECT  
		[ExternalTx] .[GUID] AS TxGUID,
		[ExternalTx].[Type] AS TxType,
		[ExternalTx].[Note] AS TxNote,
		[ExternalTx].[Date] AS TxDate,	
		[ExternalTx].[State] AS TxStatus,
		[shift].[GUID] AS ShiftGUID,
		[shift].[OpenDate] AS ShiftOpenDate ,
		[shift].CloseDate AS ShiftCloseDate ,
		[POSStation].[GUID] AS POSStationGUID,
		[ExternalTx].[CreditAccountGUID] AS TxCreditGLAccountGuid,
		[ExternalTx].[DebitAccountGUID] AS TxDebitAccountGUID,
		[cu].[cuGUID] AS CustomerGuid,
		[cu].[cuSecurity] AS CustomerSecurity,
		[cu].[acGUID] AS CustomerGLAccountGUID,
		[cu].acSecurity AS CustomerGLAccountSecurity,
		[CU].[cuCustomerName],
		[ExternalTx].[Number] AS TxNumber,	
		
		/*
		CASE [ExternalTx].[Type] 
			WHEN 2 THEN ([ExternalTx].[Amount] * [ExternalTx].[CurrencyValue]) -- debit			
		ELSE
			0
		END  AS FN_DEBIT,
		*/
		CASE WHEN [CU].acGUID = [ExternalTx].[DebitAccountGUID]	THEN 	([ExternalTx].[Amount] * [ExternalTx].[CurrencyValue])
		ELSE 0 END AS FN_DEBIT,

		CASE WHEN [CU].acGUID = [ExternalTx].CreditAccountGUID	THEN 	([ExternalTx].[Amount] * [ExternalTx].[CurrencyValue])
		ELSE 0 END AS FN_CREDIT,
		/*
		CASE [ExternalTx].[Type] 
			WHEN 1 THEN ([ExternalTx].[Amount] * [ExternalTx].[CurrencyValue]) -- credit			
		ELSE
			0
		END  AS FN_CREDIT,*/
		
		/*CASE [ExternalTx].[Type] 
			WHEN 1 THEN ([ExternalTx].[Amount]) -- debit			
		ELSE
			0
		END  AS TX_DEBIT,

		CASE [ExternalTx].[Type] 
			WHEN 2 THEN ([ExternalTx].[Amount]) -- credit			
		ELSE
			0
		END  AS TX_CREDIT,*/
		CASE WHEN [CU].acGUID = [ExternalTx].[DebitAccountGUID]	THEN 	([ExternalTx].[Amount])
		ELSE 0 END AS TX_DEBIT,

		CASE WHEN [CU].acGUID = [ExternalTx].CreditAccountGUID	THEN 	([ExternalTx].[Amount])
		ELSE 0 END AS TX_CREDIT,

		1 AS TxSecurity

	FROM [POSSDExternalOperation000] AS [ExternalTx] 
	INNER JOIN [POSSDShift000]  AS [shift]		ON [shift].[GUID] = [ExternalTx].ShiftGUID
	INNER JOIN [vWCuAC]		    AS [cu] ON ([CU].acGUID = [ExternalTx].CreditAccountGUID OR [CU].acGUID = [ExternalTx].DebitAccountGUID)
	INNER JOIN [POSSDStation000] AS [POSStation]	ON [shift].StationGUID = POSStation.GUID
	WHERE [ExternalTx].[Type] IN (1,2)
################################################################################
#END

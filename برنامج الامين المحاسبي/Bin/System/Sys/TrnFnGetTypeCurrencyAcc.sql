#############################################
CREATE FUNCTION TrnFnGetTypeCurrencyAcc(@TypeGuid UNIQUEIDENTIFIER, @UserGuid UNIQUEIDENTIFIER)
	RETURNS @result TABLE 
	(
		MyNumber	 INT,
		MyGuid		 UNIQUEIDENTIFIER,
		CurrencyGuid UNIQUEIDENTIFIER,
		TypeGuid	 UNIQUEIDENTIFIER,
		AccountGuid  UNIQUEIDENTIFIER,
		SellsAcc	 UNIQUEIDENTIFIER,
		SellsCostAcc UNIQUEIDENTIFIER,
		Number		 INT
	)
AS
BEGIN
	DECLARE @IsGenEntriesAccordingToUserAccounts BIT
	SELECT @IsGenEntriesAccordingToUserAccounts = CAST(value AS BIT)FROM op000 
													WHERE Name = 'TrnCfg_Exchange_GenEntriesAccordingToUserAccounts'
	IF (ISNULL(@IsGenEntriesAccordingToUserAccounts, 0) = 0)
	BEGIN
		INSERT INTO @result
		SELECT
			my.Number,
			My.Guid,
			isNull(ac.CurrencyGuid, My.Guid),
			isNull(Type.Guid, 0x0),
			isNull(ac.AccountGuid, 0x0),
			isNull(sell.SellsAccGUID, 0x0),
			isNull(sell.SellsCostAccGUID, 0x0),
			isNull(ac.number, 0)	
		FROM 
			MY000 as my
			INNER JOIN TrnCurrencyAccount000 as AC ON ac.CurrencyGUID = my.GUID
			INNER JOIN TrnGroupCurrencyAccount000 as gr ON gr.GUID = ac.ParentGUID
			INNER JOIN TrnExchangeTypes000 AS type ON type.GroupCurrencyAccGUID = gr.GUID
			--INNER JOIN TrnUserConfig000 AS uc ON uc.GroupCurrencyAccGUID = gr.GUID
			LEFT JOIN TrnCurrencySellsAcc000 AS sell ON sell.CurrencyGUID = my.GUID
		WHERE  
			(@TypeGuid = 0x0 OR IsNull(type.Guid, @TypeGuid)  = @TypeGuid)	 
		ORDER BY 
			my.number
	END
	ELSE
	BEGIN
		INSERT INTO @result
		SELECT
			my.Number,
			My.Guid,
			isNull(ac.CurrencyGuid, My.Guid),
			0x0, --isNull(Type.Guid, 0x0),
			isNull(ac.AccountGuid, 0x0),
			isNull(sell.SellsAccGUID, 0x0),
			isNull(sell.SellsCostAccGUID, 0x0),
			isNull(ac.number, 0)	
		FROM 
			MY000 as my
			INNER JOIN TrnCurrencyAccount000 as AC ON ac.CurrencyGUID = my.GUID
			INNER JOIN TrnGroupCurrencyAccount000 as gr ON gr.GUID = ac.ParentGUID
			--INNER JOIN TrnExchangeTypes000 AS type ON type.GroupCurrencyAccGUID = gr.GUID
			INNER JOIN TrnUserConfig000 AS uc ON uc.GroupCurrencyAccGUID = gr.GUID
			LEFT JOIN TrnCurrencySellsAcc000 AS sell ON sell.CurrencyGUID = my.GUID
		WHERE  
			(@UserGuid = 0x0 OR uc.UserGuid  = @UserGuid)	 
		ORDER BY 
			my.number
	END
	
	RETURN
END
#############################################
CREATE Function fnGetExchangeLocalCurrency()
	returns uniqueidentifier	
AS
BEGIN
	RETURN
		(SELECT
			guid
		 FROM 
			my000	
		WHERE 
			CurrencyVal = 1
		)
END
####################################################
#END

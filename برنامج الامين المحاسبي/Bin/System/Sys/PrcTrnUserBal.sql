##################################################################
CREATE Procedure PrcTrnUserBalRep
	@UserGuid UNIQUEIDENTIFIER, 
	@FromDate DATETIME = '1-1-1900',  
	@ToDate	DATETIME = '1-1-2100' 
AS 
	SET NOCOUNT ON  
	/* -------------------------------BALANCE RESULT----------------------------------------------*/ 
	DECLARE @BalResult TABLE (Number INT,CurrencyName NVARCHAR(250) COLLATE ARABIC_CI_AI,
					SumDebit FLOAT, SumCredit FLOAT, Balance FLOAT, SumInVouchers FLOAT, SumOutVouchers FLOAT, VoucherBal FLOAT) 
	 
	INSERT INTO @BalResult 
	SELECT Currency.Number, Currency.Name, 0, 0, 0, ISNULL(Sum(en.Debit/en.CurrencyVal), 0), ISNULL(Sum(en.Credit/en.CurrencyVal), 0), 0 
	FROM EN000 AS en  
	INNER JOIN CE000 AS ce ON ce.GUID = en.ParentGuid 
	INNER JOIN ER000 AS er ON er.EntryGuid = ce.Guid AND (er.Parenttype = 500 OR er.Parenttype = 501) 
	INNER JOIN TRNUSERCONFIG000 AS UserConfig ON UserConfig.CostGuid = en.CostGuid AND UserConfig.UserGuid = @UserGuid  
	INNER JOIN TRNGROUPCURRENCYACCOUNT000 AS GroupCurr ON GroupCurr.GUID = UserConfig.GroupCurrencyAccGUID 
	INNER JOIN TRNCURRENCYACCOUNT000 AS CurrAcc ON CurrAcc.AccountGUID = en.AccountGUID AND CurrAcc.ParentGUID = GroupCurr.GUID 
	INNER JOIN MY000 AS Currency ON Currency.GUID = EN.CurrencyGUID 
	WHERE EN.DATE BETWEEN @FromDate AND @ToDate 
	GROUP BY Currency.Number, Currency.Name 
	ORDER BY Currency.Number 
	 
	DECLARE @Temp TABLE (TNumber INT,CurrencyName NVARCHAR(250), SumDebit FLOAT, SumCredit FLOAT) 
			        
	 
	INSERT INTO @Temp 
	SELECT TCurrency.Number, TCurrency.Name, ISNULL(Sum(Tempen.Debit/Tempen.CurrencyVal), 0), 
			                         ISNULL(Sum(Tempen.Credit/Tempen.CurrencyVal), 0) 
	FROM EN000 AS Tempen  
	INNER JOIN TRNUSERCONFIG000 AS UserConfig ON UserConfig.CostGuid = Tempen.CostGuid AND UserConfig.UserGuid = @UserGuid  
	INNER JOIN TRNGROUPCURRENCYACCOUNT000 AS GroupCurr ON GroupCurr.GUID = UserConfig.GroupCurrencyAccGUID 
	INNER JOIN TRNCURRENCYACCOUNT000 AS CurrAcc ON CurrAcc.AccountGUID = Tempen.AccountGUID AND CurrAcc.ParentGUID = GroupCurr.GUID 
	INNER JOIN MY000 AS TCurrency ON TCurrency.GUID = Tempen.CurrencyGUID 
	WHERE Tempen.DATE BETWEEN @FromDate AND @ToDate 
	AND Tempen.GUID NOT IN  
	(SELECT IsNull(en.GUID, 0x0)  
	FROM EN000 AS en  
	INNER JOIN CE000 AS ce ON ce.GUID = en.ParentGuid 
	INNER JOIN ER000 AS er ON er.EntryGuid = ce.Guid AND (er.Parenttype = 500 OR er.Parenttype = 501) 
	INNER JOIN TRNUSERCONFIG000 AS UserConfig ON UserConfig.CostGuid = en.CostGuid AND UserConfig.UserGuid = @UserGuid  
	INNER JOIN TRNGROUPCURRENCYACCOUNT000 AS GroupCurr ON GroupCurr.GUID = UserConfig.GroupCurrencyAccGUID 
	INNER JOIN TRNCURRENCYACCOUNT000 AS CurrAcc ON CurrAcc.AccountGUID = en.AccountGUID AND CurrAcc.ParentGUID = GroupCurr.GUID 
	INNER JOIN MY000 AS Currency ON Currency.GUID = EN.CurrencyGUID 
	WHERE EN.DATE BETWEEN @FromDate AND @ToDate) 
	 
	 
	GROUP BY TCurrency.Number, TCurrency.Name 
	ORDER BY TCurrency.Number 
	
	IF ( (SELECT COUNT(*) FROM @Temp) = 0)--No External Entries
		 UPDATE @BalResult SET SumDebit = SumInVouchers, 
				       SumCredit = SumOutVouchers,
				       Balance = SumInVouchers - SumOutVouchers,
				       VoucherBal = SumInVouchers - SumOutVouchers 
	
	ELSE	 
		UPDATE @BalResult SET SumDebit = SumInVouchers + ISNULL(TempTbl.SumDebit, 0), 
				      SumCredit = SumOutVouchers + ISNULL(TempTbl.SumCredit, 0), 
				      Balance = (SumInVouchers + ISNULL(TempTbl.SumDebit, 0)) - (SumOutVouchers + ISNULL(TempTbl.SumCredit, 0)), 
				      VoucherBal = SumInVouchers - SumOutVouchers 
		FROM @Temp AS TempTbl  
		WHERE Number = TempTbl.TNumber 
	/* -------------------------------STATISTIC RESULT----------------------------------------------*/ 
	DECLARE @StatisticResult TABLE(Number INT,BranchName NVARCHAR(250) COLLATE ARABIC_CI_AI, OutVoucher INT, InVoucher INT) 
	 
	INSERT INTO @StatisticResult 
	SELECT br.Number, br.Name ,COUNT(OutVoucher.Number), COUNT(InVoucher.Number) 
	FROM TrnBranch000 AS br 
	INNER JOIN TRNUSERCONFIG000 AS us ON us.UserGUID = @UserGuid AND us.TrnBranchGUID <> br.GUID 
	LEFT JOIN TrnTransferVoucher000 AS OutVoucher ON us.UserGUID = OutVoucher.SenderUserGUID AND OutVoucher.DestinationBranch = br.Guid AND (OutVoucher.Date BETWEEN @FromDate AND @ToDate)
	LEFT JOIN TrnTransferVoucher000 AS InVoucher ON us.UserGUID = InVoucher.RecieverUserGUID AND InVoucher.SourceBranch = br.Guid AND (InVoucher.Date BETWEEN @FromDate AND @ToDate)
	GROUP BY br.Number, br.Name  
	/*-----------------------------------------View Result*----------------------------------------------------*/ 
	SELECT * FROM @BalResult ORDER BY Number 
	SELECT * FROM @StatisticResult ORDER BY Number 
##################################################################
#END
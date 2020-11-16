##############################################################################
CREATE FUNCTION fnTrnCurrency_Fix
(@Value AS [FLOAT], @OldCurGUID [UNIQUEIDENTIFIER],
 @OldCurVal [FLOAT], @NewCurGUID [UNIQUEIDENTIFIER],
 @NewCurDate AS [DATETIME] = NULL)
	RETURNS [FLOAT]
AS BEGIN
	DECLARE
		@newCurVal [FLOAT],
		@Result [FLOAT]

	IF @OldCurGUID = @NewCurGUID
		SET @Result = @Value / (CASE @OldCurVal WHEN 0 THEN 1 ELSE @OldCurVal END)

	ELSE 
	BEGIN
		IF @NewCurDate IS NOT NULL
			SET @newCurVal = (SELECT TOP 1 [InCurrencyVal] FROM [Trnmh000] WHERE [CurrencyGUID] = @NewCurGUID AND [Date] <= @NewCurDate ORDER BY [Date] DESC)

		IF @newCurVal IS NULL
			SET @newCurVal = (SELECT [CurrencyVal] FROM [my000] WHERE [GUID] = @newCurGUID)
		SET @Result = @Value / (CASE @NewCurVal WHEN 0 THEN 1 ELSE @NewCurVal END)
	END
	RETURN @Result 
END
##############################################################################
CREATE FUNCTION FnTrnGetMapingEr()
RETURNS @Result TABLE (ErType INT, ExParentType INT, AvgEffect INT)
AS
BEGIN
 
	INSERT INTO @Result
	SELECT 
		507, 1, 1

	INSERT INTO @Result
	SELECT 
		517, 2, 0
	INSERT INTO @Result
	SELECT 
		520, 3, 0
		
	INSERT INTO @Result
	SELECT 
		521, 4, 0

	INSERT INTO @Result
	SELECT 
		518, 5, 1
		
	RETURN
END
##############################################################################
CREATE FUNCTION TrnFnGetCurrencyEntries
	(
		@Currency UNIQUEIDENTIFIER,
		@AccountGuid UNIQUEIDENTIFIER = 0x0,
		@CostGuid UNIQUEIDENTIFIER = 0x0,
		@FromDate DATETIME ='',
		@ToDate DATETIME = '2100'
	)
RETURNS @Result TABLE (Type INT, Debit FLOAT, Credit FLOAT, CurrencyVal FLOAT, AccountGuid UNIQUEIDENTIFIER,
		 CostGuid UNIQUEIDENTIFIER, [Date] DATETIME, EntryGuid UNIQUEIDENTIFIER, EntryNumber INT) 
AS
BEGIN
 
		INSERT INTO @Result
		SELECT 
			CASE en.debit -- тяга
				WHEN 0 THEN 0
				ELSE 1
			END
			AS Type,	
			en.debit / en.currencyval,
			en.credit / en.currencyval,
			en.currencyval,
			en.AccountGuid,
			en.CostGuid,
			en.[Date],
			en.parentguid,
			ce.number 
		FROM en000 AS en
		INNER JOIN ce000 AS ce ON ce.guid = en.parentguid
		WHERE
			en.currencyGuid = @Currency
		AND (@AccountGuid = 0x0 OR en.AccountGuid = @Accountguid)
		AND (@CostGuid = 0x0 OR en.costGuid = @CostGuid)
		AND en.[Date] between @FromDate AND @ToDate
	
		ORDER BY en.date, ce.number,en.number

		RETURN
END
########################################################################
CREATE FUNCTION FnTrnExCurrEntries
	( 
		@TypeGuid UNIQUEIDENTIFIER = 0x0, 
		@Currency UNIQUEIDENTIFIER = 0x0, 
		@FromDate DATETIME ='', 
		@ToDate DATETIME = '2100',
		@FiteringByCost BIT = 1,
		@UserGuid UNIQUEIDENTIFIER = 0X0
	) 
	RETURNS @Result TABLE (
			[CurrencyGuid] 	[UNIQUEIDENTIFIER],
			[CurrencyVal] 	[FLOAT],
			[CeGUID] 		[UNIQUEIDENTIFIER],    
			[enGUID] 		[UNIQUEIDENTIFIER], 
			[CeNumber] 		[INT],    
			[EnNumber] 		[INT],
			[Date] 			[DATETIME],    
			[AccGUID] 		[UNIQUEIDENTIFIER],    
			[CostGuid] 		[UNIQUEIDENTIFIER],
			[ExTypeGuid] 	[UNIQUEIDENTIFIER],			
			[ExParentType]	[INT],
			[AvgEffect]		[INT],
			[Debit] 		[FLOAT],
			[Credit] 		[FLOAT],
			[ParentGuid] 	[UNIQUEIDENTIFIER])
	AS 
	BEGIN 
		DECLARE @BasicCurrencyAccounts UNIQUEIDENTIFIER
		SELECT 	
			@BasicCurrencyAccounts = CAST(VALUE AS [UNIQUEIDENTIFIER])
		FROM OP000 WHERE NAME  = 'TrnCfg_CurrencyAccount'
		SET @BasicCurrencyAccounts = ISNULL(@BasicCurrencyAccounts, 0X0)
		
		DEclare @GroupCurrencyAccGuid UNIQUEIDENTIFIER = 0x0, 
				@CostGuid			  UNIQUEIDENTIFIER = 0x0,
				@isGenEntriesAccordingToUserAccounts BIT = 0
		SELECT @isGenEntriesAccordingToUserAccounts = CAST(value AS BIT) FROM op000 WHERE name = 'TrnCfg_Exchange_GenEntriesAccordingToUserAccounts'
		IF (ISNULL(@isGenEntriesAccordingToUserAccounts, 0) <> 0)
		BEGIN
			IF (ISNULL(@UserGuid, 0x0) <> 0x0)
			BEGIN
				SELECT 
					@GroupCurrencyAccGuid = GroupCurrencyAccGuid, 
					@CostGuid = CostGuid
				FROM 
					TrnUserConfig000
				where
					UserGuid = @UserGuid
			END
		END

		INSERT INTO @Result 
		SELECT  
			En.currencyguid, 
			En.currencyval, 
			Ce.Guid,
			En.Guid,
			Ce.Number,
			En.Number,
			En.[Date], 
			en.AccountGuid, 
			en.CostGuid,
			Type.Guid,
			ISNULL(FnMap.ExParentType, 0),	-- External Entry 
			ISNULL(FnMap.AvgEffect, 1), -- External Entry Effect Avg
			En.debit,-- / En.currencyval, 
			En.credit,-- / En.currencyval
			en.ParentGUID
		FROM en000 AS en 
		INNER JOIN ce000 AS ce ON ce.guid = en.parentguid 
		INNER JOIN TrnCurrencyAccount000 AS ac ON ac.AccountGuid = en.AccountGuid 
				AND ac.CurrencyGuid = en.CurrencyGuid 
		LEFT JOIN TrnExchangeTypes000 AS type ON type.GroupCurrencyAccGUID = ac.parentGUID
			 AND (type.costguid = en.costguid  OR
				type.GroupCurrencyAccGUID =  @BasicCurrencyAccounts OR 
				type.bIsManagerType = 1)
		LEFT JOIN Er000 AS er ON er.EntryGuid = ce.Guid	 				
		LEFT JOIN( --exchange execution entry
			select er.GUID erGuid, cancelEr.Guid erCancelGuid
			from 
				TrnExchange000 AS ex
				INNER JOIN er000 er ON er.EntryGUID = ex.EntryGuid
				Left JOIN er000 cancelEr ON cancelEr.EntryGUID = ex.CancelEntryGuid
		) AS ExEntry ON ExEntry.erGuid = er.Guid
		LEFT JOIN(-- exchange cancel entry
			select er.GUID erGuid, cancelEr.Guid erCancelGuid
			from 
				TrnExchange000 AS ex
				INNER JOIN er000 er ON er.EntryGUID = ex.EntryGuid
				Left JOIN er000 cancelEr ON cancelEr.EntryGUID = ex.CancelEntryGuid
		) AS ExCancel ON ExCancel.erCancelGuid = er.Guid
		LEFT JOIN FnTrnGetMapingEr() AS FnMap ON FnMap.ErType = er.ParentType 
		WHERE ce.[date] BETWEEN @FromDate AND @ToDate 
			AND (@TypeGuid = 0x0 OR @TypeGuid = type.guid) 
			AND (@Currency = 0x0 OR @Currency = ac.CurrencyGuid) 
			AND ISNULL(er.ParentType, 0) <> 518 -- EVALUATION	
			AND (Type.Guid != 0x00 OR ac.ParentGUID = @BasicCurrencyAccounts OR @isGenEntriesAccordingToUserAccounts = 1)			
			AND ISNULL(ExEntry.erCancelGuid, 0x0) = 0x0
			AND ISNULL(ExCancel.erCancelGuid, 0x0) = 0x0
			AND (ac.ParentGUID = @GroupCurrencyAccGuid OR @GroupCurrencyAccGuid = 0x0)
			AND (en.CostGUID = @CostGuid OR @CostGuid = 0x0)
RETURN 
END 
#######################################################################################
CREATE FUNCTION FnTrnGetUserBalance
	(
		@UserGuid UNIQUEIDENTIFIER = 0X0,
		@CurGuid  UNIQUEIDENTIFIER = 0X0,
		@CenterGuid	UNIQUEIDENTIFIER = 0X0,
		@StartDate datetime = '',
		@EndDate datetime = ''
	)
RETURNS TABLE 
AS
	RETURN(
		SELECT 
			my.GUID AS CurrencyGuid, 
			SUM(en.Debit / en.CurrencyVal) sumdebit, 
			SUM(en.Credit / en.CurrencyVal) SumCredit,
			SUM(en.Debit / en.CurrencyVal) - SUM(en.Credit / en.CurrencyVal) Balance
		FROM 
			en000 AS en
			INNER JOIN My000 as my ON my.GUID = en.CurrencyGUID
			INNER JOIN TrnCurrencyAccount000 AS ca ON ca.AccountGUID = en.AccountGUID AND ca.CurrencyGUID = en.CurrencyGuid 
			INNER JOIN TrnUserConfig000 AS uc ON uc.GroupCurrencyAccGUID = ca.ParentGUID
			INNER JOIN TrnCenter000 center ON center.Guid = uc.CenterGuid
		WHERE 
			(uc.UserGuid = @UserGuid OR @UserGuid = 0x0)
			AND (en.CurrencyGUID = @CurGuid OR @CurGuid = 0x0)
			AND (center.GUID = @CenterGuid OR @CenterGuid = 0x0)
			AND en.CostGUID = uc.CostGuid
			AND en.Date between @StartDate AND CASE @EndDate WHEN '' THEN '3000' ELSE @EndDate END
		GROUP BY 
			my.GUID
	)
#######################################################################################
CREATE FUNCTION FnTrnGetUserBalance2
	(
		@UserGuid	UNIQUEIDENTIFIER = 0X0,
		@CurGuid	UNIQUEIDENTIFIER = 0X0,
		@CenterGuid	UNIQUEIDENTIFIER = 0X0,
		@StartDate	DATETIME = '',
		@EndDate	DATETIME = '',
		@flag		INT		
	) RETURNS TABLE 
AS
-- 0: AllUsersBalance + CenterBalance, 1: CenterBalance, 2: All usersBalance, 3: normal userBalance
RETURN(
		SELECT 
			my.GUID AS CurrencyGuid, 
			SUM(en.Debit / en.CurrencyVal) sumdebit, 
			SUM(en.Credit / en.CurrencyVal) SumCredit,
			SUM(en.Debit / en.CurrencyVal) - SUM(en.Credit / en.CurrencyVal) Balance
		FROM 
			en000 AS en
			INNER JOIN My000 as my ON my.GUID = en.CurrencyGUID
			INNER JOIN TrnCurrencyAccount000 AS ca ON ca.AccountGUID = en.AccountGUID AND ca.CurrencyGUID = en.CurrencyGuid 
			LEFT JOIN TrnUserConfig000 AS uc ON uc.GroupCurrencyAccGUID = ca.ParentGUID
			LEFT JOIN TrnCenter000 centerBalance ON centerBalance.CurrencyAccountGuidCenter = ca.ParentGUID
			INNER JOIN TrnCenter000 center ON center.Guid = uc.CenterGuid OR center.Guid = centerBalance.Guid
		WHERE 
			(uc.UserGuid = @UserGuid OR @UserGuid = 0x0)
			AND (en.CurrencyGUID = @CurGuid OR @CurGuid = 0x0)
			AND (center.GUID = @CenterGuid OR @CenterGuid = 0x0)
			AND (center.Guid = uc.CenterGuid		OR @flag in (0, 1)) -- to show user balance without center balance
			And (center.Guid = centerBalance.GUID	OR @flag <> 1) -- to show only Center Balance
			AND (en.CostGUID = uc.CostGuid OR centerBalance.CurrencyAccountGuidCenter = ca.ParentGUID)
			AND en.Date between @StartDate AND CASE @EndDate WHEN '' THEN '3000' ELSE @EndDate END
		GROUP BY 
			my.GUID
	)
#######################################################################################
CREATE FUNCTION FnTrnGetExchangeTypesBalance
	(
		@UserGuid UNIQUEIDENTIFIER = 0X0,
		@CurGuid  UNIQUEIDENTIFIER = 0X0,
		@CenterGuid	UNIQUEIDENTIFIER = 0X0,
		@StartDate datetime = '',
		@EndDate datetime = ''
	)
RETURNS TABLE 
AS
	RETURN(
		SELECT 
			my.GUID AS CurrencyGuid, 
			SUM(en.Debit / en.CurrencyVal) sumdebit, 
			SUM(en.Credit / en.CurrencyVal) SumCredit,
			SUM(en.Debit / en.CurrencyVal) - SUM(en.Credit / en.CurrencyVal) Balance
		FROM 
			en000 AS en
			INNER JOIN My000 as my ON my.GUID = en.CurrencyGUID
			INNER JOIN TrnCurrencyAccount000 AS ca ON ca.AccountGUID = en.AccountGUID AND ca.CurrencyGUID = en.CurrencyGuid 
			INNER JOIN TrnExchangeTypes000 AS uc ON uc.GroupCurrencyAccGUID = ca.ParentGUID
		WHERE 
			(uc.GUID = @UserGuid OR @UserGuid = 0x0)
			AND (en.CurrencyGUID = @CurGuid OR @CurGuid = 0x0)
			AND en.CostGUID = uc.CostGuid
			AND en.Date between @StartDate AND CASE @EndDate WHEN '' THEN '3000' ELSE @EndDate END
		GROUP BY 
			my.GUID
	)
#######################################################################################
CREATE FUNCTION FnTrnGetCenterBalance
(
	@CenterGuid UNIQUEIDENTIFIER = 0X0,
	@CurGuid  UNIQUEIDENTIFIER = 0X0,
	@StartDate datetime = '',
	@EndDate datetime = ''
)
RETURNS TABLE 
AS
RETURN(
		SELECT 
			my.GUID AS CurrencyGuid, 
			SUM(en.Debit / en.CurrencyVal) sumdebit, 
			SUM(en.Credit / en.CurrencyVal) SumCredit,
			SUM(en.Debit / en.CurrencyVal) - SUM(en.Credit / en.CurrencyVal) Balance
		FROM 
			en000 AS en
			INNER JOIN My000 as my ON my.GUID = en.CurrencyGUID
			INNER JOIN TrnCurrencyAccount000 AS ca ON ca.AccountGUID = en.AccountGUID AND ca.CurrencyGUID = en.CurrencyGuid 
			INNER JOIN TrnCenter000 center ON center.Guid = @CenterGuid AND center.CurrencyAccountGuidCenter = ca.ParentGUID
		WHERE 
			    (en.CurrencyGUID = @CurGuid OR @CurGuid = 0x0)
			AND (center.GUID = @CenterGuid OR @CenterGuid = 0x0)
			AND en.Date between @StartDate AND CASE @EndDate WHEN '' THEN '3000' ELSE @EndDate END
		GROUP BY 
			my.GUID
	)
#######################################################################################
CREATE FUNCTION FnTrnGetTypeBalance
	(
		@TypeGuid UNIQUEIDENTIFIER ,
		@FromDate DATETIME ='',
		@ToDate DATETIME = '2100',
		@UserGuid UNIQUEIDENTIFIER = 0X0
	)
RETURNS TABLE 
AS
	RETURN(
		SELECT CurrencyGuid, SUM(Debit / CurrencyVal) sumdebit, SUM(Credit / CurrencyVal) AS SumCredit
			FROM FnTrnExCurrEntries(@TypeGuid,0x0, @FromDate, @ToDate, 1, 0x0) 
		GROUP BY CurrencyGuid
	)
#######################################################################################
CREATE FUNCTION FnTrnGetExchangeCurrencyBalance
	(
		@CurrencyGuid	UNIQUEIDENTIFIER,
		@FromDate		DATETIME ='',
		@ToDate			DATETIME = '2100'
	)
RETURNS TABLE 
AS
	RETURN(
		SELECT CurrencyGuid, SUM(Debit / CurrencyVal) sumdebit, SUM(Credit / CurrencyVal) AS SumCredit
			FROM FnTrnExCurrEntries(0x0,@CurrencyGuid, @FromDate, @ToDate, 1, 0x0) 
		GROUP BY CurrencyGuid
	)	
#######################################################################################
CREATE FUNCTION FnAllTrnCurrEntries
	( 
        @UserGuid UNIQUEIDENTIFIER ,
		@CostGuid UNIQUEIDENTIFIER = 0x0,
		@Currency UNIQUEIDENTIFIER = 0x0, 
		@FromDate DATETIME ='', 
		@ToDate DATETIME = '2100' 
	) 
	RETURNS @Result TABLE (
			[CurrencyGuid] 	[UNIQUEIDENTIFIER],
			[CurrencyVal] 	[FLOAT],
			[CeGUID] 		[UNIQUEIDENTIFIER],    
			[enGUID] 		[UNIQUEIDENTIFIER], 
			[CeNumber] 		[INT],    
			[EnNumber] 		[INT],
			[Date] 			[DATETIME],    
			[AccGUID] 		[UNIQUEIDENTIFIER],    
			[CostGuid] 		[UNIQUEIDENTIFIER],
			[ExTypeGuid] 	[UNIQUEIDENTIFIER],
			--[ParentGuid] 	[UNIQUEIDENTIFIER],
			[ExParentType]	[INT],
			[AvgEffect]		[INT],
			[Debit] 		[FLOAT],
			[Credit] 		[FLOAT])
	AS 
	BEGIN 
INSERT INTO @Result
             select   
                    En.currencyguid, 
			En.currencyval, 
			Ce.Guid,
			En.Guid,
			Ce.Number,
			En.Number,
			En.[Date], 
			en.AccountGuid, 
			en.CostGuid,
			US.ExchangeTypeGuid,
			ISNULL(FnMap.ExParentType, 0),	-- External Entry 
			ISNULL(FnMap.AvgEffect, 1), -- External Entry Effect Avg
			En.debit,-- / En.currencyval, 
			En.credit-- / En.currencyval
                    from en000 As en
                    INNER JOIN ce000 AS ce ON ce.guid = en.parentguid 
                    INNER JOIN TrnCurrencyAccount000 As ac ON ac.AccountGUID = en.AccountGuid
                    LEFT JOIN trnuserconfig000 AS US ON ac.ParentGuid = US.GroupCurrencyAccGUID
                                                     AND en.CostGUID = US.CostGUID
                    --INNER JOIN TRNUSERCASH000 AS ac ON ac.AccountGuid = en.AccountGuid  
                    --INNER JOIN ac000 AS account ON ac.AccountGuid = Account.guid                        
	            --LEFT JOIN TRNUSERCASHCOST000 AS TrnCost ON  TrnCost.costguid = en.costguid
                    --                                        AND ac.UserGuid = TrnCost.UserGuid
                    LEFT JOIN Er000 AS er ON er.EntryGuid = ce.Guid	 
		    LEFT JOIN FnTrnGetMapingEr() AS FnMap ON FnMap.ErType = er.ParentType	                           
                    WHERE ce.[date] BETWEEN @FromDate AND @ToDate 
		            AND (@CostGuid = 0x0 OR @CostGuid = US.CostGuid) 
		            AND (@Currency = 0x0 OR @Currency = ac.CurrencyGuid)
                    AND US.userGuid = @UserGuid
RETURN 
END
####################################################
CREATE FUNCTION FnTrnGetTypeCurrBalance
	(
		@TypeGuid UNIQUEIDENTIFIER ,
		@CurrencyGuid UNIQUEIDENTIFIER ,
		@FromDate DATETIME = '',
		@ToDate DATETIME = '2100',
		@AvoidEntry UNIQUEIDENTIFIER = 0x0,
		@UserGuid	UNIQUEIDENTIFIER = 0x0
	)
RETURNS FLOAT  
AS 
BEGIN 
	DECLARE @b FLOAT 
	SELECT 
		@b = SUM(Debit / CurrencyVal) - SUM(Credit / CurrencyVal)
	FROM FnTrnExCurrEntries(@TypeGuid, @CurrencyGuid, @FromDate, @ToDate, 1, @UserGuid)  
	WHERE 	@AvoidEntry <> CeGUID
	GROUP BY CurrencyGuid
	RETURN @b 		
END 
####################################################
CREATE FUNCTION FnGetTransferTypeCurrencyBalance
	(
        @UserGuid UNIQUEIDENTIFIER ,
        @CostGuid UNIQUEIDENTIFIER ,
		@CurrencyGuid UNIQUEIDENTIFIER ,
		@FromDate DATETIME = '',
		@ToDate DATETIME = '2100',
		@AvoidEntry UNIQUEIDENTIFIER = 0x0
	)
RETURNS FLOAT  
AS 
BEGIN 
	DECLARE @b FLOAT 
	SELECT 
		@b = SUM(Debit / CurrencyVal) - SUM(Credit / CurrencyVal)
	FROM FnAllTrnCurrEntries(@UserGuid, @CostGuid, @CurrencyGuid, @FromDate, @ToDate)  
	WHERE 	@AvoidEntry <> CeGUID
	GROUP BY CurrencyGuid
	RETURN @b 		
END
####################################################	
CREATE FUNCTION fnTrnGetAccountBalance
	( 
		@AccountGuid UNIQUEIDENTIFIER, 
		@CostGuid UNIQUEIDENTIFIER, 
		@CurrencyGuid UNIQUEIDENTIFIER, 
		@Date DATETIME, 
		@AvoidEntry UNIQUEIDENTIFIER = 0x0 
	) 
RETURNS FLOAT  
AS 
BEGIN 
	DECLARE @b FLOAT 
	SELECT @b = SUM(en.Debit / en.CurrencyVal) - SUM(en.Credit / en.CurrencyVal) 
	FROM En000 AS en 
	INNER JOIN ce000 AS ce ON ce.guid = en.parentguid  
	--INNER JOIN trnExchange000 AS ex ON ex.EntryGuid = ce.guid	 
	WHERE en.AccountGuid = @AccountGuid 
		AND en.CostGuid = @CostGuid 
		AND en.CurrencyGuid = @CurrencyGuid 
		--AND ex.[Date] <= @Date 
		AND en.[Date] <= @Date 
		AND en.ParentGuid <> @AvoidEntry 
	RETURN @b 
	 
END 
####################################################	
CREATE FUNCTION fnTrnBasicCurrencyAccount
	(
	)
	RETURNS @Result TABLE (
			ParentGUID		[UNIQUEIDENTIFIER],
			CurrencyGUID 	[UNIQUEIDENTIFIER],
			AccountGUID 	[UNIQUEIDENTIFIER]
			)	
AS 
BEGIN 

	DECLARE @BasicCurrencyAccounts UNIQUEIDENTIFIER
	SELECT 	
		@BasicCurrencyAccounts = CAST(VALUE AS [UNIQUEIDENTIFIER])
	FROM OP000 WHERE NAME  = 'TrnCfg_CurrencyAccount'
	
	SET @BasicCurrencyAccounts = ISNULL(@BasicCurrencyAccounts, 0X0)
	
	INSERT INTO @Result
	SELECT
		ac.ParentGUID,
		ac.CurrencyGUID,
		ac.AccountGUID
	FROM
		TrnGroupCurrencyAccount000 AS g
		INNER JOIN TrnCurrencyAccount000 AS ac ON ac.ParentGuid = g.GUID
	WHERE g.GUID = 	@BasicCurrencyAccounts
RETURN 
END 	
####################################################	
#END
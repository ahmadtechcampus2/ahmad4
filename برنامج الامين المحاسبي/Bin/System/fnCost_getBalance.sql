#########################################################
CREATE FUNCTION fnCost_getBalance( 
		@accGuid [UNIQUEIDENTIFIER], 
		@CostGuid [UNIQUEIDENTIFIER], 
		@curGuid [UNIQUEIDENTIFIER] = 0x0, 
		@StartDate [DATETIME] = '1/1/1980', 
		@EndDate [DATETIME] = NULL,
		@CustGuid [UNIQUEIDENTIFIER] = 0x0) 
	RETURNS [FLOAT] 
AS BEGIN 
/* 
this function: 
	- returns the balance of a given @accGuid in the given @curGuid by accumulating posted entries 
	- ignores @curGuid when 0x0. 
	- deals with core tables directly, ignoring branches and itemSecurity features. 
*/ 
	DECLARE @result [FLOAT] 
	IF ISNULL(@curGuid, 0x0) = 0x0 
	BEGIN 
		IF @EndDate IS NULL 
			SET @result = ( 
					SELECT  
						SUM( [e].[debit])- SUM( [e].[credit])
					FROM 
						[en000] [e] 
						INNER JOIN [ce000] [c] ON [e].[parentGuid] = [c].[guid] 
						INNER JOIN [dbo].[fnGetAccountsList]( @accGuid, 0) [f] ON [e].[accountGuid] = [f].[guid] 
						INNER JOIN [co000] [co] ON [e].[CostGUID] = [co].[Guid]
					WHERE 
						([c].[isPosted] <> 0) AND ([e].[Date] >= @StartDate) AND ([co].[Guid] = @CostGuid)
						AND (ISNULL(@CustGuid, 0x0) = 0x0 OR [e].[CustomerGUID] = @CustGuid)
						)
		ELSE
				SET @result = ( 
						SELECT  
							SUM( [e].[debit])- SUM( [e].[credit])
						FROM 
							[en000] [e] 
							INNER JOIN [ce000] [c] ON [e].[parentGuid] = [c].[guid] 
							INNER JOIN [dbo].[fnGetAccountsList]( @accGuid, 0) [f] ON [e].[accountGuid] = [f].[guid] 
							INNER JOIN [co000] [co] ON [e].[CostGUID] = [co].[Guid]
						WHERE 
							([c].[isPosted] <> 0) AND ([e].[Date]  BETWEEN @StartDate AND @EndDate) AND ([co].[Guid] = @CostGuid)
							AND (ISNULL(@CustGuid, 0x0) = 0x0 OR [e].[CustomerGUID] = @CustGuid)
							)
	END 
	else 
	BEGIN 
		IF @EndDate IS NULL 
			SET @result = ( 
					SELECT 
						SUM( [dbo].[fnCurrency_fix]([e].[debit], [e].[currencyGuid], [e].[currencyVal], @curGUID, [e].[date]))
						- 
						SUM( [dbo].[fnCurrency_fix]([e].[credit], [e].[currencyGuid], [e].[currencyVal], @curGUID, [e].[date]))
					FROM 
						[en000] [e] 
						INNER JOIN [ce000] [c] ON [e].[parentGuid] = [c].[guid] 
						INNER JOIN [fnGetAccountsList](@accGuid, 0) [f] ON [e].[accountGuid] = [f].[guid] 
						INNER JOIN [co000] [co] ON [e].[CostGUID] = [co].[Guid]
					WHERE 
						([c].[isPosted] <> 0)  AND ([e].[Date] >= @StartDate) AND ([co].[Guid] = @CostGuid)
						AND (ISNULL(@CustGuid, 0x0) = 0x0 OR [e].[CustomerGUID] = @CustGuid)
						)
		ELSE 
			SET @result = ( 
					SELECT 
						SUM( [dbo].[fnCurrency_fix]([e].[debit], [e].[currencyGuid], [e].[currencyVal], @curGUID, [e].[date]))
						- 
						SUM( [dbo].[fnCurrency_fix]([e].[credit], [e].[currencyGuid], [e].[currencyVal], @curGUID, [e].[date]))
					FROM 
						[en000] [e] 
						INNER JOIN [ce000] [c] ON [e].[parentGuid] = [c].[guid] 
						INNER JOIN [fnGetAccountsList](@accGuid, 0) [f] ON [e].[accountGuid] = [f].[guid] 
						INNER JOIN [co000] [co] ON [e].[CostGUID] = [co].[Guid]
					WHERE 
						([c].[isPosted] <> 0) AND ([e].[Date]  BETWEEN @StartDate AND @EndDate) AND ([co].[Guid] = @CostGuid)
						AND (ISNULL(@CustGuid, 0x0) = 0x0 OR [e].[CustomerGUID] = @CustGuid)
						)
	END 
	RETURN ISNULL(@result, 0.0) 
END 
#########################################################
#END

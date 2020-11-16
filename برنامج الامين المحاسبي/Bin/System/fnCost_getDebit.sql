#########################################################
CREATE FUNCTION fnCost_getDebit(  
		@accGuid [UNIQUEIDENTIFIER] = 0x0,  
		@CostGuid [UNIQUEIDENTIFIER],  
		@curGuid [UNIQUEIDENTIFIER] = 0x0)  
	RETURNS [FLOAT]  
AS BEGIN  
/*  
this function:  
	- returns sum Debit of a given @accGuid in the given @curGuid by accumulating posted entries  
	- ignores @curGuid when 0x0.  
	- deals with core tables directly, ignoring branches and itemSecurity features.  
*/  
	DECLARE @result [FLOAT]  
	IF ISNULL(@accGuid, 0x0) = 0x0  
		SET @result = (  
				SELECT  
					CASE WHEN ISNULL(@curGuid, 0x0) = 0x0 THEN 
						SUM( [e].[Debit]) 
					ELSE
						SUM( [dbo].[fnCurrency_fix]([e].[Debit], [e].[currencyGuid], [e].[currencyVal], @curGUID, [e].[date])) 
					END
				FROM  
					[en000] [e]  
					INNER JOIN [ce000] [c] ON [e].[parentGuid] = [c].[guid]
					INNER JOIN [co000] [co] ON [e].[CostGUID] = [co].[Guid] 
				WHERE  
					[c].[isPosted] <> 0 AND ([co].[Guid] = @CostGuid))  
	ELSE  
		SET @result = (  
				SELECT  
					CASE WHEN ISNULL(@curGuid, 0x0) = 0x0 THEN 
						SUM( [e].[Debit]) 
					ELSE
						SUM( [dbo].[fnCurrency_fix]([e].[Debit], [e].[currencyGuid], [e].[currencyVal], @curGUID, [e].[date])) 
					END
				FROM  
					[en000] [e]  
					INNER JOIN [ce000] [c] ON [e].[parentGuid] = [c].[guid]  
					INNER JOIN [fnGetAccountsList](@accGuid, 0) [f] ON [e].[accountGuid] = [f].[guid]  
					INNER JOIN [co000] [co] ON [e].[CostGUID] = [co].[Guid] 
				WHERE  
					[c].[isPosted] <> 0 AND ([co].[Guid] = @CostGuid))  
		
	RETURN ISNULL(@result, 0.0)  
END  

--[dbo].[prcConnections_Add2] '„œÌ—'
--SELECT [dbo].[fnCost_getDebit] (DEFAULT,'DF85F639-2825-446A-9A95-255515823A88',DEFAULT)
#########################################################
#END

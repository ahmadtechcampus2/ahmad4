#########################################################
CREATE FUNCTION fnAccount_Customer_getCredit(
		@accGuid [uniqueidentifier],
		@curGuid [uniqueidentifier] = 0x0,
		@CustGUID[uniqueidentifier] = 0x0)
	RETURNS [float]
AS BEGIN
/*
this function:
	- returns sum credit of a given @accGuid in the given @curGuid by accumulating posted entries
	- ignores @curGuid when 0x0.
	- deals with core tables directly, ignoring branches and itemSecurity features.
*/

	DECLARE @result [float]


	IF ISNULL(@curGuid, 0x0) = 0x0
		set @result = (
				SELECT sum([e].[credit]) 
				FROM [en000] [e] INNER JOIN [vbce] [c] ON [e].[parentGuid] = [c].[guid] INNER JOIN [fnGetAccountsList](@accGuid, 0) [f] ON [e].[accountGuid] = [f].[guid] LEFT JOIN [vwcu] [cu] ON [e].[CustomerGUID] = [cu].[cuGUID]
				WHERE [c].[isPosted] <> 0 AND (ISNULL(@CustGUID, 0x0) = 0x0 OR cu.cuGUID = @CustGUID ))

	ELSE
		SET @result = (
				SELECT sum([dbo].[fnCurrency_fix]([e].[credit], [e].[currencyGuid], [e].[currencyVal], @curGUID, [e].[date]))
				FROM [en000] [e] inner join [vbce] [c] ON [e].[parentGuid] = [c].[guid] INNER JOIN [fnGetAccountsList](@accGuid, 0) [f] on [e].[accountGuid] = [f].[guid] LEFT JOIN [vwcu] [cu] on [e].[CustomerGUID] = [cu].[cuGUID]
				WHERE [c].[isPosted] <> 0 AND (ISNULL(@CustGUID, 0x0) = 0x0 OR cu.cuGUID = @CustGUID ))


	RETURN ISNULL(@result, 0.0)
END

#########################################################
CREATE function fnAccount_getCredit(
			@accGuid [uniqueidentifier],
			@curGuid [uniqueidentifier] = 0x0)
	RETURNS [float]
AS BEGIN 
return dbo.fnAccount_Customer_getCredit(
		@accGuid ,
		@curGuid ,
        default
		 )
END
#########################################################
#end 
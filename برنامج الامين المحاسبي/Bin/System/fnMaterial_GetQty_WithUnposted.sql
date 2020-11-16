###############################################################################
CREATE FUNCTION fnMaterial_getQty_withUnPosted(
		@matGuid [uniqueidentifier])
	RETURNS [float]
AS BEGIN
/*
this function:
	- returns the total quantity of a given @matGuid by accumulating from bill
	  the only deffirence between this function and fnMaterial_getQty is that this function
	  deals accumolates unposted bills, but ignores bu with bNoPost
	- deals with core tables directly, ignoring branches and itemSecurity features.
*/

	DECLARE @result [float]

	SET @result = (	
			SELECT sum([qty] * (CASE [bIsInput] WHEN 1 THEN 1 ELSE -1 END))
			FROM [bi000] [bi] INNER JOIN [bu000] [bu] ON [bi].[parentGuid] = [bu].[guid] INNER JOIN [bt000] [bt] ON [bu].[typeGuid] = [bt].[guid]
			WHERE [bi].[matGuid] = @matGuid AND [bt].[bNoPost] = 0)

	RETURN ISNULL(@result,0.0)
END
###############################################################################
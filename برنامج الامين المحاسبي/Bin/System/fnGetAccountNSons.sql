###########################################################################
CREATE FUNCTION fnGetAccountNSons(@AccGUID [UNIQUEIDENTIFIER])
	RETURNS [INT]
AS BEGIN
	RETURN (SELECT COUNT(*) FROM [ac000] AS [ac] WHERE [ac].[ParentGUID] = @AccGUID)
					+ (SELECT COUNT(*) FROM [ac000] AS [ac] WHERE [ac].[FinalGUID] = @AccGUID)
					--+ (SELECT COUNT(*) FROM [ci000] AS [ci] WHERE [ci].[ParentGUID] = @AccGUID)
END

###########################################################################
#END
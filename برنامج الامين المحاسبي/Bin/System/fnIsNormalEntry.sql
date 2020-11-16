########################################################################
CREATE FUNCTION fnIsNormalEntry( @SrcGuid [UNIQUEIDENTIFIER]) 
	RETURNS [INT]
AS BEGIN
	DECLARE @result [INT]
		IF @SrcGuid IS NULL OR EXISTS( SELECT * FROM [RepSrcs] WHERE [IdTbl] = @SrcGuid AND [IdType] = 0x0)
			SET @result = 1
		ELSE
			SET @result = 0
	RETURN @result
END
########################################################################
#END
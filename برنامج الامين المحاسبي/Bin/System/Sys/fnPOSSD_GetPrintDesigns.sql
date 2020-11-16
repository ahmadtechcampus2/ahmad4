#################################################################
CREATE FUNCTION fnPOSSD_GetPrintDesigns
	(@PrintDesignType AS INT)
	RETURNS TABLE
AS
	RETURN SELECT
	CAST(Number AS NVARCHAR(250))    AS Code, 
				[GUID]    AS [GUID],
				Name      AS Name,
				LatinName AS LatinName
		   FROM 
				POSSDPrintDesign000 
			WHERE 
				[Type] = @PrintDesignType 
#################################################################
#END 
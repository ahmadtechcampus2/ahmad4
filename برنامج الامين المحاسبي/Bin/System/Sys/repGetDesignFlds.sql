##############################################
CREATE PROC repGetDesignFlds @DesignGuid UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON
	SELECT df.* FROM df000 AS df WHERE df.ParentGUID = @DesignGuid
	------------------------------------
	SELECT fa.*
	FROM 
		df000 AS df INNER JOIN fa000 AS fa
		ON df.GUID = fa.ParentGUID
	WHERE 
		df.ParentGUID = @DesignGuid
	------------------------------------
	SELECT fn.*, df.Guid AS dfGuid
	FROM 
		fn000 AS fn INNER JOIN df000 AS df 
		ON fn.GUID = df.FontGUID
	WHERE 
		df.ParentGUID = @DesignGuid
##############################################
#END
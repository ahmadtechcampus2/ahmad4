################################################################
CREATE PROCEDURE repOrderDocuments(
	@OrderGuid		UNIQUEIDENTIFIER = 0x0)
AS
	SET NOCOUNT ON 

	SELECT 
		docach.*, 
		ordoc.Name, 
		ordoc.LatinName
	FROM 
		docach000 docach
		INNER  JOIN ordoc000 ordoc ON docach.DocGuid = ordoc.Guid
		INNER JOIN ordocvs000 ordocvs ON ordoc.Guid = ordocvs.DocGuid AND docach.TypeGuid = ordocvs.TypeGuid
	WHERE 
		docach.OrderGuid = @OrderGuid
	ORDER BY 
		DocGuid
################################################################
#END		

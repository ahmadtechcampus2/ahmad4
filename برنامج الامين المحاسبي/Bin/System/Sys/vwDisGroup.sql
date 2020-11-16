##################################################################################
Create view vwDisGroup
AS

	SELECT 
		Gr.Number,
		Gr.Guid,	
		Gr.Code,
		Gr.Name,
		Gr.LatinName,
		P.Code+'-'+P.Name AS Parent
	FROM DisGroup000 Gr 
	LEFT JOIN DisGroup000 P On Gr.ParentGuid = P.Guid
##################################################################################
#END


####################################################
CREATE VIEW vwPgGr
AS 
	SELECT  
		[pgType],		
		[pgNumber],  
		[pgGUID],  
		[pgGrpName],  
		[pgPictureGUID],
		[pgComputerName],
		[grGUID],		
		[grCode],		 
		[grName],		 
		[grLatinName]
	FROM 
		[vwPg] INNER JOIN [vwGr]
		ON [pgGrpGUID] = [grGUID]


####################################################
#END
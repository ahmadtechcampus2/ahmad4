#########################################################
CREATE VIEW vwNiMt
AS  
	SELECT    
		[niNumber],  
		[niGUID],  
		[niParent],  
		[niMatGUID],  
		[niQty],  
		[niUnity],
		[niNotes],
		[mtName],
		[mtLatinName],
		[mtCode]
	FROM 
		[vwNi] INNER JOIN [vwMt]
		ON [niMatGUID] = [mtGUID]

#########################################################
#END
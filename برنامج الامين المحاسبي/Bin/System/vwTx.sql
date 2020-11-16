#########################################################
CREATE VIEW vwTx
AS    
	SELECT	
		[Number],
		[GUID],
		[Type],
		[GroupGUID],
		[Val1],
		[Val2],
		[Val3],
		[Val4],
		[Val5]
	FROM
		[tx000]
		
#########################################################
#END
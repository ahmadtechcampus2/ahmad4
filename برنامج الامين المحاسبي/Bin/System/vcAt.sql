##########################################################
CREATE VIEW vcAt
AS 
	SELECT  
		[bt].* 
	FROM 
		[bt000][bt] inner join [vwBt][v] on [bt].[Guid] = [v].[btGuid]
	WHERE  
		[Type] IN (7,9) -- 7 the old OUT_BILL TYPE of ASSEMBLE_BILL TYPE
						-- 9 the new OUT_BILL TYPE of ASSEMBLE_BILL TYPE
##########################################################
#END
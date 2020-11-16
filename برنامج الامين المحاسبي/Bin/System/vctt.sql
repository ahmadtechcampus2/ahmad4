#############################################
CREATE VIEW vctt
AS
	SELECT 
		[bt].*
	FROM
		[bt000][bt] inner join [vwBt][v] on [bt].[Guid] = [v].[btGuid]
	WHERE 
		[Type] = 3 AND SortNum <> 0
##############################################
#END
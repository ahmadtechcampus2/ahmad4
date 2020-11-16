###################################
CREATE VIEW vwOch
AS
	SELECT
		[GUID] AS [ochGUID],
		[Type] AS [ochType],
		[CheckNumber] AS [ochCheckNumber],
		[Value] AS [ochValue],
		[ParentGUID] AS [ochParentGUID],
		[Notes] AS [ochNotes]
	FROM  
		[och000]
###################################
#END
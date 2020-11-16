#########################################################
CREATE VIEW vwOp
AS
	SELECT 
		[GUID]		AS [opGUID],
		[NAME]		AS [opName],
		[Value] 	AS [opValue],
		[PrevValue] AS [opPrevValue],
		[UserGUID] 	AS [OpUserGUID],
		[OwnerGUID]	AS [opOwnerGUID],
		[Computer] 	AS [opComputer],
		[Time]		AS [opTime],
		[Type]		AS [opType]
	FROM 
		[op000]

#########################################################
#END
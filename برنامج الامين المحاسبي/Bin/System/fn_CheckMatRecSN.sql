###########################################################################
CREATE FUNCTION fn_CheckMatRecSN(@MaterialGuid UNIQUEIDENTIFIER, @BillGuid UNIQUEIDENTIFIER)
RETURNS TABLE
RETURN (
	SELECT [sn].[SN] 
	,SUM([buDirection]) as SumBuDirection
	FROM [vcSNs] [sn]
	 INNER JOIN vwbu B ON b.buGuid = sn.buGuid  
	 WHERE sn.[MatGuid] = @MaterialGuid
	 AND b.buGUID <> @BillGuid 
	 GROUP BY [sn].[SN], sn.MatGuid
)

###########################################################################
#END
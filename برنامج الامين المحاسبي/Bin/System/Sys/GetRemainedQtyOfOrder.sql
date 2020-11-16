#########################################################################
CREATE PROCEDURE GetRemainedQtyOfOrder
	@BuGuid  as UNIQUEIDENTIFIER,
	@Rate as float = 0
AS
	SET NOCOUNT ON

	SELECT bi.ClassPtr AS Class, bi.MatGuid AS MatGuid, SUM(bi.Qty) AS QTY
	INTO #TempQty1
	FROM 
		bi000 bi 
		INNER JOIN bu000 bu ON bu.Guid= bi.ParentGuid		       
	WHERE bu.Guid = @BuGuid
	GROUP BY bi.ClassPtr, bi.MatGuid

	SELECT bi.ClassPtr AS Class, bi.MatGuid, SUM(bi.Qty) AS QTY
	INTO #TempQty2
	FROM 
		bi000 bi 
		INNER join bu000 bu ON bu.Guid= bi.ParentGuid
		INNER join ORREL000 REL ON REL.ORGuid = bu.Guid
		INNER JOIN OrAddInfo000 AddInfo ON bu.Guid = AddInfo.ParentGuid
	WHERE REL.ParentGuid = @BuGuid 
	AND ISNULL(AddInfo.Add1 , -1) <> '1' 
	GROUP BY bi.ClassPtr, bi.MatGuid

	IF (@Rate > 0)
	BEGIN
		SELECT 
			TQ1.MatGuid as MatGuid, 
			TQ1.Class AS Class, 
			((TQ1.QTY - TQ2.QTY) * @Rate / 100) AS QTY 
		FROM 
			#TempQty1 TQ1 
			INNER JOIN #TempQty2 TQ2 ON TQ1.Class = TQ2.Class AND TQ1.MatGuid = TQ2.MatGuid

	END ELSE BEGIN
		SELECT 
			TQ1.MatGuid AS MatGuid, 
			TQ1.Class AS Class, 
			(TQ1.QTY - TQ2.QTY) AS QTY 
		FROM 
			#TempQty1 
			TQ1 INNER JOIN #TempQty2 TQ2 ON TQ1.Class = TQ2.Class AND TQ1.MatGuid = TQ2.MatGuid
	END
#########################################################################
#END
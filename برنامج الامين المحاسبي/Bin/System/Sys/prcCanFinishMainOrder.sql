#########################################################################
CREATE PROCEDURE prcCanFinishMainOrder
	-- @OrderGuid: Guid of the main order
	@OrderGuid UNIQUEIDENTIFIER = 0x0
AS
BEGIN
	SET NOCOUNT ON;

	SELECT
		(CASE WHEN COUNT(CanFinishItem) > SUM(CanFinishItem) THEN 0 ELSE 1 END) AS Result
	FROM
		(
		SELECT
			biMatPtr AS matGUID
			,SUM(ParentQty) AS ParentQty
			,SUM(ChildrenQty) AS ChildrenQty
			,(CASE WHEN SUM(ChildrenQty) >= SUM(ParentQty) THEN 1 ELSE 0 END) AS CanFinishItem
		FROM 
			(SELECT 
				buGuid
				,biGuid
				,biMatPtr
				,biQty AS ParentQty
				,0 AS ChildrenQty
			FROM 
				vwExtended_bi vw
			WHERE
				buGuid = @OrderGuid 

			UNION ALL
			SELECT
				buGuid
				,biGuid
				,biMatPtr
				,0 AS ParentQty
				,biQty AS ChildrenQty
			FROM
				vwExtended_bi vw
			WHERE
				buGUID IN (
					SELECT
						ORGuid
					FROM
						ORREL000
					WHERE
						ParentGuid = @OrderGuid
				)	
			) DD
		GROUP BY
			biMatPtr
		) GG
	
	--Result is 1 when the sum of materials quantities in children orders is greater or equal to the materials quantities of main order.
END
#########################################################################
#END
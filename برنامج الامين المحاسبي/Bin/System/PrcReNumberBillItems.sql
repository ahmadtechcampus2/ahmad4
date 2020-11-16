################################################################################
CREATE PROCEDURE PrcReNumberBillItems 
AS  
	SET NOCOUNT ON
	EXEC prcDisableTriggers 'BI000'

	UPDATE bi
		SET bi.Number = RenumberdItem.Renumberd
	FROM bi000 AS bi
	CROSS APPLY (
				SELECT 
					ROW_NUMBER() OVER (ORDER BY Number ASC) AS Renumberd,
					GUID,
					ParentGUID
				FROM bi000 
				WHERE ParentGUID = bi.ParentGUID
				) AS RenumberdItem 
	WHERE RenumberdItem.GUID = bi.GUID AND bi.Number <> RenumberdItem.Renumberd

	EXEC prcEnableTriggers 'BI000'

################################################################################
#END

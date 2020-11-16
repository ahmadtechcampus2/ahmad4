##########################################################################
CREATE PROC checkAssetDelete
          @TransferHeaderGuid [UNIQUEIDENTIFIER] = 0x0
AS

SELECT 
	* 
FROM 
	assTransferHeader000 ath 
	INNER JOIN 
 	assTransferDetails000 atd
	ON ath.Guid = atd.ParentGuid 
	INNER JOIN 
	ad000 ad 
	ON ad.Guid = atd.adGuid
	
WHERE  
	ath.Guid = @TransferHeaderGuid
	AND
	(
		EXISTS(
			SELECT 
				* 
			FROM 
				assTransferHeader000 ath2 
				INNER JOIN 
			 	assTransferDetails000 atd2
				ON ath2.Guid = atd2.ParentGuid 
				INNER JOIN 
				ad000 ad2 
				ON ad2.Guid = atd2.adGuid
			WHERE
			ad2.SN = ad.SN  AND ath2.BranchSource = ath.BranchDestination  AND ath.DateIn <= ath2.DateOut
		)
	)
#############################################################################3
#END
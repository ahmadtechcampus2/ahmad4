######################################################################################
CREATE PROC repGetAxAsset @AssGUID UNIQUEIDENTIFIER
AS
	SELECT 
		AdTbl.AdGUID AS AdGUID,
		ISNULL( AxAdded.axVal, 0) AS AddedVal,
		ISNULL( AxDeduct.axVal, 0) AS DeductVal,
		ISNULL( AxMaintain.axVal, 0) AS MaintenVal,
		ISNULL( DP.ddDeprecationVal, 0) AS DeprecationVal
	FROM 
		vwAd AS AdTbl
		LEFT JOIN ( SELECT axAssDetailGUID AS AdGUID, SUM( axValue) AS axVal
				FROM     
					vwAx    
				where 
					axType = 0 
				GROUP BY     
					axAssDetailGUID ) AS AxAdded 
			ON AxAdded.AdGUID = AdTbl.AdGUID

		LEFT JOIN ( 	SELECT axAssDetailGUID AS AdGUID, SUM( axValue) AS axVal
				FROM     
					vwAx    
				where 
					axType = 1
				GROUP BY     
					axAssDetailGUID) AS AxDeduct
			ON AxDeduct.AdGUID = AdTbl.AdGUID

		LEFT JOIN ( 	SELECT axAssDetailGUID AS AdGUID, SUM( axValue) AS axVal
				FROM     
					vwAx    
				where 
					axType = 2
				GROUP BY     
					axAssDetailGUID ) AS AxMaintain
			ON AxMaintain.AdGUID = AdTbl.AdGUID

		LEFT JOIN (    
			SELECT     
				ddADGUID AS AdGUID,    
				SUM( ddValue) AS ddDeprecationVal    
			FROM     
				vwDD    
			GROUP BY     
				ddADGUID
			) AS DP ON DP.AdGUID = AdTbl.AdGUID   
	WHERE
		AdTbl.adGUID = @AssGUID
#########################################################################################
#END


#########################################################
CREATE FUNCTION fnFindMaterialByBarcode
	(
		@SerchType		NVARCHAR(250) ='', -- SM_STARTWITH = 0, SM_CONTAIN = 1, SM_EXACTLY = 2
		@MatBarcode		NVARCHAR(250) ='', 
		@MatBarcode2	NVARCHAR(250) ='', 
		@MatBarcode3	NVARCHAR(250) =''
	) 

RETURNS @Result TABLE
	(
		MatGUID			UNIQUEIDENTIFIER,
		MtCount			INT
	) 

BEGIN
	INSERT INTO @Result 
	SELECT DISTINCT
			mt.[MatGuid]			AS MatGUID,
			COUNT(mt.[MatGuid]) 	AS MtCount
	
	FROM vwMatExBarcode as mt
	LEFT JOIN vwMatExBarcode AS mt2 ON mt2.[MatGuid] = mt.[MatGuid]
	LEFT JOIN vwMatExBarcode AS mt3 ON mt3.[MatGuid] = mt.[MatGuid]
	WHERE
		((( mt.[MatBarcode] LIKE @MatBarcode+'%' ) 
		AND ( mt2.[MatBarcode2] LIKE @MatBarcode2+ '%' )
		AND ( mt3.[MatBarcode3] LIKE @MatBarcode3+ '%' )) 
		AND @SerchType='0' )
	
		OR
		
		((( mt.[MatBarcode] LIKE'%'+ @MatBarcode +'%' )
		AND ( mt2.[MatBarcode2] LIKE '%'+@MatBarcode2+ '%' )
		AND ( mt3.[MatBarcode3] LIKE'%' +@MatBarcode3+'%' )) 
		AND @SerchType='1' )
		
		OR
		
		((( mt.[MatBarcode] LIKE @MatBarcode ) 
		AND ( mt2.[MatBarcode2] LIKE @MatBarcode2 ) 
		AND ( mt3.[MatBarcode3] LIKE @MatBarcode3 )) 
		AND @SerchType='2' )
		
	GROUP BY (mt.[MatGuid])
 
 	RETURN
END
#########################################################
#END
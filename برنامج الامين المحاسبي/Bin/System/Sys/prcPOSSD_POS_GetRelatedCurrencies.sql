#################################################################
CREATE PROCEDURE prcPOSSDGetRelatedCurrencies
-- Param -------------------------------   
	   @PosGuid UNIQUEIDENTIFIER
-----------------------------------------   
AS
BEGIN
    SET NOCOUNT ON
------------------------------------------------------------------------
 SELECT my.GUID CurGUID,
	    MY.Code, Name,Number,
		CASE WHEN mh.CurrencyVal IS NOT NULL THEN mh.CurrencyVal ELSE my.CurrencyVal END CurrencyVal,
		PartName,
		LatinName,
		LatinPartName,
		PictureGUID, 
		RC.GUID,
		RC.POSGuid,
		RC.Used,
		RC.CentralBoxAccGUID,
		RC.FloatCachAccGUID 
 FROM my000 my 
      LEFT JOIN mh000 mh ON my.GUID = mh.CurrencyGUID 
      LEFT JOIN POSSDRelatedCurrencies000 RC ON my.GUID = RC.CurGUID AND POSGuid = @PosGuid
 WHERE (Used = 1 OR my.CurrencyVal = 1) 
	    AND (EXISTS (SELECT 1 FROM mh000 WHERE CurrencyGUID = my.GUID) 
		      AND (mh.Date = (SELECT MAX ([Date]) FROM mh000 mhe GROUP BY CurrencyGUID HAVING CurrencyGUID = mh.CurrencyGUID )) 
			  OR (NOT EXISTS (SELECT 1 FROM mh000 WHERE CurrencyGUID = my.GUID)))
 ORDER BY Number
END
#################################################################
#END 
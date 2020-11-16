#########################################################
CREATE FUNCTION fnGetStoresList(@StoreGUID [UNIQUEIDENTIFIER])
	RETURNS @Result TABLE ([GUID] [UNIQUEIDENTIFIER])
AS BEGIN
		INSERT INTO @Result SELECT [GUID] FROM [fnGetStoresListByLevel](@storeGuid, 0)
	RETURN
END 
#########################################################
#END
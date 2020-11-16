##################################################################
CREATE FUNCTION fnPOS_LoyaltyCards_CheckSystem (@LoyaltyCardTypeGUID UNIQUEIDENTIFIER)
	RETURNS @Result TABLE (IsRelatedToCentralizedDB BIT, CentralizedDBName NVARCHAR(500), ErrorNumber INT) 	
AS BEGIN 

	INSERT INTO @Result (IsRelatedToCentralizedDB, CentralizedDBName, ErrorNumber) SELECT 0, '', 0

	IF ISNULL(@LoyaltyCardTypeGUID, 0x0) != 0x0 AND EXISTS (SELECT * FROM POSLoyaltyCardType000 WHERE GUID = @LoyaltyCardTypeGUID AND IsInactive = 1)
	BEGIN 
		UPDATE @Result SET ErrorNumber = 1 -- type is inactive 
		RETURN
	END 

	IF EXISTS (SELECT * FROM op000 WHERE [Name] = 'AmnCfg_LoyaltyCards_RelatedToCentralizedDB' AND [Value] = '1')
		UPDATE @Result SET IsRelatedToCentralizedDB = 1
	
	IF EXISTS(SELECT * FROM @Result WHERE IsRelatedToCentralizedDB = 1)
	BEGIN 
		DECLARE @CentralizedDBName NVARCHAR(500)

		SELECT TOP 1 @CentralizedDBName = [Value] FROM op000 WHERE [Name] = 'AmnCfg_LoyaltyCards_CentralizedDB'
		
		IF ISNULL (@CentralizedDBName, '') = ''
		BEGIN
			UPDATE @Result SET ErrorNumber = 10	-- dbname not set 
			RETURN
		END 

		IF DB_ID (@CentralizedDBName) IS NULL
		BEGIN
			UPDATE @Result SET ErrorNumber = 11	-- db not exists
			RETURN
		END 

		IF EXISTS (
			SELECT 1 
			FROM sys.databases 
			WHERE 
				[Name] = @CentralizedDBName
				AND 
				[State] != 0 )
		BEGIN
			UPDATE @Result SET ErrorNumber = 12	-- db state is not online 
			RETURN
		END 

		UPDATE @Result SET CentralizedDBName = '[' + @CentralizedDBName + '].dbo.'
	END
	RETURN
END 
##################################################################
#END

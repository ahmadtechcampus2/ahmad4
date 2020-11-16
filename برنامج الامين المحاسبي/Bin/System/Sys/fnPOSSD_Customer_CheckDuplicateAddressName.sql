#############################################
CREATE FUNCTION fnPOSSD_Customer_CheckDuplicateAddressName
-- Param ----------------------------------------------------------
	  ( @CustomerAddressGuid UNIQUEIDENTIFIER, @CustomerGUID UNIQUEIDENTIFIER, @CustomerAddressName NVARCHAR(250), @CustomerAddressLatinName NVARCHAR(250))
-- Return ----------------------------------------------------------
RETURNS INT
--------------------------------------------------------------------
AS 
BEGIN 
	DECLARE @CustomerAddressNameIsUsed INT = 0
	DECLARE @Name NVARCHAR(250) = ''
	DECLARE @LatinName	NVARCHAR(250) = '' 
	
	SELECT @Name = Name ,
		   @LatinName = LatinName 
	FROM CustAddress000 
	WHERE
		GUID <> @CustomerAddressGuid AND CustomerGUID = @CustomerGUID 
		AND ( 
		Name  = @CustomerAddressName AND Name <> ''
		OR 
		LatinName = @CustomerAddressLatinName AND LatinName <> '')
	
	IF(@Name <> '' AND @Name = @CustomerAddressName ) 
		SET	@CustomerAddressNameIsUsed = 1
	
	IF(@LatinName <> '' AND @LatinName = @CustomerAddressLatinName ) 
		SET	@CustomerAddressNameIsUsed = 2
	
	RETURN @CustomerAddressNameIsUsed	
END
##############################################
#END
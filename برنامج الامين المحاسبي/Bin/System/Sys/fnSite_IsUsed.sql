######################
CREATE FUNCTION fnSite_IsUsed(@SiteGUID [UNIQUEIDENTIFIER])
	RETURNS [INT] 
AS BEGIN 
/*  
this function:  
	- returns a constanct integer representing the existance of a given sites in the database tables.  
	- is usually called from trg_hosSite000_Hos_CheckConstraints.  
*/  
	DECLARE @result [INT]

	SET @result = 0 

	IF EXISTS(SELECT * FROM [HosStay000] WHERE [SiteGUID]	= @SiteGUID)
		SET @result = 0x010001 
		
	ELSE IF EXISTS(SELECT * FROM [HosPFile000] WHERE [SiteGUID]	= @SiteGUID)
		SET @result = 0x010002 

	ELSE IF EXISTS(SELECT * FROM [HosReservationDetails000] WHERE [SiteGUID] = @SiteGUID)
		SET @result = 0x010003 

	RETURN @result
END 

#######################
#END
#########################################################
CREATE FUNCTION fnDistDisc_IsUsed(@GUID [UNIQUEIDENTIFIER]) 
	RETURNS [INT]  
AS BEGIN  
/*   
this function:   
	- returns a constanct integer representing the existance of a given Dist Discount in the database tables.   
	- is usually called from trg_DistDisc000_CheckConstraints.
*/   
	DECLARE @result [INT] 
	SET @result = 0  
	IF EXISTS(SELECT * FROM [DistCtd000] WHERE [DiscountGUID]	= @GUID) 
		SET @result = 0x010001
	RETURN @result 
END  
#########################################################
CREATE FUNCTION fnDistCt_IsUsed(@GUID [UNIQUEIDENTIFIER]) 
	RETURNS [INT]  
AS BEGIN  
/*   
this function:   
	- returns a constanct integer representing the existance of a given Dist Discount in the database tables.   
	- is usually called from trg_DistCustType000_CheckConstraints.
*/   
	DECLARE @result [INT] 
	SET @result = 0  
	IF EXISTS(SELECT * FROM [DistCe000] WHERE [CustomerTypeGUID]	= @GUID) 
		SET @result = 0x010001
	RETURN @result 
END  

#########################################################
CREATE FUNCTION fnDistTch_IsUsed(@GUID [UNIQUEIDENTIFIER]) 
	RETURNS [INT]  
AS BEGIN  
/*   
this function:   
	- returns a constanct integer representing the existance of a given Dist Discount in the database tables.   
	- is usually called from trg_DistCustTch000_CheckConstraints.
*/   
	DECLARE @result [INT] 
	SET @result = 0  
	IF EXISTS(SELECT * FROM [DistCe000] WHERE [TradeChannelGUID]	= @GUID) 
		SET @result = 0x010001
	RETURN @result 
END
#########################################################	
CREATE  FUNCTION fnDistChkMatTemplateGroup ( @GroupGuid	UNIQUEIDENTIFIER, @TemplateGuid	UNIQUEIDENTIFIER )
	RETURNS [INT]
AS
BEGIN
	DECLARE @res INT
	SET @res = 1

	IF EXISTS ( 
			SELECT fn.Guid 
			FROM fnGetGroupParents( @GroupGuid) AS fn INNER JOIN DistMatTemplates000 AS T ON fn.Guid = T.GroupGuid 
			WHERE fn.Guid <> 0x00 AND T.Guid <> @TemplateGuid 
		  )	
		SET @res = 0

	IF EXISTS (
			SELECT fn.Guid 
			FROM fnGetGroupsList( @GroupGuid) AS fn INNER JOIN DistMatTemplates000 AS T ON fn.Guid = T.GroupGuid 
			WHERE fn.Guid <> 0x00 AND T.Guid <> @TemplateGuid
		  )
		SET @res = 0
		
	RETURN @res
END

/*
select dbo.fnDistChkMatTemplateGroup ( '957E6F98-4E8E-4FEC-831A-F9036DE6B22A')
select * from gr000
*/
#########################################################
#END
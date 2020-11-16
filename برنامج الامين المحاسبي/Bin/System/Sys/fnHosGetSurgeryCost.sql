####################################################
CREATE function fnHosGetSurgeryCost
	(  
		@FileGuid UNIQUEIDENTIFIER
	) 
RETURNS @Result TABLE 
	( 
	OperationGuid	UNIQUEIDENTIFIER, 
	SurgeryGuid		UNIQUEIDENTIFIER, 
	OperaionName	NVARCHAR(250) COLLATE ARABIC_CI_AI, 
	SurCount		INT, 
	TotalCost		FLOAT
	)	 
AS 
BEGIN
	INSERT INTO @Result 
	SELECT  
		Op.Guid, 
		S.guid,  
		op.[Name],  
		COUNT(s.[NAME]) AS SurCount,  
		c.TotalCost  
	FROM   
		HosFSurgery000 S   
		INNER JOIN hosoperation000 op ON S.OperationGuid = op.GUID	  
		INNER JOIN vwHosSurgeryCost() AS C ON c.guid = s.guid  
	WHERE  	fileGuid = @FileGuid
	GROUP BY S.guid, op.[Name], op.Guid, c.totalcost 
RETURN 
END 
####################################################
#END

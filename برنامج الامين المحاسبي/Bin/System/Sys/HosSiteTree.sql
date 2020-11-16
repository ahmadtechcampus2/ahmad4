#######################################################
CREATE FUNCTION fnHosSitesTree(     
			@Sorted INT = 0)  
		RETURNS @Result TABLE (GUID UNIQUEIDENTIFIER, [Level] INT DEFAULT 0, [Path] NVARCHAR(max) COLLATE ARABIC_CI_AI)     
BEGIN 
 INSERT INTO  @Result 
 SELECT  
	 *  
 FROM  dbo.fnGetSitesListSorted(0x0 ,1) 
 RETURN  
END 

#######################################################
CREATE PROCEDURE RepHosAllSitesTree
		@Lang		INT = 0 ,
		@Guid		[UNIQUEIDENTIFIER] = 0x00 
AS   
SET NOCOUNT ON 
	CREATE TABLE #SecViol (Type INT, Cnt INT)   
	CREATE TABLE #Result(   
			Guid		UNIQUEIDENTIFIER,   
			ParentGuid 	UNIQUEIDENTIFIER,   
			Code		NVARCHAR(255) COLLATE ARABIC_CI_AI,   
			[Name]	NVARCHAR(255) COLLATE ARABIC_CI_AI,   
			[LatinName]	NVARCHAR(255) COLLATE ARABIC_CI_AI,   
			Number		FLOAT,   
			Security INT,   
			--Type 		INT,  
			[Level] 	INT,   
			[Path] 		NVARCHAR(max) COLLATE ARABIC_CI_AI   
			)   
		 
	--exec  HosSetCurrentDate	 
	INSERT INTO #Result    
	SELECT    
			[ana].[Guid],    
			ISNull(ana.ParentGUID , 0x0) AS Parent,   
			ana.Code,    
			Ana.Name,  
			Ana.LatinName,  
			ana.Number,  
			ana.Security,   
			--ana.Type,  
			fn.[Level],  
			fn.Path   
		FROM 	  
			vwHosSite as ana INNER JOIN dbo.fnHosSitesTree(@Lang) AS fn  ON ana.Guid = fn.Guid  
		WHERE @Guid = 0X00 OR @Guid	= [ana].[Guid]		
		CREATE TABLE #LastResult (  
					  ItemGUID UNIQUEIDENTIFIER,  
					  LastResult NVARCHAR(255)) 
		 
	EXEC prcCheckSecurity   
	SELECT * FROM #Result ORDER BY Path   
	SELECT * FROM #SecViol 	
/*
SELECT * FROM vwHosSite
SELECT * FROM HosSite000

*/
##################################################################################

#END

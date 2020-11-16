###################################
CREATE VIEW vwOd
AS 
	SELECT
		[GUID]		AS [odGUID],
		[Number]	AS [odNumber],
		[Name]		AS [odName],
		[LatinName] AS [odLatinName],
		[Notes]		AS [odNotes],
		[Code]		AS [odCode],
		[security]	AS [odsecurity]
	FROM 
		[Department000]

###########################################################
CREATE   VIEW vwOdTb
AS 
	SELECT 
		[tbGUID]	AS [GUID], 
		[tbCode]	AS [Code], 
		[tbCover], 
		[odGUID], 
		[odCode], 
		[odName]		AS [Name], 
		[odLatinName]	AS [LatinName], 
		[odNotes], 
		[odsecurity]	AS [security] 
	FROM   
		[vwtb] INNER JOIN [vwod] ON [tbDepartment] = [odGUID] 

###################################
CREATE  FUNCTION fnVwOdTb (@DepartGUID [UNIQUEIDENTIFIER]) 
	RETURNS @Result TABLE  
	( 
		[GUID]		[UNIQUEIDENTIFIER], 
		[Code]		[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[tbCover]	[INT], 
		[odGUID]	[UNIQUEIDENTIFIER], 
		[odCode]	[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[Name]		[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[LatinName]	[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[odNotes]	[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[security]	[INT] 
	) 
AS   
BEGIN  
	INSERT INTO @Result 
	SELECT * FROM [vwOdtb] 
	WHERE ((@DepartGUID = 0x0)OR(([odGUID] = @DepartGUID)))
	RETURN
END  
###################################
#END
############################################################################################
CREATE PROCEDURE prcCheckDB_mt_RepeatedCode
	@Correct [INT] = 0
AS
	IF @Correct <> 1
	BEGIN
		DECLARE @MatTbl TABLE( [Code] [NVARCHAR](100) COLLATE ARABIC_CI_AI)
		INSERT INTO @MatTbl
			SELECT 
				[Code]
			FROM 
				[mt000] 
			GROUP BY 
				[Code] 
			HAVING 
				COUNT( [Code]) > 1
	
		INSERT INTO [ErrorLog]([Type], [g1], [c1])
			SELECT 
				0x0D, [mt].[Guid], [mt].[Code]
			FROM 
				[mt000] AS [mt] INNER JOIN @MatTbl AS [tbl]
				ON ([mt].[Code] COLLATE  ARABIC_CI_AI) = ([tbl].[Code] COLLATE ARABIC_CI_AI)
	END
############################################################################################
#END
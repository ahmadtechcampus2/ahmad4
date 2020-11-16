## ÌﬁÊ„ Â–« «·≈Ã—«¡ »Õ”«» Õ—ﬂ… Õ”«» Œ «„Ì
######################################################
CREATE PROCEDURE prcCalcFinalAcc
	@StartDate [DATETIME],		-- ????? ????? ??????  
	@EndDate [DATETIME],			-- ????? ????? ??????  
	@FinalAcc [INT],				-- ??? ?????? ???????  
	@UserCeSec [INT],				-- ?????? ???????? ???????  
	@UserAccSec [INT],			-- ?????? ???????? ????????  
	@Notes1 [NVARCHAR](256),		-- ???? ??????? ??? ??? ????  
	@Notes2 [NVARCHAR](256)		-- ???? ??????? ??? ??? ?? ????  
AS  
	SET NOCOUNT ON
	
	CREATE TABLE [#t_Result]
	(
	 	[acName] [NVARCHAR](256) COLLATE ARABIC_CI_AI	DEFAULT '',      
		[Account] [INT],
		[ParentAcc] [INT],
		[ParentName] [NVARCHAR](256) COLLATE ARABIC_CI_AI	DEFAULT '',      
		[ParentCode]  [NVARCHAR](256) COLLATE ARABIC_CI_AI	DEFAULT '',      
		[enDebit]	[FLOAT]		DEFAULT 0,      
		[enCredit] [FLOAT]		DEFAULT 0,  
		[CeSecurity] [INT]		DEFAULT 0,  
		[AcSecurity] [INT]		DEFAULT 0
	)

	CREATE TABLE [#t_SecViol](
		[SecType]	[INT],
		[SecValue]  [INT]
	)

	DECLARE @SqlString [NVARCHAR](3000)  
	SET @SqlString ='  
	INSERT INTO [#t_Result]
	SELECT  
		[acName],  
		[enAccount] AS [Number],  
		[dbo].[fnGetFinalAcc]( '+CAST(@FinalAcc AS [NVARCHAR])+', [enAccount]) AS [ParentAcc],  
		( SELECT [acName] FROM [vwAc] WHERE [acNumber] = [dbo].[fnGetFinalAcc]('+CAST(@FinalAcc AS [NVARCHAR])+', [enAccount]) ) AS [ParentName],  
		( SELECT [acCode] FROM [vwAc] WHERE [acNumber]  = [dbo].[fnGetFinalAcc]('+CAST(@FinalAcc AS [NVARCHAR])+', [enAccount]) )AS [ParentCode],'  
		SET @SqlString = @SqlString+' SUM([enDebit]) AS [enDebit],
		 SUM([enCredit]) AS [enCredit],[ceSecurity],[acSecurity] '  
		SET @SqlString = @SqlString + ' FROM [vwExtended_en]  
			 WHERE [EnDate] BETWEEN ''' +  CAST(@StartDate  AS [NVARCHAR])+ ''' AND '''  
			+ CAST(@EndDate  AS [NVARCHAR])+ ''''	  
		
 		IF ISNULL(@Notes1, '') <> ''  
			SET @SqlString = @SqlString + ' AND [enNotes] LIKE ''%'+ @Notes1 +'%'''	  
 		IF ISNULL(@Notes2, '') <> ''  
			SET @SqlString = @SqlString + ' AND [enNotes] NOT LIKE ''%'+ @Notes2 +'%'''  
		SET @SqlString = @SqlString +' GROUP BY [enAccount], [acName],[ceSecurity],[acSecurity],  
			[dbo].[fnGetFinalAcc]('+CAST(@FinalAcc AS [NVARCHAR])+', [enAccount]) '  
		SET @SqlString = @SqlString + ' ORDER BY [acName]'  
	EXECUTE(@SqlString)  

print (@SqlString)

DECLARE @RecCnt AS [INT]
SET @RecCnt = (SELECT COUNT(*) FROM [#t_Result] WHERE [ceSecurity] > @UserCeSec)
INSERT INTO [#t_SecViol] VALUES(1, @RecCnt)

SET @RecCnt = (SELECT COUNT(*) FROM [#t_Result] WHERE [acSecurity] > @UserAccSec)
INSERT INTO [#t_SecViol] VALUES(2, @RecCnt)

SELECT * from  [#t_Result] WHERE [ceSecurity] <= @UserCeSec AND  [acSecurity] <= @UserAccSec

SELECT * from  [#t_SecViol]

#########################################################
#END

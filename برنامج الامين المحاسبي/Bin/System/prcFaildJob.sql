######################################
##
##
######################################
CREATE PROCEDURE prcGetFaildJobCnt
AS 

DECLARE @NameStr  [NVARCHAR](1000)
SET @NameStr = '%' + db_name() + '%'
SELECT COUNT(*) AS [cnt]
FROM 
	[msdb].[dbo].[sysjobs] AS [sj] INNER JOIN [msdb].[dbo].[sysjobservers] AS [js]
	ON [sj].[job_id] = [js].[job_id]
WHERE 
		[js].[last_run_outcome] = 0 AND
		[sj].[name] LIKE @NameStr 

#####################################
#END
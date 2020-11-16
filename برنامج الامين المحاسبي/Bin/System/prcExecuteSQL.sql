#########################################################
create proc prcExecuteSQL 
	@sql [NVARCHAR](max), 
	@param0 [NVARCHAR](2000) = null, 
	@param1 [NVARCHAR](2000) = null, 
	@param2 [NVARCHAR](2000) = null, 
	@param3 [NVARCHAR](2000) = null, 
	@param4 [NVARCHAR](2000) = null, 
	@param5 [NVARCHAR](2000) = null, 
	@param6 [NVARCHAR](2000) = null,
	@param7 [NVARCHAR](2000) = null,
	@param8 [NVARCHAR](2000) = null,
	@param9 [NVARCHAR](2000) = null,
	@caller [NVARCHAR](128) = null
as  
	set nocount on 
	
	declare
		@nestLevel [int],
		@logMsg [NVARCHAR](max)

	set @nestLevel = @@nestLevel - 1

	set @sql = [dbo].[fnFormatString] (@sql, @param0, @param1, @param2, @param3, @param4, @param5, @param6, @param7, @param8, @param9) 
	set @logMsg = 'executingSQL: ' + @sql
	exec [prcLog] @logMsg--, @nestLevel = @nestLevel
	exec (@sql)	

	return @@error
#########################################################
#END
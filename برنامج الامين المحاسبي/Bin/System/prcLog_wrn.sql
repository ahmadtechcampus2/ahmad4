#########################################################
CREATE PROC prcLog_wrn
	@message [NVARCHAR](max) = '',  
	@param0 [NVARCHAR](128) = null,  
	@param1 [NVARCHAR](128) = null,  
	@param2 [NVARCHAR](128) = null,  
	@param3 [NVARCHAR](128) = null,  
	@param4 [NVARCHAR](128) = null,  
	@param5 [NVARCHAR](128) = null,  
	@param6 [NVARCHAR](128) = null, 
	@param7 [NVARCHAR](128) = null, 
	@param8 [NVARCHAR](128) = null, 
	@param9 [NVARCHAR](128) = null,
	@caller [NVARCHAR](128) = null,
	@details [NVARCHAR](max) = null,
	@exitCode [int] = @@error

as

	declare @nestLevel [int]
	set @nestLevel = @@nestLevel - 1

	exec  [prcLog]
		@message = @message,
		@param0 = @param0,
		@param1 = @param1,
		@param2 = @param2,
		@param3 = @param3,
		@param4 = @param4,
		@param5 = @param5,
		@param6 = @param6,
		@param7 = @param7,
		@param8 = @param8,
		@param9 = @param9,
		@caller = @caller,
		@details = @details,
		@exitCode = @exitCode,
		@status = 'wrn',
		@nestLevel = @nestlevel

#########################################################
#END

 
 
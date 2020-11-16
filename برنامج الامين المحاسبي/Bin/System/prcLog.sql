#########################################################
CREATE PROCEDURE prcLog
	@txt [NVARCHAR](max) = '', 
	@param0 [NVARCHAR](128) = null, 
	@param1 [NVARCHAR](128) = null, 
	@param2 [NVARCHAR](128) = null, 
	@param3 [NVARCHAR](128) = null, 
	@param4 [NVARCHAR](128) = null, 
	@param5 [NVARCHAR](128) = null, 
	@param6 [NVARCHAR](128) = null,
	@param7 [NVARCHAR](128) = null,
	@param8 [NVARCHAR](128) = null,
	@param9 [NVARCHAR](128) = null
as 
	SET NOCOUNT ON
	IF OBJECT_ID(N'DBLog', N'U') IS NULL
	BEGIN
		CREATE TABLE [dbo].[DBLog]
		(
			[ID] int identity PRIMARY KEY,
			[Time] datetime NOT NULL DEFAULT GetDate(),
			[Notes] NVARCHAR(max) NULL
		) 
	END

	
	if @txt = ''
		set @txt = '<nothing>'
	else
		set @txt = [dbo].[fnFormatString] (@txt, @param0, @param1, @param2, @param3, @param4, @param5, @param6, @param7, @param8, @param9)

	DECLARE @text AS [NVARCHAR](max)
	SET @text = REPLICATE( '.', @@NESTLEVEL)
	SET @text = @text + LEFT(@txt, 8000)
	--print @text
	INSERT INTO DBLog( [Notes])	SELECT @text
		
#########################################################
#END

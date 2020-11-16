#########################################################
CREATE PROC prcItemSecurityExtended_AddISRT -- Item Security Related Table
	@ClassName [NVARCHAR](128),
	@TableName [NVARCHAR](128),
	@ListingFunctionName [NVARCHAR](128) = '',
	@Name [NVARCHAR](128) = '',
	@LatinName [NVARCHAR](128) = '',
	@ParentFldName [NVARCHAR](128) = ''
AS
	SET NOCOUNT ON
	IF NOT EXISTS( SELECT * FROM [isrt] WHERE [TableName]  = @TableName)
		INSERT INTO [isrt] ([ClassName], [TableName], [ListingFunctionName],[Name],[LatinName], [ParentFldName])
			SELECT @ClassName, @TableName, @ListingFunctionName, @Name, @LatinName, @ParentFldName


#########################################################
#END
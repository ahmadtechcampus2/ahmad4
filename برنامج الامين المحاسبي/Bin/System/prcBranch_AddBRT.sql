#########################################################
CREATE PROC prcBranch_AddBRT -- Branch Related Table
	@ClassName [NVARCHAR](128),
	@TableName [NVARCHAR](128),
	@ListingFunctionName [NVARCHAR](128) = '',
	@SingleBranch [BIT] = 0,
	@SingleBranchFldName [NVARCHAR](128) = 'Branch',
	@Name [NVARCHAR](128) = '',
	@LatinName [NVARCHAR](128) = ''
AS
	SET NOCOUNT ON
	IF [dbo].[fnObjectExists]( @TableName ) <> 0
		IF NOT EXISTS( SELECT * FROM [brt] WHERE [TableName]  = @TableName)
			INSERT INTO [brt] ([ClassName], [TableName], [ListingFunctionName],[SingleBranch],[SingleBranchFldName],[Name],[LatinName])
				SELECT @ClassName, @TableName, @ListingFunctionName, @SingleBranch, @SingleBranchFldName, @Name, @LatinName


#########################################################
#END
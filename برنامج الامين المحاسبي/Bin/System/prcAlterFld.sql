##########################################################################
CREATE PROCEDURE prcAlterFld 
	@TableName [NVARCHAR] (128),
	@Column [NVARCHAR] (128),
	@NewType [NVARCHAR] (128),
	@bNull [BIT] = 1,
	@DefaultVal [NVARCHAR] (128) = NULL
AS
	SET NOCOUNT ON
	IF NOT EXISTS (SELECT * FROM SYS.OBJECTS WHERE NAME = @TableName AND [TYPE] = 'U')
		RETURN
	DECLARE @Sql AS [NVARCHAR](max)
	
	SET @Sql = 	'prcAlterFld:' + @TableName + '.' + @Column + ' -> ' + @NewType
	EXECUTE [prcLog] @Sql	
	IF [dbo].[fnObjectExists]( @TableName + '.' + @Column) <> 0
	BEGIN
		EXECUTE [prcDropFldConstraints] @TableName, @Column

		SET @Sql = 'ALTER TABLE [' + @TableName + '] ALTER COLUMN [' + @Column + '] ' + @NewType
		IF @bNull = 1
			SET @Sql = @Sql + ' NULL'
		ELSE
			SET @Sql = @Sql + ' NOT NULL'
		EXECUTE [prcLog] @Sql
		EXECUTE (@Sql)
		
		IF NOT @DefaultVal IS NULL
		BEGIN
			SET @Sql =  'ALTER TABLE [' + @TableName + '] ADD CONSTRAINT [DF__' 
						+ @TableName + '__' + @Column + '_12341234] DEFAULT ' + @DefaultVal + ' FOR [' + @Column + ']'
			EXECUTE (@Sql)
		END
	END
##########################################################################
CREATE PROCEDURE prcChangeDefault
	@TblName NVARCHAR(100),
	@ColName NVARCHAR(100),
	@Const	NVARCHAR(100)
AS
	DECLARE 
		@ConstName NVARCHAR(100),
		@Sql NVARCHAR(MAX)
			
	SET @Sql = 'prcChangeDefault ' + @TblName + '.' + @ColName + '-' + @Const
	EXECUTE [prcLog] @Sql
	
	SELECT  
		@ConstName = const.name
	FROM 
		sys.default_constraints const 
		INNER JOIN sys.Objects obj ON const.parent_object_id = obj.object_id
		INNER JOIN SYS.COLUMNS col ON const.parent_column_id = col.column_id  AND col.object_id = obj.object_id
	WHERE 
		obj.name = @TblName and col.name = @ColName

	IF @ConstName IS NOT NULL
	BEGIN 	
		SET @Sql = 'ALTER TABLE ' + @TblName + ' DROP CONSTRAINT ' + @ConstName
		EXECUTE prcExecuteSQL @Sql
	END 
	
	IF @Const = '''' OR @Const = ''
		SET @Const = ''''''

	SET @Sql = 'ALTER TABLE ' + @TblName + ' ADD DEFAULT (' + @Const + ') FOR [' + @ColName + ']'
	EXECUTE prcExecuteSQL @Sql
##########################################################################
#END

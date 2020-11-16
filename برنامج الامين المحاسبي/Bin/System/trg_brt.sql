#include prcBranch_UnInstallTable.sql
#include prcBranch_InstallMultiBranchTable.sql
#include prcBranch_InstallSingleBranchTable.sql
#include prcBranch_AddBRT.sql

#########################################################
CREATE TRIGGER trg_brt_CheckConstraints
	ON [brt] FOR INSERT, UPDATE
	NOT FOR REPLICATION

AS
/*
this trigger assures:
	- not to update TableName, SingleBranch or SinfleBranchFldName flields.
	- not to insert duplicate TableName.
*/
	SET NOCOUNT ON 
	
	IF EXISTS(SELECT * FROM [deleted]) AND (UPDATE([TableName]) OR UPDATE([SingleBranch]) OR UPDATE([SingleBranchFldName]))
		INSERT INTO [ErrorLog] ([level], [type], [c1]) SELECT 1, 0, 'AmnE0080: Can''t update TableName or MultiBranch fields'

	IF (SELECT COUNT(DISTINCT [TableName]) FROM [brt]) <> (SELECT COUNT(*) FROM [brt])
		INSERT INTO ErrorLog ([level], [type], [c1]) SELECT 1, 0, 'AmnE0081: a table with the same name already installed in brt'

#########################################################
CREATE TRIGGER trg_brt_insert
	ON [BRT] FOR INSERT
	NOT FOR REPLICATION

AS
	SET NOCOUNT ON 
	
	DECLARE
		@c CURSOR,
		@TableName [VARCHAR](128),
		@SingleBranch [BIT],
		@SingleBranchFldName [NVARCHAR](128)

	SET @c = CURSOR FAST_FORWARD FOR SELECT [TableName], [SingleBranch], [SingleBranchFldName] FROM [inserted]
	OPEN @c FETCH FROM @c INTO @TableName, @SingleBranch, @SingleBranchFldName
	
	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF @SingleBranch = 1
			EXEC [prcBranch_InstallSingleBranchTable] @TableName, @SingleBranchFldName
		ELSE
			EXEC [prcBranch_InstallMultiBranchTable] @TableName

		FETCH FROM @c INTO @TableName, @SingleBranch, @SingleBranchFldName
	END

	CLOSE @c DEALLOCATE @c

#########################################################
CREATE TRIGGER trg_brt_delete
	ON [BRT] FOR DELETE
	NOT FOR REPLICATION

AS
	SET NOCOUNT ON 
	
	DECLARE
		@c CURSOR,
		@TableName [NVARCHAR](128)
		
	SET @c = CURSOR FAST_FORWARD FOR SELECT [TableName] FROM [deleted]
	OPEN @c FETCH FROM @c INTO @TableName
	
	WHILE @@FETCH_STATUS = 0
	BEGIN
		EXEC [prcBranch_UnInstallTable] @TableName
		FETCH FROM @c INTO @TableName
	END
	CLOSE @c
	DEALLOCATE @c

#########################################################
#END
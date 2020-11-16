######################################################### 
CREATE PROC prcBranch_enable
	@enableBranches [BIT] = 1
AS
/*
This procedure:
	- inserts/updates the op000 EnableBranches record.
	- optimize views accordingly.
	- is usually called from options dialog in al-ameen.
*/
	SET NOCOUNT ON
	
	DELETE [op000] WHERE [name] = 'EnableBranches'
	INSERT INTO [op000] ([name], [value]) VALUES( 'EnableBranches', @enableBranches)

	EXECUTE [prcBranch_optimize]
	EXECUTE [prcBranch_Optimize_LeftTables]
	EXECUTE [prcUser_SetDirtyFlag]

#########################################################
#END
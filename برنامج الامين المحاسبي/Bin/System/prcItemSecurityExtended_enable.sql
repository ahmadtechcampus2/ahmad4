######################################################### 
CREATE PROC prcItemSecurityExtended_enable
	@enable [BIT] = 1
AS
/*
This procedure:
	- inserts/updates the op000 EnableBranches record.
	- optimize views accordingly.
	- is usually called from options dialog in al-ameen.
*/
	DELETE [op000] WHERE [name] = 'EnableItemSecurity'
	INSERT INTO [op000] ([name], [value]) VALUES( 'EnableItemSecurity', @enable)

	EXECUTE [prcItemSecurityExtended_Optimize]
#########################################################
#END
######################################################### 
CREATE PROC prcCheckDB
	@correct [INT] = 1
AS
	EXEC [prcCheckDBProc_exec] @correct = @correct

#########################################################
CREATE PROC prcMaintain_GenAndPost_Prepare 
AS 
	SET NOCOUNT ON 
	
	EXEC [prcDisableTriggers] 'bu000', 0
	EXEC [prcDisableTriggers] 'ce000', 0
	EXEC [prcDisableTriggers] 'en000', 0
	ALTER TABLE bu000 ENABLE TRIGGER trg_bu000_CheckConstraints_sn

#########################################################
CREATE PROC prcMaintain_GenAndPost_Finish
AS 
	SET NOCOUNT ON 
	
	EXEC [prcEnableTriggers] 'bu000'
	EXEC [prcEnableTriggers] 'ce000'
	EXEC [prcEnableTriggers] 'en000'

	EXEC [prcBill_RePost]
	EXEC [prcEntry_RePost]

#########################################################
#END

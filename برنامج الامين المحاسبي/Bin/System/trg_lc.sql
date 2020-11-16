#########################################################
CREATE TRIGGER trg_LC000_CheckConstraints
	ON [LC000] FOR DELETE
AS
/*
This trigger checks:
	- if letter of credit is used in bill or entry. 			(AmnE1100)
*/
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON

	IF EXISTS(	SELECT * FROM deleted AS [d] 
				INNER JOIN vwBu Bu ON Bu.[buLCGUID] = d.[GUID])
		INSERT INTO [ErrorLog] ([level], [type], [c1]) 
			SELECT 1, 0, 'AmnE1100: Cannot delete letter of Credit is used in bill'

	IF EXISTS(	SELECT * FROM deleted AS [d] 
				INNER JOIN vwExtended_en En ON en.[enLCGUID] = d.[GUID])
		INSERT INTO [ErrorLog] ([level], [type], [c1]) 
			SELECT 1, 0, 'AmnE1100: Cannot delete letter of Credit is used in entry'

#########################################################
CREATE TRIGGER trg_LC000_closeLC
	ON [dbo].[LC000] FOR UPDATE
	NOT FOR REPLICATION
AS  
	IF @@ROWCOUNT = 0 RETURN  
	SET NOCOUNT ON
	BEGIN 
		IF(dbo.fnOption_GetInt('EnableBranches', '0') = 1)
			BEGIN
				IF EXISTS(SELECT I.State FROM INSERTED I INNER JOIN DELETED D ON I.GUID = D.GUID WHERE I.State != D.State AND I.State = 0)
					BEGIN
						DECLARE @LCBranchGUID UNIQUEIDENTIFIER, @LCGUID UNIQUEIDENTIFIER 
						DECLARE @LCbranchMask INT, @accountBranchMask INT, @costCenterBranchMask INT, @LCMainBranchMask INT
						
						SELECT @LCGUID = I.[GUID], 
							   @LCBranchGUID = I.BranchGUID, 
							   @LCbranchMask = BR.brBranchMask,
							   @accountBranchMask = AC.branchMask,
							   @costCenterBranchMask = CO.branchMask,
							   @LCMainBranchMask = LCMAIN.branchMask
						FROM INSERTED I 
						LEFT JOIN vwBr BR ON I.BranchGUID = BR.brGUID 
						INNER JOIN ac000 AC ON I.AccountGUID = AC.GUID 
						LEFT JOIN co000 CO ON I.CostCenterGUID = CO.GUID 
						INNER JOIN LCMain000 LCMAIN ON I.ParentGUID = LCMAIN.GUID

						IF(@LCBranchGUID <> 0x0)
							BEGIN
								IF EXISTS( SELECT BU.Branch 
										   FROM BU000 BU INNER JOIN LC000 LC
										   ON BU.LCGUID = @LCGUID
										   WHERE BU.Branch != @LCBranchGUID AND LCGUID = @LCGUID
								  )
								OR EXISTS( SELECT ce.Branch 
										   FROM ce000 ce INNER JOIN en000 en
										   ON ce.GUID = en.ParentGUID
										   WHERE ce.Branch != @LCBranchGUID AND en.LCGUID = @LCGUID
										  )
									BEGIN
										INSERT INTO ErrorLog ([level], [type], [c1], [g1])
											   SELECT 1, 0,  'AmnE0555: the branch of bills or entries is different from LC branch, can''t close the LC' , @LCGUID
									END

								IF((@LCbranchMask & @accountBranchMask) = 0)
									BEGIN
										INSERT INTO ErrorLog ([level], [type], [c1], [g1])
											   SELECT 1, 0,  'AmnE0556: account branch is different from LC branch, can''t close the LC' , @LCGUID
									END

								IF((@LCbranchMask & @costCenterBranchMask) = 0)
									BEGIN
										INSERT INTO ErrorLog ([level], [type], [c1], [g1])
											   SELECT 1, 0,  'AmnE0557: cost center branch is different from LC branch, can''t close the LC' , @LCGUID
									END

								IF((@LCbranchMask & @LCMainBranchMask) = 0)
									BEGIN
										INSERT INTO ErrorLog ([level], [type], [c1], [g1])
											   SELECT 1, 0,  'AmnE0558: LCMain branch is different from LC branch, can''t close the LC' , @LCGUID
									END
							END 
					END
				RETURN
			END
	END
#########################################################
#END
##################################################################
CREATE TRIGGER trg_OrderAlternativeUsers000_delete
	ON OrderAlternativeUsers000 FOR DELETE
	NOT FOR REPLICATION
AS
	SET NOCOUNT ON

	IF EXISTS(SELECT * FROM OrderApprovalStates000 oas INNER JOIN deleted d ON d.[GUID] = oas.AlternativeUserGUID)
	BEGIN
		INSERT INTO [ErrorLog] ([level], [type], [c1])
		SELECT 1, 0, 'AmnE0147: Can''t delete used alternativeUser card because it''s used';
		return;
	END;
	
	DELETE oauTypes 
	FROM 
		OrderAlternativeUserTypes000 oauTypes
		INNER JOIN deleted d ON d.GUID = oauTypes.ParentGUID;
##################################################################
CREATE TRIGGER trg_OrderAlternativeUserTypes000_Insert
	ON OrderAlternativeUserTypes000 FOR INSERT
	NOT FOR REPLICATION
AS
	SET NOCOUNT ON

	DECLARE @CurrentDate DATETIME = GETDATE()
	IF EXISTS
		(
			SELECT * 
			FROM 
				inserted i
				INNER JOIN OrderAlternativeUsers000 oau ON i.ParentGUID = oau.[GUID]
			WHERE
			(oau.IsActive = 1) OR (oau.IsLimitedActive = 1 AND @CurrentDate BETWEEN oau.StartDate AND oau.ExpireDate)
		)
	BEGIN
		INSERT INTO [ErrorLog] ([level], [type], [c1])
		SELECT 1, 0, 'AmnE0150: can''t insert types for an active parent';
		RETURN;
	END
##################################################################
CREATE TRIGGER trg_OrderAlternativeUsers000_CheckConstraints
	ON OrderAlternativeUsers000 FOR INSERT, UPDATE, DELETE
	NOT FOR REPLICATION
AS
	SET NOCOUNT ON

	IF EXISTS(SELECT * FROM inserted)
	BEGIN
		IF EXISTS(SELECT * FROM inserted WHERE UserGUID = 0x0 OR AlternativeUserGUID = 0x0)
		BEGIN
			INSERT INTO [ErrorLog]([level], [type], [c1])
			SELECT 1, 0, 'AmnE0151: User or AlternativeUser can''t be empty';
			RETURN;
		END
		IF EXISTS(SELECT * FROM inserted WHERE UserGUID = AlternativeUserGUID)
		BEGIN
			INSERT INTO [ErrorLog]([level], [type], [c1])
			SELECT 1, 0, 'AmnE0152: User and AlternativeUser can''t be the same';
			RETURN;
		END

		IF EXISTS(SELECT * FROM deleted) AND (NOT UPDATE(IsAllAvailableTypes) AND NOT UPDATE(IsActive)  AND NOT UPDATE(IsLimitedActive))
		BEGIN
			INSERT INTO [ErrorLog]([level], [type], [c1])
			SELECT 1, 0, 'AmnE0153: can not update card because it''s used';
			RETURN;
		END

		IF EXISTS(SELECT * 
				FROM
					 inserted i  
					 INNER JOIN OrderAlternativeUsers000 oau on  i.UserGUID = oau.UserGUID
				WHERE
					 i.AlternativeUserGUID = oau.AlternativeUserGUID
					AND I.[GUID] <> OAU.[GUID])
		BEGIN
			INSERT INTO [ErrorLog]([level], [type], [c1])
			SELECT  1, 0, 'AmnE0154: User and AlternativeUser can''t have more than one card';
			RETURN;
		 END
	END
##################################################################
#END
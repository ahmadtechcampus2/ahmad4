#################################################################
create PROC prcPaGenerateEntry
	@ID int
AS
SET NOCOUNT ON

DECLARE @Date DateTime,
		@Note NVARCHAR(250),
		@EnNote NVARCHAR(250),
		@CurGuid UniqueIdentifier,
		@CurVal float,
		@Value float,
		@Number int,
		@PaCeID UniqueIdentifier,
		@CeID UniqueIdentifier,
		@AcDebitID UniqueIdentifier,
		@AcCreditID UniqueIdentifier

DECLARE pa_ce CURSOR FAST_FORWARD
	FOR SELECT GUID, ISNULL(Date, GetDate()), ISNULL(Note, ''), CurGUID, CurVal FROM pa_ce000

OPEN pa_ce

FETCH NEXT 
FROM pa_ce
INTO @PaCeID, @Date, @Note, @CurGuid, @CurVal

WHILE @@FETCH_STATUS = 0
BEGIN
	SELECT @Value=ISNULL(Debit, 0),@AcDebitID=AcGUID,@EnNote=ISNULL(Note, '') FROM pa_en000 WHERE CeGuid=@PaCeID AND Debit<>0
	SELECT @AcCreditID=AcGUID FROM pa_en000 WHERE CeGuid=@PaCeID AND Credit<>0
	SELECT @Number = ISNULL(MAX(Number), 0) + 1 FROM CE000
	SET @CeID = newid()
	INSERT INTO [CE000] 
		([Type],[Number],[Date],[Debit],[Credit],[Notes],[CurrencyVal],[IsPosted],[State],[Security] 
		   ,[Num1],[Num2],[Branch],[GUID],[CurrencyGUID],[TypeGUID]) 
	VALUES(1,--Type 
			@Number,--Number 
			@Date,--Date 
			@Value, --Debit 
			@Value, --Credit 
			@Note,--Notes 
			@CurVal,--CurrencyVal 
			0,--IsPosted 
			0,--State 
			1,--Security 
			0,--Num1 
			0,--Num2 
			0x0,--Branch 
			@CeID,--GUID 
			@CurGuid,--CurrencyGUID 
			0x0) --TypeGUID
			
	INSERT INTO [en000]  (
		[Number]
		,[Date]
		,[Debit]
		,[Credit]
		,[Notes]
		,[CurrencyVal]
		,[Class]
		,[Num1]
		,[Num2]
		,[Vendor]
		,[SalesMan]
		,[GUID]
		,[ParentGUID]
		,[AccountGUID]
		,[CurrencyGUID]
		,[CostGUID]
		,[ContraAccGUID])
	SELECT 
		1, --Number 
		@Date, --Date 
		0, --Debit 
		@value, --Credit 
		@Note, --Notes 
		@CurVal, --CurrencyVal 
		'', --Class 
		0, --Num1 
		0, --Num2 
		0, --Vendor 
		0, --SalesMan 
		newid(),
		@CeID, --ParentGUID 
		AmnGUID, --AccountGUID 
		@CurGuid, --CurrencyGUID 
		0x0, --CostGUID 
		0x0 --ContraAccGUID
		FROM pa_ac000 WHERE GUID=@AcCreditID
		
	INSERT INTO [en000] (
		[Number]
		,[Date]
		,[Debit]
		,[Credit]
		,[Notes]
		,[CurrencyVal]
		,[Class]
		,[Num1]
		,[Num2]
		,[Vendor]
		,[SalesMan]
		,[GUID]
		,[ParentGUID]
		,[AccountGUID]
		,[CurrencyGUID]
		,[CostGUID]
		,[ContraAccGUID])
	SELECT
		1, --Number 
		@Date, --Date 
		@value, --Debit 
		0, --Credit 
		@Note, --Notes 
		@CurVal, --CurrencyVal 
		'', --Class 
		0, --Num1 
		0, --Num2 
		0, --Vendor 
		0, --SalesMan 
		newid(),
		@CeID, --ParentGUID 
		AmnGUID, --AccountGUID 
		@CurGuid, --CurrencyGUID 
		0x0, --CostGUID 
		0x0 --ContraAccGUID 
		FROM pa_ac000 WHERE GUID=@AcDebitID
						
	-- UPDATE [CE000] SET ISPOSTED=1
	FETCH NEXT 
	FROM pa_ce
	INTO @PaCeID, @Date, @Note, @CurGuid, @CurVal			
END
CLOSE pa_ce
DEALLOCATE pa_ce
DELETE pa_en000
DELETE pa_ce000
#################################################################
CREATE PROCEDURE repGetPA_CE
 @DevGuid UNIQUEIDENTIFIER
AS
	SELECT ce.Number , ce.GUID,ce.DeviceGuid,ce.Date,ce.Note,ce.CurGuid,ce.CurVal,ce.ParentName,ce.CanUpdateAmount,ce.CanUpdateNotes,ce.Deleted,ce.IsPocketAcc,ce.Timestamp 
	FROM dbo.PA_CE000 ce 
	WHERE ce.DeviceGuid = @DevGuid
#################################################################
CREATE PROCEDURE repGetPA_EN
 @DevGuid UNIQUEIDENTIFIER
AS
	SELECT en.Number , en.GUID,en.CEGUID,en.AcGuid,en.Debit,en.Credit,en.Note,en.Timestamp
	FROM dbo.PA_EN000 en 
	WHERE en.CEGUID in (SELECT GUID FROM dbo.PA_CE000 WHERE AcGUID in (SELECT GUID FROM dbo.PA_Ac000 WHERE DeviceGuid = @DevGuid))
#################################################################
CREATE FUNCTION PA_fnGetAmnAccounts ( @DeviceGUID UNIQUEIDENTIFIER, @ExpIntervalPocketAcc int, @ExpIntervalStatAcc int, @SyncDate DateTime)
RETURNS TABLE
AS
RETURN 
(
	SELECT  AC.Number, AC.GUID, AC.AmnGUID, AC.DeviceGuid, AC.AmnName, AC.Type, AC.IsET,
			AC.IsStatmentAcc,
			ISNULL(( SELECT SUM(Debit) 
					 FROM EN000 
					 WHERE AccountGuid = Ac.AmnGuid
						   AND
						   Date > ( @SyncDate - ( CASE AC.Type 
										                 WHEN 0 THEN 
											                  CASE AC.IsET 
												                    WHEN 1 THEN @ExpIntervalPocketAcc
												                    ELSE CASE AC.IsStatmentAcc
															                  WHEN 1 THEN @ExpIntervalStatAcc
															                  ELSE 0 
														                 END 
                                                              END
										                 ELSE @ExpIntervalPocketAcc
                                                    END
                                                   ) ) ), 0) InitDebit,
			ISNULL(( SELECT SUM(Credit) 
                     FROM EN000 
                     WHERE AccountGuid = Ac.AmnGuid
                           AND
						   Date > ( @SyncDate - ( CASE AC.Type 
										                 WHEN 0 THEN 
											                  CASE AC.IsET 
												                    WHEN 1 THEN @ExpIntervalPocketAcc
												                    ELSE CASE AC.IsStatmentAcc
															                  WHEN 1 THEN @ExpIntervalStatAcc
															                  ELSE 0 
														                 END 
                                                              END
										                 ELSE @ExpIntervalPocketAcc
                                                    END
                                                   ) ) ), 0) InitCredit,
            AC.Icon, AC.Text, AC.Timestamp
	FROM PA_AC000 AC
)
#################################################################
CREATE FUNCTION PA_fnGetPAAccounts ( @DeviceGUID UNIQUEIDENTIFIER )
RETURNS TABLE
AS
RETURN 
(
	SELECT * FROM PA_AC000 WHERE DeviceGUID = @DeviceGUID
)
#################################################################
CREATE FUNCTION PA_fnGetAmnEntries ( @DeviceGUID UNIQUEIDENTIFIER, @ExpIntervalPocketAcc int, @ExpIntervalStatAcc int, @SyncDate DateTime )
RETURNS TABLE
AS
RETURN
(
	SELECT E.Number, E.GUID, E.ParentGUID CEGUID, 
		   A.GUID AcGUID, E.Debit, E.Credit, 
		   E.Notes Note, E.Date Timestamp
	FROM EN000 E, (Select * FROM PA_fnGetPAAccounts(@DeviceGUID)) A
	WHERE E.AccountGUID = A.AmnGUID
		  AND
		  E.Date > (@SyncDate - (CASE A.Type 
							 WHEN 0 THEN 
								  CASE A.IsET 
									   WHEN 1 THEN @ExpIntervalPocketAcc
									   ELSE CASE A.IsStatmentAcc
												 WHEN 1 THEN @ExpIntervalStatAcc
												 ELSE 0 
											END 
								  END
							 ELSE @ExpIntervalPocketAcc
						 END
						))
)
#################################################################
CREATE FUNCTION PA_fnGetPAEntries ( @DeviceGUID UNIQUEIDENTIFIER )
RETURNS TABLE
AS
RETURN
(
	SELECT E.Number, E.GUID, E.CEGUID, 
           E.AcGUID, E.Debit, E.Credit, 
           E.Note, E.Timestamp
	FROM PA_EN000 E, (Select * FROM PA_fnGetPAAccounts(@DeviceGUID)) A
	WHERE E.AcGUID = A.GUID
)
#################################################################
CREATE FUNCTION PA_fnGetAmnCEntries ( @DeviceGUID UNIQUEIDENTIFIER, @ExpIntervalPocketAcc int, @ExpIntervalStatAcc int, @SyncDate DateTime )
RETURNS TABLE
AS
RETURN
(
	SELECT C.Number, C.GUID, @DeviceGuid DeviceGuid, C.Date, C.Notes Note,
		   C.CurrencyGUID CurGuid, C.CurrencyVal CurVal, 
		   (CASE C.TypeGuid WHEN '00000000-0000-0000-0000-000000000000' THEN '”‰œ ﬁÌœ' WHEN E.Guid THEN E.Name ELSE '' END) ParentName,
           0 CanUpdateAmount, 
           (CASE C.TypeGuid WHEN '00000000-0000-0000-0000-000000000000' THEN 1 WHEN E.Guid THEN 1 ELSE 0 END) CanUpdateNotes, 
		   0 Deleted, 0 IsPocketAcc,
		   C.Date Timestamp
	FROM CE000 C LEFT OUTER JOIN ET000 E ON (C.TypeGuid = E.Guid)
	WHERE C.Guid IN (SELECT DISTINCT CEGuid FROM PA_fnGetAmnEntries(@DeviceGUID, @ExpIntervalPocketAcc, @ExpIntervalStatAcc, @SyncDate))
)
#################################################################
CREATE FUNCTION PA_fnGetPACEntries ( @DeviceGUID UNIQUEIDENTIFIER )
RETURNS TABLE
AS
RETURN
(
	SELECT CAST(Number AS FLOAT) Number, GUID, DeviceGUID
      ,Date, Note, CurGuid, CurVal, ParentName
      ,CanUpdateAmount, CanUpdateNotes, Deleted
      ,IsPocketAcc, Timestamp
    FROM PA_CE000
)
#################################################################
CREATE VIEW PA_vwAccount000
AS
SELECT   AC.Number, AC.GUID, AC.AmnGUID, AC.DeviceGuid, AC.AmnName, AC.Type, AC.IsET,
        AC.IsStatmentAcc, AC.InitDebit, AC.InitCredit, AC.Icon, AC.Text, AC.Timestamp
FROM PA_AC000 AC
#################################################################
CREATE VIEW PA_vwCEntries000
AS
SELECT * FROM PA_CE000
#################################################################
CREATE VIEW PA_vwEntries000
AS
SELECT * FROM PA_EN000
#################################################################
CREATE TRIGGER PA_trgVwAccountInsert
ON PA_vwAccount000
INSTEAD OF INSERT
NOT FOR REPLICATION
AS
	INSERT INTO PA_AC000 (Number, GUID, AmnGUID, DeviceGuid, AmnName, Type, IsET,
        IsStatmentAcc, InitDebit, InitCredit, Icon, Text, Timestamp)
   (SELECT Number, GUID, AmnGUID, DeviceGuid, AmnName, Type, IsET,
        IsStatmentAcc, InitDebit, InitCredit, Icon, Text, Timestamp FROM inserted)
#################################################################
CREATE TRIGGER PA_trgVwAccountUpdate
ON PA_vwAccount000
INSTEAD OF UPDATE
NOT FOR REPLICATION
AS
	UPDATE PA_AC000
	SET Number = inserted.Number, AmnGUID = inserted.AmnGuid, 
	    DeviceGuid = inserted.DeviceGuid, AmnName = inserted.AmnName,
	    Type = inserted.Type, IsET = inserted.IsET,
        IsStatmentAcc = inserted.IsStatmentAcc, InitDebit = inserted.InitDebit, 
        InitCredit = inserted.InitCredit, Icon = inserted.Icon, Text = inserted.Text,
        Timestamp = inserted.Timestamp
	FROM inserted
    WHERE 
        PA_AC000.Guid = inserted.Guid
#################################################################
CREATE TRIGGER PA_trgVwAccountDelete
ON PA_vwAccount000
INSTEAD OF DELETE
NOT FOR REPLICATION
AS
	DELETE FROM PA_AC000
    WHERE Guid IN ( SELECT Guid FROM deleted )
#################################################################
CREATE TRIGGER PA_trgVwCEntriesInsert
ON PA_vwCEntries000
INSTEAD OF INSERT
NOT FOR REPLICATION
AS
	INSERT INTO CE000 (Number, Guid, Date, Notes, CurrencyGuid, CurrencyVal)
	(SELECT Number, Guid, Date, Note, CurGuid, CurVal FROM inserted)
#################################################################
CREATE TRIGGER PA_trgVwCEntriesUpdate
ON PA_vwCEntries000
INSTEAD OF UPDATE
NOT FOR REPLICATION
AS
	UPDATE CE000
	SET Number = inserted.Number, Date = inserted.Date, 
        Notes = inserted.Note, CurrencyGuid = inserted.CurGuid,
        CurrencyVal = inserted.CurVal
    FROM inserted
	WHERE CE000.Guid = inserted.Guid
#################################################################
CREATE TRIGGER PA_trgVwCEntriesDelete
ON PA_vwCEntries000
INSTEAD OF DELETE
NOT FOR REPLICATION
AS
	DELETE FROM CE000
    WHERE Guid IN ( SELECT Guid FROM deleted )
#################################################################
CREATE TRIGGER PA_trgVwEntriesInsert
ON PA_vwEntries000
INSTEAD OF INSERT
NOT FOR REPLICATION
AS
	INSERT INTO EN000 (Number, Guid, ParentGuid, AccountGuid, Debit, Credit, Notes, Date)
	(SELECT Number, Guid, CEGuid, AcGuid, Debit, Credit, Note, Timestamp FROM inserted)
#################################################################
CREATE TRIGGER PA_trgVwEntriesUpdate
ON PA_vwEntries000
INSTEAD OF UPDATE
NOT FOR REPLICATION
AS
	UPDATE EN000
	SET Number = inserted.Number, ParentGuid = inserted.CEGuid, 
        AccountGuid = inserted.AcGuid, Debit = inserted.Debit,
        Credit = inserted.Credit, Notes = inserted.Note, Date = inserted.Timestamp
    FROM inserted
	WHERE EN000.Guid = inserted.Guid
#################################################################
CREATE TRIGGER PA_trgVwEntriesDelete
ON PA_vwEntries000
INSTEAD OF DELETE
NOT FOR REPLICATION
AS
	DELETE FROM EN000
    WHERE Guid IN ( SELECT Guid FROM deleted )
#################################################################
#END     

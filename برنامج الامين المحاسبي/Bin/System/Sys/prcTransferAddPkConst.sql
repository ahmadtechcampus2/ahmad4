#######################################################################	
CREATE PROCEDURE prcTransferAddPkConst
AS
	SET NOCOUNT ON
	ALTER TABLE TrnGenerator000 Alter Column SourceBranchGuid Uniqueidentifier NOT NULL 
	ALTER TABLE TrnGenerator000 Alter Column DestBranchGuid Uniqueidentifier NOT NULL 
	ALTER TABLE TrnGenerator000 Alter Column Type Int NOT NULL 
	
	IF NOT EXISTS ( SELECT * FROM   sysobjects WHERE name = 'PK_Trngen_SourceDestType')
		ALTER TABLE TrnGenerator000 ADD CONSTRAINT PK_Trngen_SourceDestType primary Key( SourceBranchGuid, DestBranchGuid, Type)

#######################################################################
#END
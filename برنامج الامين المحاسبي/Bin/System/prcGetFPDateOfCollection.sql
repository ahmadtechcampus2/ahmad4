###############################################
CREATE PROCEDURE prcGetFPDateOfCollection
	@CollectionGUID [UNIQUEIDENTIFIER]
AS

SET NOCOUNT ON
CREATE TABLE [#tmp]
(
	[Guid]					[UNIQUEIDENTIFIER],
	[dbid]					[INT],
	[dbName]				[NVARCHAR](256) COLLATE ARABIC_CI_AI,
	[amnName]				[NVARCHAR](256) COLLATE ARABIC_CI_AI,
	[FPDate]				[DATETIME],
	[EPDate]				[DATETIME],
	[ExcludeEntries]		[INT],
	[ExcludeFPBills]		[INT],
	[InCollection]			[INT],
	[VersionNeedsUpdating]	[INT],
	[UserIsNotDefined]		[INT],
	[PasswordError]			[INT],
	[Order]					[INT]
)

INSERT INTO [#tmp] EXEC [prcDatabase_Collection] @CollectionGUID, 1
SELECT [FPDate] FROM [#tmp] WHERE [Order] = 1
/*
prcGetFPDateOfCollection '82784582-83C9-4CFD-B6B0-7D40C0091C22'
select * from dbc
82784582-83C9-4CFD-B6B0-7D40C0091C22	collection 1
2BA7ACBE-9E90-407C-B487-E4604CB86C26	collection3
84A4932B-6F26-4A19-8BC4-E542438AAAB7	collection2


EXEC prcGetFPDateOfCollection 'f4081683-52a3-41cc-9646-b99db9c79709'
*/
###########################################################
#END
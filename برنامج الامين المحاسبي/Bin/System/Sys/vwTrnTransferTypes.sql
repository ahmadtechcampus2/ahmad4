#########################################################
CREATE VIEW vtTrnTransferTypes
AS
	SELECT * FROM TrnTransferTypes000

#########################################################
CREATE VIEW vbTrnTransferTypes
AS
	SELECT v.*
	FROM vtTrnTransferTypes AS v INNER JOIN fnBranch_GetCurrentUserReadMask(DEFAULT) AS f ON v.branchMask & f.Mask <> 0

#########################################################
CREATE VIEW vcTrnTransferTypes
AS
	SELECT * FROM vbTrnTransferTypes

#########################################################
CREATE VIEW vdTrnTransferTypes
AS
	SELECT * FROM vbTrnTransferTypes

#########################################################
CREATE  VIEW vwTrnTransferTypes
AS  
	SELECT  
		[GUID]					AS [ttGuid], 
		[SortNum]				AS [ttSortNum], 
		[Name]					AS [ttName], 
		[LatinName]				AS [ttLatinName], 
		[Abbrev]				AS [ttAbbrev], 
		[LatinAbbrev]			AS [ttLatinAbbrev], 
		[Type]					AS [ttType], 
		[CalcReturnWages]		AS [ttCalcReturnWages], 
		[bIsLinked]				AS [ttbIsLinked], 
		[bRepeatPrinting]		AS [ttbRepeatPrinting], 
		[PrintType]				AS [ttPrintType], 
		[PayType] 				AS [ttPayType], 
		[WagesTypeGUID]			AS [ttWagesTypeGUID], 
		[WagesType2GUID]		AS [ttWagesType2GUID],
		[RatioTypeGUID]			AS [ttRatioTypeGUID], 
		[SourceBranchGUID]		AS [ttSourceBranchGUID], 
		[DestinationBranchGUID]	AS [ttDestinationBranchGUID], 
		[branchMask]			AS [ttbranchMask],
		[ReturnCapability]		AS [ttReturnCapability],
 		[ReturnTrType]			AS [ttReturnTrType],
		[PrintInternalVoucher]	AS [ttPrintInternalVoucher],
		[PrintVoucher]			AS [ttPrintVoucher],
		[CashAccGuid]			AS	[ttCashAccGuid],
		[PaidAccGuid]			AS	[ttPaidAccGuid],
		[AgentBranchGuid]		AS [ttAgentBranchGuid],
		[SourceOfficeGuid]		AS [ttSourceOfficeGuid],
		[DestinationOfficeGuid]	AS [ttDestinationOfficeGuid],
		[SourceType]			AS [ttSourceType],
		[DestinationType]		AS [ttDestinationType]
	FROM  
		[vbTrnTransferTypes]	
#########################################################	
#END
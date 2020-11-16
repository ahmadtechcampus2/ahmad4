#########################################################
CREATE VIEW vtTrnExchange
AS
	SELECT * FROM [trnExchange000]

#########################################################
CREATE VIEW vbTrnExchange
AS
	SELECT [v].*
	FROM [vtTrnExchange] AS [v] INNER JOIN [vwBr] AS [br] ON [v].[BranchGUID] = [br].[brGUID]

#########################################################
CREATE VIEW vcTrnExchange
AS
	SELECT * FROM [vbTrnExchange]

#########################################################
CREATE VIEW vdTrnExchange
AS
	SELECT * FROM [vbTrnExchange]

#########################################################
CREATE VIEW vwTrnExchange
AS  
	SELECT
		*
	FROM  
		[vbTrnExchange] 

#########################################################	
CREATE VIEW vwTrnExchangeCustomer
AS  
      SELECT
            ex.Number,                
            ex.Guid,                  
            ex.CashAmount,            
            ex.CashCurrency,   
            ex.CashCurrencyVal,
            ex.CashAcc,               
            ex.PayAmount,            
            ex.PayCurrency,   
            ex.PayCurrencyVal,              
            ex.PayAcc,                
            ex.Note,                  
            ex.BranchGuid,            
            ex.[Date],
            ex.TypeGuid,              
            ex.Security,              
            ex.EntryGuid,             
            ex.RoundValue,            
            ex.RoundDir,              
            ex.CustomerType,    
            ex.CashRoundAmount,       
            ex.PayRoundAmount,        
            ex.CashCurBalance,        
            ex.CashAvgVal,            
            ex.PayCurBalance,   
            ex.PayAvgVal,             
            ex.OpType,                
            ex.RoundCurrency,   
            ex.RoundCurrencyVal,
            ISNULL(cu.Name, ex.CustomerName) AS CustomerName,
            ISNULL(cu.IdentityNo, ex.CutomerIdentityNo) AS CutomerIdentityNo,
            ex.CashNote,      
            ex.PayNote,       
            ex.bSimple,       
            ex.EvlCurrency,   
            ex.EvlCurrencyVal,  
            ex.Reason,        
            ex.InternalNumber,      
            ex.CustomerGuid,
            ISNULL(cu.FatherName, '') AS FatherName,
            ISNULL(cu.LastName, '') AS LastName,
            ISNULL(cu.MotherName, '') AS MotherName,
            ISNULL(cu.Nation, '') AS Nation,
            ISNULL(cu.BirthDate, '1980-1-1') AS BirthDate,
            ISNULL(cu.BirthPlace, '') AS BirthPlace,
            ISNULL(cu.Phone, '') AS Phone,
            ISNULL(cu.IdentityType, '') AS IdentityType,
            ISNULL(cu.IdentityDate, '1980-1-1') AS IdentityDate,
            ISNULL(cu.IdentityPlace, '') AS IdentityPlace,
            ISNULL(cu.Address, '') AS [Address],
            ex.CommissionAmount / 
				(CASE WHEN ex.CommissionCurrency = ex.CashCurrency AND ex.CashCurrencyVal <> 0 THEN ex.CashCurrencyVal ELSE 1 END)
				AS CommissionAmount,
            ex.CommissionRatio * 1000 AS CommissionRatio,
            ex.CommissionNet / 
				(CASE WHEN ex.CommissionCurrency = ex.CashCurrency AND ex.CashCurrencyVal <> 0 THEN ex.CashCurrencyVal ELSE 1 END)
				AS CommissionNet,
            ISNULL(commissionMy.Name, '') AS commissionCurrency
FROM  
            vtTrnExchange AS ex 
			LEFT JOIN TrnCustomer000 AS cu ON cu.Guid = ex.CustomerGuid
			LEFT JOIN my000 AS commissionMy ON commissionMy.[GUID] = ex.CommissionCurrency
#########################################################	
CREATE VIEW vwTrnCustomer_relateWithExchange
AS
	SELECT 
		cu.* 
	FROM trnCustomer000 AS cu
	INNER JOIN TrnExchange000 AS ex	ON ex.CustomerGuid = cu.[Guid]
#########################################################	
CREATE FUNCTION fbTrnExchange( 
	@TypeGUID UNIQUEIDENTIFIER, 
	@ShowOthersTransferPermissionRID BIGINT
) RETURNS TABLE
AS
	RETURN 
	(
		SELECT * 
		FROM 
			vtTrnExchange  
		WHERE 
			TypeGUID = @TypeGUID  
			AND bSimple = 1
			And (UserGuid = dbo.fnGetCurrentUserGUID() 
				OR dbo.fnIsAdmin(dbo.fnGetCurrentUserGUID()) = 1
				OR (SELECT permission from ui000 where ReportID = @ShowOthersTransferPermissionRID AND UserGuid = dbo.fnGetCurrentUserGUID()) = 1
				)
	)
#########################################################
CREATE FUNCTION fbTrnExchangeBill
	( @TypeGUID AS UNIQUEIDENTIFIER)
	RETURNS TABLE
	AS
		RETURN 
			(
				SELECT 
					* 
				FROM vtTrnExchange AS ex 
				WHERE TypeGUID = @TypeGUID  AND bSimple = 0
				)
#########################################################
CREATE Function VwTrnMy()
	RETURNS @Result Table 
		([Number] [NVARCHAR] (100) COLLATE Arabic_CI_AI,
		[Code] [NVARCHAR] (100) COLLATE Arabic_CI_AI,
		[Name] [NVARCHAR] (250) COLLATE Arabic_CI_AI ,
		[GUID] [uniqueidentifier])

AS
BEGIN
	insert into @Result
		select 
			[Number],
			[Code],
			[Name],
			[GUID]
		From vdMy
Return 
END	
#########################################################
#END
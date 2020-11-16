#########################################################
CREATE VIEW vwExtended_AC
AS 
	SELECT 
		ac.*,
		ISNULL(t.Debit, 0) AS [CalcDebit],
		ISNULL(t.Credit, 0) AS [CalcCredit]
	FROM  
		[vbAc] ac
		OUTER APPLY (
			SELECT 
				Debit, Credit
			FROM 
				[fnAccount_getDebitCredit]([GUID], [CurrencyGUID]) t
			WHERE 
				ac.[Type] = 1 ) t
#########################################################
CREATE VIEW vwExtended_AC_WithoutPOSSDAcc
AS 
	SELECT 
		AC.*
	FROM 
		vwExtended_AC AC
		LEFT JOIN POSSDStation000 ShiftControlAcc  ON AC.[GUID] = ShiftControlAcc.ShiftControlGUID
		LEFT JOIN POSSDStation000 ContinuesCashAcc ON AC.[GUID] = ContinuesCashAcc.ContinuesCashGUID
	WHERE 
		ShiftControlAcc.ShiftControlGUID   IS NULL
	AND ContinuesCashAcc.ContinuesCashGUID IS NULL
#########################################################	
CREATE FUNCTION fnCust_MainAccount(@AccGuid UNIQUEIDENTIFIER)
RETURNS TABLE 
AS
RETURN (
	SELECT [vdCu2].*
	FROM  [vdCu2] vdCu2  INNER JOIN [fnGetAccountsList](@AccGuid, 0) [f]  on [f].Guid = vdCu2.AccountGUID 
	)
#########################################################	
CREATE FUNCTION fnAccount_CanLinkedToCust(@AccGuid UNIQUEIDENTIFIER, @CustGuid UNIQUEIDENTIFIER = 0x0)
	RETURNS TINYINT
	--0    
	--1 ÇáÍÓÇÈ íÓÊÎÏã ÇáÖÑíÈÉ¡ áÇ íãßä ÑÈØ ÒÈæä ãÚå
	--2 áÇ íãßä ÑÈØ ÇáÍÓÇÈ ãÚ ÒÈæä ÈÓÈÈ æÌæÏ ÍÑßÇÊ Êã ÊÍÏíÏ ÒÈæä ÝíåÇ 
	--3  ÓíÞæã ÇáÈÑäÇãÌ ÈÊÍÏíÏ ÇáÒÈæä ãÞÇÈá ÇáÍÑßÇÊ ÇáÓÇÈÞÉ ááÍÓÇÈ
	--4 áÇ íãßä ÑÈØ ÃßËÑ ãä ÒÈæä ãÚ ÍÓÇÈ æÇÍÏ 
	--5 ÇáÍÓÇÈ ãÑÊÈØ ãÚ ÒÈæä/ÒÈÇÆä¡ åá ÊÑíÏ ÇáÇÓÊãÑÇÑ¿
	--6 áÇ íãßä ÑÈØ åÐÇ ÇáÍÓÇÈ ÈÈØÇÞÉ ÒÈæä
	
AS 
BEGIN 
	IF EXISTS(SELECT GUID FROM ac000 WHERE GUID = @AccGuid AND (type != 1 OR NSons > 0))
		RETURN 6

	IF EXISTS(SELECT GUID FROM cu000 cu WHERE AccountGUID = @AccGuid AND [GUID] = @CustGuid)
		RETURN 0
	-- ÅÐÇ ßÇä äÙÇã ÖÑÇÆÈ ÇáÎáíÌ ãÝÚá æ ÇáÍÓÇÈ åæ ÍÓÇÈ ÖÑíÈÉ 
	DECLARE @IsGCCSystemEnabled INT = dbo.fnOption_GetInt('AmnCfg_EnableGCCTaxSystem', '0');
	DECLARE @IsMultiCustomersEnabled INT = dbo.fnOption_GetInt('AmnCfg_EnableMultiCustomersSystem', '0');
	IF  @IsGCCSystemEnabled = 1 AND  EXISTS (SELECT GUID FROM ac000 WHERE GUID = @AccGuid AND ISNULL(IsUsingAddedValue, 0) != 0)
		RETURN 1

	IF ISNULL(@CustGuid, 0x0) != 0x0
	BEGIN 
		-- ÅÐÇ ßÇä ÇáÒÈæä ãÑÊÈØ ÈÍÓÇÈ ÛíÑ ÇáÍÓÇÈ ÇáãÏÎá æ  áå ÍÑßÇÊ ãÚå   Ýí ÓäÏ ÇáÞíÏ 
		IF EXISTS (SELECT * FROM en000 en
		INNER JOIN cu000 cu ON cu.GUID = CustomerGUID AND CustomerGUID = @CustGuid 
		WHERE cu.AccountGUID = en.AccountGUID  AND cu.AccountGUID != @AccGuid)
			RETURN 6		
	END	

	-- ÅÐÇ ßÇä ÇáÍÓÇÈ ãÑÊÈØ ÈÚÏÉ ÒÈÇÆä 
	IF EXISTS (SELECT * FROM vwAcCu WHERE GUID = @AccGuid AND CustomersCount > 0)
			RETURN IIF(@IsMultiCustomersEnabled = 1 ,5,4)

	--  ÅÐÇ ßÇä ÇáÍÓÇÈ áå ÍÑßÇÊ ãÚ   ÓäÏ ÇáÞíÏ æ ÊÚÏÏ ÇáÒÈÇÆä ãÝÚá
	IF @IsMultiCustomersEnabled = 1 AND EXISTS (SELECT GUID FROM en000 WHERE AccountGUID = @AccGuid AND CustomerGuid != 0x0)
		RETURN 2
	ELSE IF EXISTS (SELECT GUID FROM en000 WHERE AccountGUID = @AccGuid  
					UNION ALL
					SELECT GUID FROM bu000 WHERE CustAccGUID = @AccGuid AND CustGUID = 0x0
					UNION ALL 
					SELECT GUID FROM ch000 WHERE AccountGuid = @AccGuid 
					UNION ALL
					SELECT GUID FROM Allocations000 WHERE AccountGuid = @AccGuid   OR CounterAccountGuid =   @AccGuid)
		RETURN 3

	RETURN 0
END
#########################################################	
CREATE FUNCTION fnMultiCustomersSystem_GetState()
	RETURNS TINYINT
	-- 0: ready to enable / disable 
	-- 1: there are accounts related to multi customers /*not ready to disable*/ 
	-- 2: there are accounts moved with not related customers /*not ready to disable*/ 
AS
BEGIN 
	IF EXISTS (SELECT * FROM vwAcCu WHERE CustomersCount > 1)
		RETURN 1

	IF EXISTS (
		SELECT * 
		FROM 
			en000 en
			INNER JOIN ac000 ac ON ac.GUID = en.AccountGUID 
			INNER JOIN cu000 cu ON cu.GUID = en.CustomerGUID 
			INNER JOIN ce000 ce ON ce.GUID = en.ParentGUID
			LEFT JOIN er000 er ON ce.GUID = er.EntryGUID 
			LEFT JOIN bu000 bu ON bu.GUID = er.ParentGUID 			
		WHERE 
			(cu.AccountGUID != ac.GUID)	
			AND 
			((bu.GUID IS NULL) OR ((bu.GUID IS NOT NULL) AND ((bu.PayType != 0) OR (ac.GUID != bu.CustAccGUID)))))
		RETURN 2	

	RETURN 0
END
###########################################################################
CREATE VIEW vwManualEntryAccountWithoutBalance
AS
	
	SELECT 
		AC.*
	FROM 
		vdAc_WithoutPOSSDAcc AC
		LEFT JOIN ManualEntryAccount000 ME ON AC.GUID = ME.AccountGuid
	WHERE
		ME.AccountGuid IS NULL
###########################################################################
CREATE VIEW vwManualEntryAccountWithBalance
AS

	SELECT 
		AC.*
	FROM 
		vwExtended_AC_WithoutPOSSDAcc AC
		LEFT JOIN ManualEntryAccount000 ME ON AC.GUID = ME.AccountGuid
	WHERE
		ME.AccountGuid IS NULL
###########################################################################
#END
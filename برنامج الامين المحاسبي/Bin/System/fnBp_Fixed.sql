####################################################################################
CREATE FUNCTION fnBpDebt_Fixed( @CurGUID [UNIQUEIDENTIFIER], @CurVal [FLOAT])
RETURNS TABLE
AS
RETURN(
		SELECT 
			[BpDebtGUID],
			SUM ( [dbo].[fnCurrency_fix]( [BpVal], [bpCurrencyGUID], [bpCurrencyVal], @CurGUID, DEFAULT)) AS [FixedBpVal]
		FROM 
			[vwBp]
		GROUP BY
			[BpDebtGUID])
####################################################################################
CREATE FUNCTION fnBpPay_Fixed( @CurGUID [UNIQUEIDENTIFIER], @CurVal [FLOAT])
RETURNS TABLE
AS
RETURN(
		SELECT 
			[BpPayGUID],
			SUM ( [dbo].[fnCurrency_fix]( [BpVal], [bpCurrencyGUID], [bpCurrencyVal], @CurGUID, DEFAULT)) AS [FixedBpVal]
		FROM 
			[vwBp]
		GROUP BY
			[BpPayGUID])
####################################################################################
CREATE FUNCTION fnBp_Fixed( @CurGUID [UNIQUEIDENTIFIER], @CurVal [FLOAT])
RETURNS TABLE
AS
RETURN(
		SELECT 
			[BpGUID], 
			[BpDebtGUID], 
			[BpPayGUID], 
			[BpPayType], 
			[BpVal], 
			[BpCurrencyGUID], 
			[BpCurrencyVal], 
			[BpRecType],
			[BpDebitType],
			[dbo].[fnCurrency_fix]( [BpVal], [bpCurrencyGUID], [bpCurrencyVal], @CurGUID, DEFAULT) AS [FixedBpVal],
			Bptype as bptype
		FROM 
			[vwBp])
####################################################################################
CREATE FUNCTION fnBpDebt_Fixed2( @CurGUID [UNIQUEIDENTIFIER], @CurVal [FLOAT])
RETURNS TABLE
AS
RETURN(
		SELECT 
			[BpDebtGUID],
			SUM ( [dbo].[fnCurrency_fix]( [BpVal], [bpCurrencyGUID], [bpCurrencyVal], @CurGUID, DEFAULT)) AS [FixedBpVal]
		FROM 
			[vwBp]
		WHERE Bptype <> 4
		GROUP BY
			[BpDebtGUID])
######################################################################################
CREATE FUNCTION fnBpPay_Fixed2( @CurGUID [UNIQUEIDENTIFIER], @CurVal [FLOAT])
RETURNS TABLE
AS
RETURN(
		SELECT 
			[BpPayGUID],
			SUM ( [dbo].[fnCurrency_fix]( [BpVal], [bpCurrencyGUID], [bpCurrencyVal], @CurGUID, DEFAULT)) AS [FixedBpVal]
		FROM 
			[vwBp]
		where Bptype <> 4
		GROUP BY
			[BpPayGUID])
######################################################################################
#END

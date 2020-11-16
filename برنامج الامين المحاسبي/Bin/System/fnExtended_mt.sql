#########################################################
CREATE FUNCTION fnExtended_mt(@PriceType [INT], @PricePolicy [INT], @UseUnit [INT])
	RETURNS TABLE
AS
	RETURN
		(SELECT
			*,
			(CASE [mtPriceType]
				WHEN 15 THEN ( CASE @PriceType
						WHEN 2 THEN ( CASE @PricePolicy
								WHEN 120 THEN (CASE @UseUnit
										WHEN 0 THEN [mtMaxPrice]
										WHEN 1 THEN CASE [mtUnit2Fact] WHEN 0 THEN [mtMaxPrice] ELSE [mtMaxPrice2] END
										WHEN 2 THEN CASE [mtUnit3Fact] WHEN 0 THEN [mtMaxPrice] ELSE [mtMaxPrice3] END
										ELSE ( CASE [mtDefUnit]
											WHEN 1 THEN [mtMaxPrice]
											WHEN 2 THEN [mtMaxPrice2]
											ELSE [mtMaxPrice3]
											END)
										END)
									WHEN 121 THEN (CASE @UseUnit 
											WHEN 0 THEN [mtAvgPrice] 
											WHEN 1 THEN [mtAvgPrice] * CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE [mtUnit2Fact] END
											WHEN 2 THEN [mtAvgPrice] * CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE [mtUnit3Fact] END
											ELSE [mtAvgPrice] * CASE [mtDefUnitFact] WHEN 0 THEN 1 ELSE [mtDefUnitFact] END
										 END)	
									WHEN 122 THEN (CASE @UseUnit
											WHEN 0 THEN [mtLastPrice]
											WHEN 1 THEN CASE [mtUnit2Fact] WHEN 0 THEN [mtLastPrice] ELSE [mtLastPrice2] END
											WHEN 2 THEN CASE [mtUnit3Fact] WHEN 0 THEN [mtLastPrice] ELSE  [mtLastPrice3] END
											ELSE ( CASE [mtDefUnit]
												WHEN 1 THEN [mtLastPrice]
												WHEN 2 THEN [mtLastPrice2]
												ELSE [mtLastPrice3]
												END)
											END)
									ELSE (CASE @UseUnit
											WHEN 0 THEN [mtMaxPrice]
											WHEN 1 THEN  CASE [mtUnit2Fact] WHEN 0 THEN [mtMaxPrice] ELSE [mtMaxPrice2] END
											WHEN 2 THEN CASE [mtUnit3Fact] WHEN 0 THEN [mtMaxPrice] ELSE [mtMaxPrice3] END
											ELSE ( CASE [mtDefUnit]
												WHEN 1 THEN [mtMaxPrice]
												WHEN 2 THEN [mtMaxPrice2]
												ELSE [mtMaxPrice3]
												END)
											END)
									END)
						WHEN 4 THEN (CASE @UseUnit
								WHEN 0 THEN [mtWhole]
								WHEN 1 THEN CASE [mtUnit2Fact] WHEN 0 THEN [mtWhole] ELSE [mtWhole2] END
								WHEN 2 THEN CASE [mtUnit3Fact] WHEN 0 THEN [mtWhole] ELSE [mtWhole3] END
								ELSE ( CASE [mtDefUnit]
									WHEN 1 THEN [mtWhole]
									WHEN 2 THEN [mtWhole2]
									ELSE [mtWhole3]
									END)
								END)
						WHEN 8 THEN (CASE @UseUnit
								WHEN 0 THEN [mtHalf]
								WHEN 1 THEN CASE [mtUnit2Fact] WHEN 0 THEN [mtHalf] ELSE [mtHalf2] END
								WHEN 2 THEN CASE [mtUnit3Fact] WHEN 0 THEN [mtHalf] ELSE [mtHalf3] END
								ELSE ( CASE [mtDefUnit]
									WHEN 1 THEN [mtHalf]
									WHEN 2 THEN [mtHalf2]
									ELSE [mtHalf3]
									END)
								END)
						WHEN 16 THEN (CASE @UseUnit
								WHEN 0 THEN [mtExport]
								WHEN 1 THEN CASE [mtUnit2Fact] WHEN 0 THEN [mtExport] ELSE  [mtExport2] END
								WHEN 2 THEN CASE [mtUnit3Fact] WHEN 0 THEN [mtExport] ELSE  [mtExport3] END
								ELSE ( CASE [mtDefUnit]
									WHEN 1 THEN [mtExport]
									WHEN 2 THEN [mtExport2]
									ELSE [mtExport3]
									END)
								END)
						WHEN 32 THEN (CASE @UseUnit
								WHEN 0 THEN [mtVendor]
								WHEN 1 THEN CASE [mtUnit2Fact] WHEN 0 THEN [mtVendor] ELSE [mtVendor2] END
								WHEN 2 THEN CASE [mtUnit3Fact] WHEN 0 THEN [mtVendor] ELSE [mtVendor3] END
								ELSE ( CASE [mtDefUnit]
									WHEN 1 THEN [mtVendor]
									WHEN 2 THEN [mtVendor2]
									ELSE [mtVendor3]
									END)
								END)
						WHEN 64 THEN (CASE @UseUnit
								WHEN 0 THEN [mtRetail]
								WHEN 1 THEN CASE [mtUnit2Fact] WHEN 0 THEN [mtRetail] ELSE  [mtRetail2] END
								WHEN 2 THEN CASE [mtUnit3Fact] WHEN 0 THEN [mtRetail] ELSE [mtRetail3] END
								ELSE ( CASE [mtDefUnit]
									WHEN 1 THEN [mtRetail]
									WHEN 2 THEN [mtRetail2]
									ELSE [mtRetail3]
									END)
								END)
						ELSE (CASE @UseUnit
							WHEN 0 THEN [mtEndUser]
							WHEN 1 THEN CASE [mtUnit2Fact] WHEN 0 THEN [mtEndUser] ELSE [mtEndUser2] END
							WHEN 2 THEN CASE [mtUnit3Fact] WHEN 0 THEN [mtEndUser] ELSE [mtEndUser3] END
							ELSE ( CASE [mtDefUnit]
								WHEN 1 THEN [mtEndUser]
								WHEN 2 THEN [mtEndUser2]
								ELSE [mtEndUser3]
								END)
							END)
						END)
				ELSE
					(CASE @PriceType
						WHEN 2 THEN (CASE @PricePolicy
								WHEN 120 THEN (CASE @UseUnit
										WHEN 0 THEN [MP_mtCostPrice]
										WHEN 1 THEN CASE [mtUnit2Fact] WHEN 0 THEN [MP_mtCostPrice] ELSE [MP_mtCostPrice2] END
										WHEN 2 THEN CASE [mtUnit3Fact] WHEN 0 THEN [MP_mtCostPrice] ELSE [MP_mtCostPrice3] END
										ELSE ( CASE [mtDefUnit]
											WHEN 1 THEN [MP_mtCostPrice]
											WHEN 2 THEN [MP_mtCostPrice2]
											ELSE [MP_mtCostPrice3]
											END)
										END)
								WHEN 121 THEN (CASE @UseUnit
										WHEN 0 THEN [AP_mtCostPrice]
										WHEN 1 THEN CASE [mtUnit2Fact] WHEN 0 THEN [AP_mtCostPrice] ELSE [AP_mtCostPrice2] END
										WHEN 2 THEN CASE [mtUnit3Fact] WHEN 0 THEN [AP_mtCostPrice] ELSE [AP_mtCostPrice3] END
										ELSE ( CASE [mtDefUnit]
											WHEN 1 THEN [AP_mtCostPrice]
											WHEN 2 THEN [AP_mtCostPrice2]
											ELSE [AP_mtCostPrice3]
											END)
										END)
								WHEN 122 THEN (CASE @UseUnit
										WHEN 0 THEN [LP_mtCostPrice]
										WHEN 1 THEN CASE [mtUnit2Fact] WHEN 0 THEN [LP_mtCostPrice] ELSE [LP_mtCostPrice2] END
										WHEN 2 THEN CASE [mtUnit3Fact] WHEN 0 THEN [LP_mtCostPrice] ELSE [LP_mtCostPrice3] END
										ELSE ( CASE [mtDefUnit]
											WHEN 1 THEN [LP_mtCostPrice]
											WHEN 2 THEN [LP_mtCostPrice2]
											ELSE [LP_mtCostPrice3]
											END)
										END)
								ELSE (CASE [mtPriceType]
									WHEN 120 THEN (CASE @UseUnit
											WHEN 0 THEN [MP_mtCostPrice]
											WHEN 1 THEN [MP_mtCostPrice2]
											WHEN 2 THEN [MP_mtCostPrice3]
											ELSE ( CASE [mtDefUnit]												WHEN 1 THEN MP_mtCostPrice
												WHEN 2 THEN [MP_mtCostPrice2]
												ELSE [MP_mtCostPrice3]
												END)
											END)
									WHEN 121 THEN (CASE @UseUnit
											WHEN 0 THEN [AP_mtCostPrice]
											WHEN 1 THEN [AP_mtCostPrice2]
											WHEN 2 THEN [AP_mtCostPrice3]
											ELSE ( CASE [mtDefUnit]
												WHEN 1 THEN [AP_mtCostPrice]
												WHEN 2 THEN [AP_mtCostPrice2]
												ELSE [AP_mtCostPrice3]
												END)
											END)
									WHEN 122 THEN (CASE @UseUnit
											WHEN 0 THEN [LP_mtCostPrice]
											WHEN 1 THEN [LP_mtCostPrice2]
											WHEN 2 THEN [LP_mtCostPrice3]
											ELSE ( CASE [mtDefUnit]
												WHEN 1 THEN [LP_mtCostPrice]
												WHEN 2 THEN [LP_mtCostPrice2]
												ELSE [LP_mtCostPrice3]
												END)
											END)
									ELSE (CASE @UseUnit
											WHEN 0 THEN [MP_mtCostPrice]
											WHEN 1 THEN [MP_mtCostPrice2]
											WHEN 2 THEN [MP_mtCostPrice3]
											ELSE ( CASE [mtDefUnit]
												WHEN 1 THEN [MP_mtCostPrice]
												WHEN 2 THEN [MP_mtCostPrice2]
												ELSE [MP_mtCostPrice3]
												END)
											END)
									END)
								END)
						WHEN 4 THEN (CASE @PricePolicy
								WHEN 120 THEN (CASE @UseUnit
										WHEN 0 THEN [MP_mtWhole]
										WHEN 1 THEN [MP_mtWhole2]
										WHEN 2 THEN [MP_mtWhole3]
										ELSE ( CASE [mtDefUnit]
											WHEN 1 THEN [MP_mtWhole]
											WHEN 2 THEN [MP_mtWhole2]
											ELSE [MP_mtWhole3]
											END)
										END)
								WHEN 121 THEN (CASE @UseUnit
										WHEN 0 THEN [AP_mtWhole]
										WHEN 1 THEN [AP_mtWhole2]
										WHEN 2 THEN [AP_mtWhole3]
										ELSE ( CASE [mtDefUnit]
											WHEN 1 THEN [AP_mtWhole]
											WHEN 2 THEN [AP_mtWhole2]
											ELSE [AP_mtWhole3]
											END)
										END)
								WHEN 122 THEN (CASE @UseUnit
										WHEN 0 THEN [LP_mtWhole]
										WHEN 1 THEN [LP_mtWhole2]
										WHEN 2 THEN [LP_mtWhole3]
										ELSE ( CASE [mtDefUnit]
											WHEN 1 THEN [LP_mtWhole]
											WHEN 2 THEN [LP_mtWhole2]
											ELSE [LP_mtWhole3]
											END)
										END)
								ELSE (CASE mtPriceType
									WHEN 120 THEN (CASE @UseUnit
											WHEN 0 THEN [MP_mtWhole]
											WHEN 1 THEN [MP_mtWhole2]
											WHEN 2 THEN [MP_mtWhole3]
											ELSE ( CASE [mtDefUnit]
												WHEN 1 THEN [MP_mtWhole]
												WHEN 2 THEN [MP_mtWhole2]
												ELSE [MP_mtWhole3]
												END)
											END)
	 								WHEN 121 THEN (CASE @UseUnit
											WHEN 0 THEN [AP_mtWhole]
											WHEN 1 THEN [AP_mtWhole2]
											WHEN 2 THEN [AP_mtWhole3]
											ELSE ( CASE [mtDefUnit]
												WHEN 1 THEN [AP_mtWhole]
												WHEN 2 THEN [AP_mtWhole2]
												ELSE [AP_mtWhole3]
												END)
											END)
									WHEN 122 THEN  (CASE @UseUnit
											WHEN 0 THEN [LP_mtWhole]
											WHEN 1 THEN [LP_mtWhole2]
											WHEN 2 THEN [LP_mtWhole3]
											ELSE ( CASE [mtDefUnit]
												WHEN 1 THEN [LP_mtWhole]
												WHEN 2 THEN [LP_mtWhole2]
												ELSE [LP_mtWhole3]
												END)
											END)
									ELSE (CASE @UseUnit
											WHEN 0 THEN [MP_mtWhole]
											WHEN 1 THEN [MP_mtWhole2]
											WHEN 2 THEN [MP_mtWhole3]
											ELSE ( CASE [mtDefUnit]
												WHEN 1 THEN [MP_mtWhole]
												WHEN 2 THEN [MP_mtWhole2]
												ELSE [MP_mtWhole3]
												END)
											END)
									END)
								END)
						WHEN 8 THEN (CASE @PricePolicy
								WHEN 120 THEN (CASE @UseUnit
										WHEN 0 THEN [MP_mtHalf]
										WHEN 1 THEN [MP_mtHalf2]
										WHEN 2 THEN [MP_mtHalf3]
										ELSE ( CASE [mtDefUnit]
											WHEN 1 THEN [MP_mtHalf]
											WHEN 2 THEN [MP_mtHalf2]
											ELSE [MP_mtHalf3]
											END)
										END)
								WHEN 121 THEN (CASE @UseUnit
										WHEN 0 THEN [AP_mtHalf]
										WHEN 1 THEN [AP_mtHalf2]
										WHEN 2 THEN [AP_mtHalf3]
										ELSE ( CASE [mtDefUnit]
											WHEN 1 THEN [AP_mtHalf]
											WHEN 2 THEN [AP_mtHalf2]
											ELSE [AP_mtHalf3]
											END)
										END)
								WHEN 122 THEN (CASE @UseUnit
										WHEN 0 THEN [LP_mtHalf]
										WHEN 1 THEN [LP_mtHalf2]
										WHEN 2 THEN [LP_mtHalf3]
										ELSE ( CASE [mtDefUnit]
											WHEN 1 THEN [LP_mtHalf]
											WHEN 2 THEN [LP_mtHalf2]
											ELSE [LP_mtHalf3]
											END)
										END)
								ELSE (CASE [mtPriceType]
									WHEN 120 THEN (CASE @UseUnit
											WHEN 0 THEN [MP_mtHalf]
											WHEN 1 THEN [MP_mtHalf2]
											WHEN 2 THEN [MP_mtHalf3]
											ELSE ( CASE [mtDefUnit]
												WHEN 1 THEN [MP_mtHalf]
												WHEN 2 THEN [MP_mtHalf2]
												ELSE [MP_mtHalf3]
												END)
											END)
									WHEN 121 THEN (CASE @UseUnit
											WHEN 0 THEN [AP_mtHalf]
											WHEN 1 THEN [AP_mtHalf2]
											WHEN 2 THEN [AP_mtHalf3]
											ELSE ( CASE [mtDefUnit]
												WHEN 1 THEN [AP_mtHalf]
												WHEN 2 THEN [AP_mtHalf2]
												ELSE [AP_mtHalf3]
												END)
											END)
									WHEN 122 THEN (CASE @UseUnit
											WHEN 0 THEN [LP_mtHalf]
											WHEN 1 THEN [LP_mtHalf2]
											WHEN 2 THEN [LP_mtHalf3]
											ELSE ( CASE [mtDefUnit]
												WHEN 1 THEN [LP_mtHalf]
												WHEN 2 THEN [LP_mtHalf2]
												ELSE [LP_mtHalf3]
												END)
											END)
									ELSE (CASE @UseUnit
										WHEN 0 THEN [MP_mtHalf]
										WHEN 1 THEN [MP_mtHalf2]
										WHEN 2 THEN [MP_mtHalf3]
										ELSE ( CASE [mtDefUnit]
											WHEN 1 THEN [MP_mtHalf]
											WHEN 2 THEN [MP_mtHalf2]
											ELSE [MP_mtHalf3]
											END)
										END)
									END)
								END)
						WHEN 16 THEN (CASE @PricePolicy
								WHEN 120 THEN (CASE @UseUnit
										WHEN 0 THEN [MP_mtExport]
										WHEN 1 THEN [MP_mtExport2]
										WHEN 2 THEN [MP_mtExport3]
										ELSE ( CASE [mtDefUnit]
											WHEN 1 THEN [MP_mtExport]
											WHEN 2 THEN [MP_mtExport2]
											ELSE [MP_mtExport3]
											END)
										END)
								WHEN 121 THEN (CASE @UseUnit
										WHEN 0 THEN [AP_mtExport]
										WHEN 1 THEN [AP_mtExport2]
										WHEN 2 THEN [AP_mtExport3]
										ELSE ( CASE [mtDefUnit]
											WHEN 1 THEN [AP_mtExport]
											WHEN 2 THEN [AP_mtExport2]
											ELSE [AP_mtExport3]
											END)
										END)
								WHEN 122 THEN (CASE @UseUnit
										WHEN 0 THEN [LP_mtExport]
										WHEN 1 THEN [LP_mtExport2]
										WHEN 2 THEN [LP_mtExport3]
										ELSE ( CASE [mtDefUnit]
											WHEN 1 THEN [LP_mtExport]
											WHEN 2 THEN [LP_mtExport2]
											ELSE [LP_mtExport3]
											END)
										END)
								ELSE (CASE [mtPriceType]
									WHEN 120 THEN (CASE @UseUnit
											WHEN 0 THEN [MP_mtExport]
											WHEN 1 THEN [MP_mtExport2]
											WHEN 2 THEN [MP_mtExport3]
											ELSE ( CASE [mtDefUnit]
												WHEN 1 THEN [MP_mtExport]
												WHEN 2 THEN [MP_mtExport2]
												ELSE [MP_mtExport3]
												END)
											END)
									WHEN 121 THEN (CASE @UseUnit
											WHEN 0 THEN [AP_mtExport]
											WHEN 1 THEN [AP_mtExport2]
											WHEN 2 THEN [AP_mtExport3]
											ELSE ( CASE [mtDefUnit]
												WHEN 1 THEN [AP_mtExport]
												WHEN 2 THEN [AP_mtExport2]
												ELSE [AP_mtExport3]
												END)
											END)
									WHEN 122 THEN (CASE @UseUnit
											WHEN 0 THEN [LP_mtExport]
											WHEN 1 THEN [LP_mtExport2]
											WHEN 2 THEN [LP_mtExport3]
											ELSE ( CASE [mtDefUnit]
												WHEN 1 THEN [LP_mtExport]
												WHEN 2 THEN [LP_mtExport2]
												ELSE [LP_mtExport3]
												END)
											END)
									ELSE (CASE @UseUnit
										WHEN 0 THEN [MP_mtExport]
										WHEN 1 THEN [MP_mtExport2]
										WHEN 2 THEN [MP_mtExport3]
										ELSE ( CASE [mtDefUnit]
											WHEN 1 THEN [MP_mtExport]
											WHEN 2 THEN [MP_mtExport2]
											ELSE [MP_mtExport3]
											END)
										END)
									END)
								END)
						WHEN 32 THEN (CASE @PricePolicy
								WHEN 120 THEN (CASE @UseUnit
										WHEN 0 THEN [MP_mtVendor]
										WHEN 1 THEN [MP_mtVendor2]
										WHEN 2 THEN [MP_mtVendor3]
										ELSE ( CASE [mtDefUnit]
											WHEN 1 THEN [MP_mtVendor]
											WHEN 2 THEN [MP_mtVendor2]
											ELSE [MP_mtVendor3]
											END)
										END)
								WHEN 121 THEN (CASE @UseUnit
										WHEN 0 THEN [AP_mtVendor]
										WHEN 1 THEN [AP_mtVendor2]
										WHEN 2 THEN [AP_mtVendor3]
										ELSE ( CASE [mtDefUnit]
											WHEN 1 THEN [AP_mtVendor]
											WHEN 2 THEN [AP_mtVendor2]
											ELSE [AP_mtVendor3]
											END)
										END)
								WHEN 122 THEN (CASE @UseUnit
										WHEN 0 THEN [LP_mtVendor]
										WHEN 1 THEN [LP_mtVendor2]
										WHEN 2 THEN [LP_mtVendor3]
										ELSE ( CASE [mtDefUnit]
											WHEN 1 THEN [LP_mtVendor]
											WHEN 2 THEN [LP_mtVendor2]
											ELSE [LP_mtVendor3]
											END)
										END)
								ELSE (CASE mtPriceType
									WHEN 120 THEN (CASE @UseUnit
											WHEN 0 THEN [MP_mtVendor]
											WHEN 1 THEN [MP_mtVendor2]
											WHEN 2 THEN [MP_mtVendor3]
											ELSE ( CASE [mtDefUnit]
												WHEN 1 THEN [MP_mtVendor]
												WHEN 2 THEN [MP_mtVendor2]
												ELSE [MP_mtVendor3]
												END)
											END)
									WHEN 121 THEN (CASE @UseUnit
											WHEN 0 THEN [AP_mtVendor]
											WHEN 1 THEN [AP_mtVendor2]
											WHEN 2 THEN [AP_mtVendor3]
											ELSE ( CASE [mtDefUnit]
												WHEN 1 THEN [AP_mtVendor]
												WHEN 2 THEN [AP_mtVendor2]
												ELSE [AP_mtVendor3]
												END)
											END)
									WHEN 122 THEN (CASE @UseUnit
											WHEN 0 THEN [LP_mtVendor]
											WHEN 1 THEN [LP_mtVendor2]
											WHEN 2 THEN [LP_mtVendor3]
											ELSE ( CASE [mtDefUnit]
												WHEN 1 THEN [LP_mtVendor]
												WHEN 2 THEN [LP_mtVendor2]
												ELSE [LP_mtVendor3]
												END)
											END)
									ELSE (CASE @UseUnit
										WHEN 0 THEN [MP_mtVendor]
										WHEN 1 THEN [MP_mtVendor2]
										WHEN 2 THEN [MP_mtVendor3]
										ELSE ( CASE [mtDefUnit]
											WHEN 1 THEN [MP_mtVendor]
											WHEN 2 THEN [MP_mtVendor2]
											ELSE [MP_mtVendor3]
											END)
										END)
									END)
								END)
						WHEN 64 THEN (CASE @PricePolicy
								WHEN 120 THEN (CASE @UseUnit
										WHEN 0 THEN [MP_mtRetail]
										WHEN 1 THEN [MP_mtRetail2]
										WHEN 2 THEN [MP_mtRetail3]
										ELSE ( CASE [mtDefUnit]
											WHEN 1 THEN [MP_mtRetail]
											WHEN 2 THEN [MP_mtRetail2]
											ELSE [MP_mtRetail3]
											END)
										END)
								WHEN 121 THEN (CASE @UseUnit
										WHEN 0 THEN [AP_mtRetail]
										WHEN 1 THEN [AP_mtRetail2]
										WHEN 2 THEN [AP_mtRetail3]
										ELSE ( CASE [mtDefUnit]
											WHEN 1 THEN [AP_mtRetail]
											WHEN 2 THEN [AP_mtRetail2]
											ELSE [AP_mtRetail3]
											END)
										END)
								WHEN 122 THEN (CASE @UseUnit
										WHEN 0 THEN [LP_mtRetail]
										WHEN 1 THEN [LP_mtRetail2]
										WHEN 2 THEN [LP_mtRetail3]
										ELSE ( CASE [mtDefUnit]
											WHEN 1 THEN [LP_mtRetail]
											WHEN 2 THEN [LP_mtRetail2]
											ELSE [LP_mtRetail3]
											END)
										END)
								ELSE (CASE [mtPriceType]
										WHEN 120 THEN (CASE @UseUnit
												WHEN 0 THEN [MP_mtRetail]
												WHEN 1 THEN [MP_mtRetail2]
												WHEN 2 THEN [MP_mtRetail3]
												ELSE ( CASE [mtDefUnit]
													WHEN 1 THEN [MP_mtRetail]
													WHEN 2 THEN [MP_mtRetail2]
													ELSE [MP_mtRetail3]
													END)
												END)
										WHEN 121 THEN (CASE @UseUnit
												WHEN 0 THEN [AP_mtRetail]
												WHEN 1 THEN [AP_mtRetail2]
												WHEN 2 THEN [AP_mtRetail3]
												ELSE ( CASE [mtDefUnit]
													WHEN 1 THEN [AP_mtRetail]
													WHEN 2 THEN [AP_mtRetail2]
													ELSE [AP_mtRetail3]
													END)
												END)
										WHEN 122 THEN (CASE @UseUnit
												WHEN 0 THEN [LP_mtRetail]
												WHEN 1 THEN [LP_mtRetail2]
												WHEN 2 THEN [LP_mtRetail3]
												ELSE ( CASE [mtDefUnit]
													WHEN 1 THEN [LP_mtRetail]
													WHEN 2 THEN [LP_mtRetail2]
													ELSE [LP_mtRetail3]
													END)
												END)
										ELSE (CASE @UseUnit
											WHEN 0 THEN [MP_mtRetail]
											WHEN 1 THEN [MP_mtRetail2]
											WHEN 2 THEN [MP_mtRetail3]
											ELSE ( CASE [mtDefUnit]
												WHEN 1 THEN [MP_mtRetail]
												WHEN 2 THEN [MP_mtRetail2]
												ELSE [MP_mtRetail3]
												END)
											END)
										END)
								END)
						ELSE (CASE @PricePolicy
							WHEN 120 THEN (CASE @UseUnit
									WHEN 0 THEN [MP_mtEndUser]
									WHEN 1 THEN [MP_mtEndUser2]
									WHEN 2 THEN [MP_mtEndUser3]
									ELSE ( CASE [mtDefUnit]
										WHEN 1 THEN [MP_mtEndUser]
										WHEN 2 THEN [MP_mtEndUser2]
										ELSE [MP_mtEndUser3]
										END)
									END)
							WHEN 121 THEN (CASE @UseUnit
									WHEN 0 THEN [AP_mtEndUser]
									WHEN 1 THEN [AP_mtEndUser2]
									WHEN 2 THEN [AP_mtEndUser3]
									ELSE ( CASE [mtDefUnit]
										WHEN 1 THEN [AP_mtEndUser]
										WHEN 2 THEN [AP_mtEndUser2]
										ELSE [AP_mtEndUser3]
										END)
									END)
							WHEN 122 THEN (CASE @UseUnit
									WHEN 0 THEN [LP_mtEndUser]
									WHEN 1 THEN [LP_mtEndUser2]
									WHEN 2 THEN [LP_mtEndUser3]
									ELSE ( CASE [mtDefUnit]
										WHEN 1 THEN [LP_mtEndUser]
										WHEN 2 THEN [LP_mtEndUser2]
										ELSE [LP_mtEndUser3]
										END)
									END)
							ELSE (CASE [mtPriceType]
								WHEN 120 THEN (CASE @UseUnit
										WHEN 0 THEN [MP_mtEndUser]
										WHEN 1 THEN [MP_mtEndUser2]
										WHEN 2 THEN [MP_mtEndUser3]
										ELSE ( CASE [mtDefUnit]
											WHEN 1 THEN [MP_mtEndUser]
											WHEN 2 THEN [MP_mtEndUser2]
											ELSE [MP_mtEndUser3]
											END)
										END)
								WHEN 121 THEN (CASE @UseUnit
										WHEN 0 THEN [AP_mtEndUser]
										WHEN 1 THEN [AP_mtEndUser2]
										WHEN 2 THEN [AP_mtEndUser3]
										ELSE ( CASE [mtDefUnit]
											WHEN 1 THEN [AP_mtEndUser]
											WHEN 2 THEN [AP_mtEndUser2]
											ELSE [AP_mtEndUser3]
											END)
										END)
								WHEN 122 THEN (CASE @UseUnit
										WHEN 0 THEN [LP_mtEndUser]
										WHEN 1 THEN [LP_mtEndUser2]
										WHEN 2 THEN [LP_mtEndUser3]
										ELSE ( CASE [mtDefUnit]
											WHEN 1 THEN [LP_mtEndUser]
											WHEN 2 THEN [LP_mtEndUser2]
											ELSE [LP_mtEndUser3]
											END)
										END)
								ELSE (CASE @UseUnit
									WHEN 0 THEN [MP_mtEndUser]
									WHEN 1 THEN [MP_mtEndUser2]
									WHEN 2 THEN [MP_mtEndUser3]
									ELSE ( CASE [mtDefUnit]
										WHEN 1 THEN [MP_mtEndUser]
										WHEN 2 THEN [MP_mtEndUser2]
										ELSE [MP_mtEndUser3]
										END)
									END)
								 END)
							END)
						END)
				END) AS [Price]
		FROM
			[vwExtended_mt])

#########################################################
#END
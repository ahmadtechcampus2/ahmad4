###############################################################################
CREATE procedure prcOrder_genBills
	@orderGuid [uniqueidentifier]   
AS    
	declare @OrState as int 
	Select @OrState = OrderState from [or000] where [guid] = @orderGuid  
	if( @OrState = 2) 
		return 0 
	begin tran     
	-- @t_oi table:     
	declare @t_oi table(     
				[number] [int],     
				[qty] [float],     
				[unity] [int],     
				[price] [float],     
				[discount] [float],     
				[notes] [NVARCHAR](250) collate arabic_ci_ai,     
				[expireDate] [datetime],     
				[productionDate] [datetime],     
				[length] [float],     
				[width] [float],     
				[height] [float],     
				[extraAmount] [float], --vat     
				[extraRatio] [float], -- vatRatio     
				[matGUID] [uniqueidentifier],     
				[storeGUID] [uniqueidentifier],     
				[guid] [uniqueidentifier],     
				[parent] [uniqueidentifier],     
				[itemBillType] [uniqueidentifier],     
				[vendor] [uniqueidentifier],     
				[matType] [int],     
				[itemState] [int],     
				[parentItemGuid] [uniqueidentifier],     
				[soType] [int],     
				[soGuid] [uniqueidentifier])     
	-- @t_bu table:     
	declare @t_bu  table (     
				[guid] [uniqueidentifier] default newid(),     
				[billTypeGuid] [uniqueidentifier] not null,     
				[vendor] [uniqueidentifier] not null,     
				[number] [int] identity(1, 1),     
				[total] [float],     
				[itemsDisc] [float],     
				[maxBillNum] [int],     
				[btBillType] [int],     
				[btAutoPost] [bit],     
				[btAutoGenEntry] [bit],     
				[btDefDiscAccGuid] [uniqueidentifier],     
				[btDefExtraAccGuid] [uniqueidentifier],     
				[btSortFlag] [int],     
				[vnNumber] [int] not null default 0,     
				[vnType] [int] not null default 0,     
				[vnName] [NVARCHAR](250) collate arabic_ci_ai not null default '')     
	-- @t_di table:     
	declare @t_di table (     
				[parentGuid] [uniqueidentifier],     
				[discount] [float],     
				[extra] [float])     
	-- @t_bi table:     
	declare @t_bi table (     
				[parentGuid] [uniqueidentifier],     
				[total] [float],     
				[vat] [float],     
				[itemsDisc] [float])     
	-- @t_ocur table:     
	declare @t_ocur table (     
				[number] [int] identity(1, 1),     
				[currencyGuid] [uniqueidentifier],     
				[currencyVal] [float],     
				[value] [float])     
	-- restuarants:   
	declare @t_ni table(     
				[number] [int],     
				[matGuid] [uniqueidentifier],     
				[ngGuid] [uniqueidentifier],     
				[ngstoreGuid] [uniqueidentifier])     
				  
	declare @t_raw table(     
				[number] [int],     
				[matGuid] [uniqueidentifier],     
				[ngGuid] [uniqueidentifier],     
				[parentGuid] [uniqueidentifier],     
				[price] [float],     
				[qty] [float],     
				[unity] [int],   
				[unitFact] [float],    
				[storeGuid] [uniqueidentifier],     
				[level] [int])   		  
	declare @t_ready table(     
				[number] [int],     
				[ngGuid] [uniqueidentifier],     
				[matGuid] [uniqueidentifier],     
				[price] [float],     
				[qty] [float],     
				[storeGuid] [uniqueidentifier])     
	-- ot variables:     
	declare      
		@otGuid [uniqueidentifier],     
		@otSystemType [int],		-- 0 for POS, 1 for Restaurants.     
		@otInReadyBillTypeGuid [uniqueidentifier],     
		@otOutRawBillTypeGuid [uniqueidentifier],     
		@otInReadyAccGuid [uniqueidentifier],     
		@otOutRawAccGuid [uniqueidentifier],     
		@otDrawerAccGuid [uniqueidentifier],     
		@otCurDrawerAccGuid [uniqueidentifier]     
	-- or variables:     
	declare     
		@orOrderID [int],     
		@orVendor [uniqueidentifier],     
		@orCurrencyGuid [uniqueidentifier],     
		@orCurrencyVal [float],     
		@orCustGuid [uniqueidentifier],     
		@orTotal [float],     
		@orTotalRSales [float],     
		@orDefPrice [int],     
		@orBillPayType [int],     
		@orSalesmanNum [int],     
		@orDate [datetime],     
		@orNotes [NVARCHAR](250),     
		@orBranch [uniqueidentifier],     
		@orAccountGuid [uniqueidentifier],     
		@orContraAccGuid [uniqueidentifier],     
		@orCashierUserGuid [uniqueidentifier],     
		@orTableGuid [uniqueidentifier],     
		@orDiscAmnt [float],     
		@orDiscRatio [float],     
		@orExtraAmnt [float],     
		@orExtraRatio [float],    
		@orGroupTax [float],   
		@allRSales [bit],     
		@sumOfBu [float]     
	-- bt variables:     
	declare     
		@btAutoPost [bit],     
		@btAutoEntry [bit]     
	-- order tables variables:     
	declare     
		@tbCode [NVARCHAR](250),     
		@tbCover [NVARCHAR](250)     
	-- bu variables:     
	declare     
		@buGuid [uniqueidentifier],     
		@buCustGuid [uniqueidentifier],     
		@buCustName [NVARCHAR](255)     
	-- other helpfull variables:     
	declare     
		@c cursor,     
		@bDivideDisc [bit],     
		@defCurrency [uniqueidentifier],     
		@defCurVal [float],     
		@maxBillNum [int],     
		@chGuid [uniqueidentifier],     
		@ceGuid [uniqueidentifier],     
		@curCount [int],     
		@level [int],     
		@maxLevel [int]     
	-- delete check related with order      
	delete from [ch000] where [parentGuid] in (select [billGuid] from [billRel000] where [parentGuid] = @orderGuid)     
	-- delete Multi Currency entry from er000     
	delete from [er000] where [parentGuid] = @orderGuid     
	-- delete old bills:      
	exec [prcOrder_deleteBills] @orderGuid     
	set @bDivideDisc = [dbo].[fnOption_GetBit]('AmnCfg_DivideDiscount', default)     
	set @defCurrency = CAST([dbo].[fnOption_Get]('AmnCfg_DefaultCurrency', Default) AS [uniqueidentifier])      
	set @defCurVal = (select [CurrencyVal] from [my000] where [GUID] = @defCurrency)     
	-- or000 variables:     
	select     
		@orOrderID = [orderID],     
		@orVendor = [vendor],     
		@orCurrencyGuid = [currencyGuid],     
		@orCurrencyVal = [currencyVal],     
		@orCustGuid = [custGuid],     
		@orTotal = [total],     
		@orTotalRSales = [totalRSales],     
		@orDefPrice = [defPrice],     
		@orBillPayType = [BillPayType],     
		@orSalesmanNum = (select [number] from [us000] where [guid] = [cashierUserGuid]), -- salesManPtr     
		@orDate = [date],     
		@orNotes = [notes],     
		@orBranch = [branch],     
		@orAccountGuid = [accountGuid],     
		@orContraAccGuid = [contraAccGuid],     
		@orCashierUserGuid = [cashierUserGuid],     
		@orTableGuid =  [tableGuid],     
		@orDiscAmnt = [discAmnt],     
		@orDiscRatio = [discRatio],     
		@orExtraAmnt = [extraAmnt],     
		@orExtraRatio = [extraRatio],  
		@orGroupTax = [GroupTax],     
		-- get the otGuid     
		@otGuid = [otGuid]     
	from     
		[or000]  
	where     
		[guid] = @orderGuid     
	-- prepare or tables variables:     
	select     
		@tbCode = [code],     
		@tbCover = [cover]     
	from     
		[tb000]     
	where     
		[guid] = @orTableGuid     
	-- ot variabls:     
	select     
		@otSystemType = [systemType],     
		@otInReadyBillTypeGuid = [btInReadyGuid],     
		@otOutRawBillTypeGuid = [btOutRawGuid],     
		@otInReadyAccGuid = [inReadyAccGuid],     
		@otOutRawAccGuid = [outRawAccGuid],     
		@otDrawerAccGuid = [drawerAccGuid],     
		@otCurDrawerAccGuid = [curDrawerAccGuid]     
	from     
		[ot000]     
	where     
		[guid] = @otGuid     
	-- prepare sales and/or rsales bu(s):     
	-- insert data into @t_bu 
	insert into @t_bu ([billTypeGuid], [vendor], [maxBillNum])     
		select distinct [itemBillType], [vendor], isnull((select max([number]) from [bu000] where [typeGuid] = [itemBillType]), 0)    
		from [oi000]     
		where     
			[parent] = @orderGuid      
			and [MatType] != 2     
			and  [itemState] != 2    
	-- fix vendors:     
	update @t_bu set [vendor] = @orVendor where [vendor] = 0x0     
	-- fix bt:     
	update [u] set     
			[btBillType] = [t].[btBillType],     
			[btAutoPost] = [t].[btAutoPost],     
			[btAutoGenEntry] = [t].[btAutoEntry],     
			[btDefDiscAccGuid] = [t].[btDefDiscAcc],     
			[btDefExtraAccGuid] = [t].[btDefExtraAcc],     
			[btSortFlag] = [t].[btSortFlag]     
		from @t_bu [u] inner join [vwbt] [t] on [u].[billTypeGuid] = [t].[btguid]     
	-- fix vendors:     
	update [u] set     
			[vnNumber] = [v].[number],     
			[vnType] = [v].[type],     
			[vnName] = [v].[name]     
		from @t_bu [u] inner join [vn000] [v] on [u].[vendor] = [v].[guid]     
	-- insert bu000:     
	insert into [bu000](      
			[Number], [Cust_Name], [Date], [CurrencyVal], [Notes], [PayType], [Security], [Vendor], [SalesManPtr], [Branch], [GUID], [TypeGUID], [CustGUID], [CurrencyGUID], [StoreGUID], [CustAccGUID],       
			[MatAccGUID], [ItemsDiscAccGUID], [BonusDiscAccGUID], [FPayAccGUID], [CostGUID], [UserGUID], [CheckTypeGUID], [TextFld1], [TextFld2], [TextFld3], [TextFld4])     
		select     
			[t].[number] + [t].[maxBillNum], -- ???     
			case isnull(@orCustGuid, 0x0) when 0x0 then '' else (select [CustomerName] from [cu000] where [guid] = @orCustGuid) end,  -- cust_name     
			@orDate,     
			@orCurrencyVal,     
			@orNotes,     
			@orBillPayType, -- payType     
			1, -- security,     
			[t].[vnNumber],     
			@orSalesmanNum,     
			@orBranch,     
			[t].[guid], -- guid     
			[t].[billTypeGuid], -- typeGuid     
			case isnull(@orCustGuid, 0x0) when 0x0 then      
					(case isnull(@orAccountGuid, 0x0) when 0x0 then 0x0 else (select [guid] from [cu000] where [AccountGuid] = @orAccountGuid) end)     
					else  @orCustGuid end, -- custGuid     
			@orCurrencyGUID,     
			[b].[defStoreGuid], -- storeGuid     
			case isnull(@orAccountGuid, 0x0) when 0x0 then [dbo].fnGetDAcc([b].[DefCashAccGUID]) else @orAccountGuid end, -- custAccGuid     
			isnull(@orContraAccGuid, 0x0), -- matAccGuid     
			[b].[defDiscAccGUID],     
			[b].[defBonusAccGUID],     
			[dbo].fnGetDAcc([b].[DefCashAccGUID]),     
			[b].[defCostGUID],     
			@orCashierUserGuid, -- userGUID     
			case @orBillPayType when 2  then (select top 1 [type] from [och000] where [parentGuid] = @orderGuid) else 0x0 end, -- CheckTypeGUID     
			cast(@orOrderId as NVARCHAR(10)),	-- TextFld1     
			[vnName], -- TextFld2     
			isnull(@tbCode, ''), -- TextFld3     
			isnull(@tbCover, '') -- TextFld4     
		from @t_bu t inner join [bt000] [b] on [t].[billTypeGuid] = [b].[guid]     
	-- prepare @t_oi	     
	insert into @t_oi     
		select      
			[o].[number],     
			[o].[qty],     
			[o].[unity],     
			[o].[price],     
			([o].[discRatio] * ([o].[qty] / (case [o].[unity] when 2 then [mt].[unit2fact] when 3 then [mt].[unit3fact] else 1 end))* [o].[price] / 100) + [o].[discAmount],     
			[o].[notes],     
			[o].[expireDate],     
			[o].[productionDate],     
			[o].[length],     
			[o].[width],     
			[o].[height],     
			[o].[extraAmount],     
			[o].[extraRatio],     
			[o].[matGuid],     
			[o].[storeguid],     
			[o].[guid],     
			[o].[parent],     
			[o].[itemBillType],     
			[o].[vendor],     
			[o].[matType],     
			[o].[itemState],     
			[o].[parentItemGuid],     
			[o].[soType],     
			[o].[soGuid]     
		from      
			[oi000] [o] inner join [mt000] [mt] on [o].[matGuid] = [mt].[guid]   
		where [o].[parent] = @orderGuid   
	if @otSystemType = 1 -- restaurants:     
		update @t_oi set [vendor] = (select [vendor] from [or000] where [guid] = @orderGuid)   
	-- if needed, fix oi prices according to the policy so that it will affect bi prices later:     
	if( @orDefPrice > 1 AND @orBillPayType > 0 )  --  0 is abstract and 1 is for default price wich is same as oi000 hanges are needed.
		update @t_oi set [price] =     
					case @orDefPrice     
						when 2		then [avgPrice]     
						when 4		then case [o].[unity] when 1 then [m].[whole]		when 2 then [m].[whole2]		else [m].[whole3]		end
						when 8		then case [o].[unity] when 1 then [m].[half]		when 2 then [m].[half2]			else [m].[half3]		end
						when 16		then case [o].[unity] when 1 then [m].[export]		when 2 then [m].[export2]		else [m].[export3]		end
						when 32		then case [o].[unity] when 1 then [m].[vendor]		when 2 then [m].[vendor2]		else [m].[vendor3]		end
						when 64		then case [o].[unity] when 1 then [m].[retail]		when 2 then [m].[retail]		else [m].[retail]		end
						when 128	then case [o].[unity] when 1 then [m].[endUser]		when 2 then [m].[endUser] 		else [m].[endUser3] 	end
						when 512	then case [o].[unity] when 1 then [m].[LastPrice]	when 2 then [m].[lastPrice2] 	else [m].[lastPrice3]	end
						else [o].[price]     
					end     
			from @t_oi [o] inner join [mt000] [m] on [o].[matGuid] = [m].[guid]     
	-- handle additions and holds:     
	update [o] set [o].[price] = [o].[price]     
								+ isnull(((select sum([price] * [qty]) from @t_oi where [parentItemGuid] = [o].[guid] and [matType] = 4) / [o].[qty]) , 0)     
								- isnull(((select sum([price] * [qty]) from @t_oi where [parentItemGuid] = [o].[guid] and [matType] = 5) / [o].[qty]), 0)     
		from @t_oi o     
		where [qty] != 0 and [matType] not in (1, 2, 4, 5) and [itemState] != 2     
	-- insert bi000:     
	insert into [bi000]( 
			[Number], [Qty], [Unity], [Price], [BonusQnt], [Discount], [CurrencyVal], [Notes], [ClassPtr], [ExpireDate], [ProductionDate], [Length], [Width], [Height], [VAT], [VATRatio],       
			[ParentGUID], [MatGUID], [CurrencyGUID], [StoreGUID], [soType], [soGuid])     
		select      
			ISNULL(min([o].[number])-1, 1),     
			case [o].[matType] when 6 then 0 else sum([o].[qty]) end, -- qty     
			[o].[unity],     
			[o].[price], 
			case [o].[matType] when 6 then sum([o].[qty]) else 0 end, --  bonus     
			sum([o].[discount]), -- discount     
			@orCurrencyVal,     
			[o].[notes],     
			CAST( [vnType] AS [NVARCHAR](128)),-- Class,     
			[o].[expireDate],     
			[o].[productionDate],     
			[o].[length],     
			[o].[width],     
			[o].[height],     
			sum([o].[extraAmount]), --vat     
			[o].[extraRatio], -- vatRatio     
			[t].[guid],     
			[o].[matGUID],     
			@orCurrencyGUID,      
			[o].[storeGUID],     
			[o].[soType],     
			[o].[soGuid]     
		from @t_oi [o] inner join @t_bu [t] on [o].[itemBillType] = [t].[billTypeGuid] and [o].[vendor] = [t].[vendor]     
		where [o].[matType] not in (2, 4, 5) and [o].[itemState] != 2     
		group by     
			[t].[guid], [t].[billTypeGuid], [t].[vnType], [o].[itemBillType], [o].[matType], [o].[unity], [o].[price], [o].[notes],     
			[o].[expireDate], [o].[productionDate], [o].[length], [o].[width], [o].[height], [o].[extraRatio], [o].[matguid], [o].[storeguid], [o].[soType], [o].[soGuid]     
	-- prepare totals from @t_bi:     
	insert into @t_bi     
		select [parentGuid], sum([i].[price] * [i].[qty] / (case [i].[unity] when 2 then [m].[unit2fact] when 3 then [m].[unit3fact] else 1 end)), sum([i].[vat]), sum([i].[discount])     
		from @t_bu [t] inner join [bi000] [i] on [t].[guid] = [i].[parentGuid] inner join [mt000] [m] on [i].[matGuid] = [m].[guid]    
		group by [t].[guid], [i].[parentGuid]     
	-- fix bu totals:     
	update [bu000] set     
			[total] = [t].[total],     
			[vat] = [t].[vat],     
			[itemsDisc] = [t].[itemsDisc],     
			[totalDisc] =  [t].[itemsDisc]     
		 from [bu000] [b] inner join @t_bi [t] on [b].[guid] = [t].[parentGuid]     
	-- update bu total in @t_bu     
	update [t] set      
			[t].[total] = [b].[total],     
			[t].[itemsDisc] = [b].[itemsDisc]     
		from @t_bu [t] inner join [bu000] [b] on [b].[guid] = [t].[guid]     
			     
	-- study if All orders are ReSales variables:     
	if @orTotalRSales != 0 and (@orTotal + @orTotalRSales = 0)     
		set @allRSales = 1     
	else     
		set @allRSales = 0     
	set @sumOfBu = abs(@orTotal) + case @allRSales when 0 then @orTotalRSales else 0 end     
	-- insert di000 discount, if any:     
	if @orDiscAmnt != 0 or @orDiscRatio != 0     
		insert into [di000]([number], [discount], [extra], [currencyVal], [notes], [flag], [classPtr], [parentGUID], [accountGUID], [currencyGUID], [costGUID], [contraAccGUID])     
			select     
				1,      
				(@orDiscAmnt + case @bDivideDisc when 1 then (@sumOfBu - itemsDisc) * ( 1.0 - 100.0 / (100.0 + @orDiscRatio)) else (@orDiscRatio * (@sumOfBu - [itemsDisc]) / 100) end) * ([total] - [itemsDisc]) / (@sumOfBu - [itemsDisc]), -- discount     
				0,     
				@orCurrencyVal,     
				@orNotes,     
				0,     
				CAST ([vnType] AS [NVARCHAR](128)),-- class,     
				[guid], -- parentGuid     
				[btDefDiscAccGuid],     
				@orCurrencyGUID,     
				0x0, -- costGuid     
				0x0 -- contraAccGuid     
			from @t_bu     
			where [btBillType] != 3 or @allRSales = 1     
	-- insert di000 extra, if any:     
	if @orExtraAmnt != 0 or @orExtraRatio != 0 or @orGroupTax != 0     
		insert into [di000]([number], [discount], [extra], [currencyVal], [notes], [flag], [classPtr], [parentGUID], [accountGUID], [currencyGUID], [costGUID], [contraAccGUID])     
			select     
				2,      
				0, --discount,      
				(@orExtraAmnt + @orGroupTax + (@orExtraRatio * (@sumOfBu - [itemsDisc]) / 100) ) * ([total] - [itemsDisc])/ (@sumOfBu - [itemsDisc]), -- extra     
				@orCurrencyVal,     
				@orNotes,     
				0, --flad     
				[vnType],-- class,     
				[guid], -- parentGuid     
				[btDefExtraAccGuid],     
				@orCurrencyGUID,     
				0x0, -- costGuid     
				0x0 -- contraAccGuid     
			from @t_bu     
			where [btBillType] != 3 or @allRSales = 1     
	-- prepare for di totals:     
	insert into @t_di     
		select [parentGuid], sum([d].[discount]), sum([d].[extra])     
		from [di000] [d] inner join @t_bu [t] on [d].[parentGuid] = [t].[guid]     
		group by [d].[parentGuid], [t].[guid]     
	-- fix bu totals:     
	update [bu000] set     
			[totalDisc] = [b].[totalDisc] + [d].[discount],     
			[totalExtra] = [d].[extra]     
		 from [bu000] [b] inner join @t_di [d] on [b].[guid] = [d].[parentGuid]     
	-- insert billRel:     
	insert into [billRel000] ([type], [billGuid], [parentGuid], [parentNumber])     
		select 3, [guid], @orderGuid, @orOrderID from @t_bu     
	set @c = cursor fast_forward for 
					select [guid], [btAutoPost], [btAutoGenEntry]  
					from @t_bu order by [btSortFlag], [number]     
	open @c fetch from @c into @buGuid, @btAutoPost, @btAutoEntry     
	while @@fetch_status = 0     
	begin     
		-- post bill if required:     
		if @btAutoPost = 1     
			update [bu000] set [isPosted] = 1 where [guid] = @buGuid     
		-- generate entry for bill if required:     
		if @btAutoEntry = 1     
			exec [prcBill_genEntry] @buGuid 
		fetch from @c into @buGuid, @btAutoPost, @btAutoEntry     
	end     
	close @c     
	-- generate ch000, if any:     
	if exists(select * from [och000] where [parentGuid] = @orderGuid)     
	begin     
		set @buGuid = (select top 1 [guid] from @t_bu where [btBillType] != 3)     
		if @buGuid is null     
			delete [och000] where [parentGuid] = @orderGuid     
		else     
		begin     
			insert into [ch000] ([Number], [Dir], [Date], [DueDate], [Num], [Bank], [Notes], [Val], [CurrencyVal], [Security], [GUID], [TypeGUID], [ParentGUID], [AccountGUID], [CurrencyGUID], [BranchGUID])     
				select     
					isnull((select max([number]) from [ch000] where [typeGuid] = [c].[type]), 0) + 1, -- number     
					1, -- dir     
					[b].[date],     
					[b].[date], -- dueDate     
					[c].[checkNumber], -- num     
					[n].[destName], -- bank     
					[c].[Notes],	--notes     
					[c].[value], --val     
					@defCurVal,--b.CurrencyVal,     
					1, --security     
					newid(), -- guid     
					[c].[type], -- typeGuid     
					[b].[guid], -- parentGuid     
					[b].[custAccGuid], -- accountGuid     
					@defCurrency,--b.currencyGuid,     
					[b].[branch]     
				from [och000] [c] inner join [nt000] [n] on [c].[type] = [n].[guid], [bu000] [b]     
				where [c].[parentGuid] = @orderGuid and [b].[guid] = @buGuid     
	     
			-- generate ch entries:     
			set @c = cursor fast_forward for select [guid] from [ch000] where [parentGuid] = @buGuid order by [number]     
			open @c fetch from @c into @chGuid     
			while @@fetch_status = 0      
			begin     
				exec [prcNote_genEntry] @chGuid     
				fetch from @c into @chGuid     
			end     
			close @c     
		end     
	end     
	-- we wont be using @c anymore, so:     
	deallocate @c     
	-- currencies:     
	insert into @t_ocur ([currencyGuid], [currencyVal], [Value])     
		select      
			[currencyGuid],     
			[currencyVal],     
			[value]     
		from [ocur000]     
		where [parentGUID] = @orderGuid	     
	-- insert payment if exist     
	insert into @t_ocur ( [currencyGuid], [currencyVal], [Value])     
		select      
			[o].[CurrencyGuid],     
			[o].[CurrencyVal],     
			[o].[payment]	     
		from [or000] [o] where [guid] = @OrderGuid and [o].[payment] != 0     
				     
	set @curCount = (select Count(*) from @t_ocur)   
	if( @curCount > 1)     
	begin     
		set @ceGuid = newid()     
		-- Insert ce:      
		insert into [ce000] ([Type], [Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [IsPosted], [Security], [Branch], [GUID], [CurrencyGUID], [TypeGUID])      
			select     
				1, -- type     
				isnull((select max([number]) from [ce000]), 0) + 1, -- number     
				@orDate,      
				@orTotal, -- debit     
				@orTotal, -- credit     
				@orNotes,     
				@orCurrencyVal,     
				0, -- isposted     
				1,     
				@orBranch,     
				@ceGuid, --guid     
				@orCurrencyGUID,     
				0x0      
		-- insert en:     
		insert into [en000] ([Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [class], [Vendor], [Salesman], [ParentGUID], [AccountGUID], [CurrencyGUID], [ContraAccGUID] )      
			select     
				[number],      
				@orDate,     
				[value] * [currencyVal],     
				0,     
				@orNotes,     
				[currencyVal],     
				0, --class     
				0, --vendor     
				@orSalesmanNum,     
				@ceGuid, -- parentGuid     
				@otDrawerAccGuid, -- accountGuid     
				[currencyGuid],     
				@otCurDrawerAccGuid -- contraAccGuid     
			from     
				@t_ocur     
			     
			union all      
			select     
				[number] + @curCount,     
				@orDate,     
				0,     
				[value] * [currencyVal],     
				@orNotes,     
				[currencyVal],     
				0, --class     
				0, --vendor     
				@orSalesmanNum,     
				@ceGuid, -- parentGuid     
				@otCurDrawerAccGuid, -- accountGuid     
				[currencyGuid],     
				@otDrawerAccGuid -- currencyGuid     
			from     
				@t_ocur     
		-- insert er:     
		insert into [er000] ([EntryGUID], [ParentGUID], [ParentType], [ParentNumber])      
			values(@ceGuid, @orderGuid, 9, @orOrderID)      
		-- post entry:      
		update [ce000] set      
				[isPosted] = 1,      
				[debit] = (select ISNULL(Sum([debit]), 0) from [en000] where [parentguid] = @ceGuid),     
				[credit] = (select ISNULL(Sum([credit]), 0) from [en000] where [parentguid] = @ceGuid)     
		where [guid] = @ceGuid     
	end     
	-- restaurants:     
	-- generate raw materials and ready materials ouput and input bills:     
	if @otSystemType = 1 -- restaurants:     
	begin     
		-- Insert Into ingredient Items Temp Table  
		insert into @t_ni     
			select     
				distinct     
				[ni].[number],     
				[ni].[MatGuid],     
				[ng].[Guid],     
				[ng].[StoreGuid]				     
			from     
				[ng000] [ng] inner join [ni000] [ni] on [ng].[matguid] = [ni].[matguid]     
		  
		-- Insert Into ingredients Temp Table: 
		insert into @t_ready     
				select [oi].[number], [ng].[Guid], [oi].[matGuid], 0, [oi].[qty], [ng].[storeGuid]     
				from [oi000] [oi] inner join [ng000] [ng] on [oi].[matGuid] = [ng].[matGuid]     				where [oi].[parent] = @orderGuid     
		if @@rowcount != 0     
		begin		     
			insert into @t_raw     
					select     
						[ni].[number],     
						[ni].[matGuid],     
						isnull([i].[ngGuid], 0x0),     
						[ni].[parentGuid],     
						0, -- price     
						[ni].[Qty] * [ng].[qty],     
						[ni].[unity],	     
						0,  
						case isnull([i].[ngStoreGuid],0x0) when 0x0 then isnull([ng].[storeGuid], 0x0) else [i].[ngStoreGuid] end, -- storePtr     
						0     
					from     
						[ni000] [ni]  inner join @t_ready [ng] on [ni].[parentGuid] = [ng].[ngGuid] Left join @t_ni [i] on [ni].[matGuid] = [i].[matGuid]     
			--------------------------------------------------------------------------     
			--add additions and holds:     
			--------------------------------------------------------------------------     
			insert into @t_raw     
					select     
						--[number] [int] identity(1, 1),     
						[i].[number],     
						[oi].[matGuid],     
						isnull([i].[ngGuid], 0x0),     
						0x0,     
						0, -- price     
						[oi].[Qty],     
						[oi].[unity],	     
						0, -- unitFact  
						isnull([i].[ngStoreGuid], 0x0), -- storePtr     
						0     
					from     
						[oi000] [oi] Left join @t_ni i on [oi].[matGuid] = [i].[matGuid]     
					where [oi].[parent] = @orderGuid and [matType] in ( 4, 5)     
		end     
			     
		set @level = 0				     
		if exists(select count(*) from @t_ni)     
		begin			     
			while 1 = 1     
			begin     
				set @level = @level +1     
				insert into @t_raw     
						select     
							[ni].[number],     
							[ni].[matGuid],     
							isnull([i].[ngGuid], 0x0),     
							[ni].[parentGuid],     
							0, -- price     
							[ni].[Qty],     
							[ni].[unity],     
							0, -- unitFact  
							isnull([i].[ngStoreGuid],0x0), --storePtr     
							@level     
						from     
							[ni000] [ni] Left join @t_ni [i] on [ni].[matGuid] = [i].[matGuid]     
						where [ni].[parentGuid] in ( select [ngGuid] from @t_raw where [level] = @level - 1 and [ngGuid] != 0x0 )   				  
	     
				if @@rowcount = 0     
					break     
	     
				-- short ciruit     
			end     
		end     
		-- update price for raw materials     
		update [r] set   
			[r].[price] = [mt].[AvgPrice] * (case [r].[unity] when 2 then [mt].[unit2fact] when 3 then [mt].[unit3fact] else 1 end),  
			[r].[unitFact] = (case [r].[unity] when 2 then [mt].[unit2fact] when 3 then [mt].[unit3fact] else 1 end)  
			from @t_raw [r] inner join [mt000] [mt] on [r].[matguid] = [mt].[guid]    
	-------------------------------------------  
	--select matguid,price,Qty,unitFact, price *Qty/ unitFact from @t_raw order by matguid  
	-------------------------------------------  
		-- update price for materails that  has subItems:	     
		if @level > 0     
		begin     
			while 1 = 1     
			begin		     
				set @level = @level -2     
				     
				update [r] set     
					[r].[price] = (select isnull(sum([price] * [qty] / [unitFact] ), 0)  from @t_raw where [parentguid] = [r].[ngGuid])     
				from @t_raw [r]     
				where [ngGuid] != 0x0 and [level] = @level     
				     
				if @@rowcount = 0     
					break						     
			end     
		end     
		-- update store for subItems:     
		update [r] set     
				[storeGuid]  = case isnull([storeGuid], 0x0) when 0x0 then isnull((select top 1 [storeGuid] from @t_raw where [ngGuid] = [r].[parentGuid]), 0x0) else [storeGuid] end     
			from @t_raw [r]      
		     
		-- update ready materials:     
		update [r] set     
				[price] = (select sum( [price]  * [qty] / unitFact) from @t_raw where [parentGuid] = [r].ngGuid)     
			from @t_ready [r]     
	-------------------------------------------  
	--select * from @t_ready  
	-------------------------------------------		     
		-- delete materials that  has subItems     
		delete @t_raw where [ngGuid] != 0x0     
		-- add bu for ready materials & raw materials bills     
		set @buGuid = newid() -- raw mats bill:     
		-- fetch customer's guid and name:     
		select     
			top 1     
			@buCustGuid = [guid],     
			@buCustName = [customerName]     
		from [cu000]     
		where [accountGuid] = @otOutRawAccGuid     
		if exists(select * from @t_raw) 
		begin 
			-- insert bu000 for raw:     
			insert into [bu000](      
					[Number], [Cust_Name], [Date], [CurrencyVal], [Notes], [Total], [PayType], [Security], [SalesManPtr], [Branch], [GUID], [TypeGUID], [CustGUID], [CurrencyGUID], [StoreGUID], [CustAccGUID],       
					[MatAccGUID], [ItemsDiscAccGUID], [BonusDiscAccGUID], [FPayAccGUID], [CostGUID], [UserGUID])     
				select     
					isnull((select max([number]) from [bu000] where [typeGuid] = @otOutRawBillTypeGuid), 0) + 1, -- number     
					@buCustName,     
					@orDate,     
					@orCurrencyVal,     
					@orNotes,     
					isnull((select sum([price] * [qty]) from @t_raw), 0), -- total     
					1, -- payType     
					1, -- security,     
					@orSalesmanNum,     
					@orBranch,     
					@buGuid, -- guid     
					@otOutRawBillTypeGuid, -- typeGuid     
					@buCustGuid,     
					@orCurrencyGUID,     
					[defStoreGuid], -- storeGuid				     
					@otOutRawAccGuid, -- custAccGuid     
					[defBillAccGuid], -- matAccGuid     
					[defDiscAccGUID],     
					[defBonusAccGUID],     
					[dbo].fnGetDAcc([DefCashAccGUID]),     
					[defCostGUID],     
					@orCashierUserGuid -- userGUID     
				from [bt000]     
				where [guid] = @otOutRawBillTypeGuid     
			-- add bi for raw:     
			-- insert bi000:     
			insert into [bi000](      
					[Number], [Qty], [Unity], [Price], [CurrencyVal], [ParentGUID], [MatGUID], [CurrencyGUID], [StoreGUID])     
				select      
					[number],     
					[qty], -- qty 
					[unity],     
					[price] /** [qty]*/, 
					@orCurrencyVal,     
					@buGuid, -- parentGuid     
					[matGUID],     
					@orCurrencyGUID,      
					case isnull([storeGUID],0x0) when 0x0 then (select [storeGuid] from [bu000] where [guid] = @buGuid ) else 0x0 end     
				from @t_raw     
			-- prepare for posting and entry generation of raw bu:     
			select     
				@btAutoPost = [bAutoPost],     
				@btAutoEntry = [bAutoEntry]     
			from [bt000]     
			where [guid] = @otOutRawBillTypeGuid     
			-- post raw bu: 
			if @btAutoPost = 1     
				update [bu000] set [isposted] = 1 where [guid] = @buGuid     
			-- generate entry for raw bu:     
			if @btAutoEntry = 1     
				exec [prcBill_genEntry] @buGuid     
			-- insert billRel:     
			insert into [billRel000] ([type], [billGuid], [parentGuid], [parentNumber])     
				select 3, @buGuid, @orderGuid, @orOrderID     
		end 
		-- add bu for ready bills:     
		set @buGuid = newid() -- ready mats bill     
		-- fetch customer's guid and name:     
		select     
			top 1     
			@buCustGuid = [guid],     
			@buCustName = [customerName]     
		from [cu000]     
		where [accountGuid] = @otInReadyAccGuid 
		if exists(select * from @t_ready) 
		begin 
			-- insert bu000 for ready: 
			insert into [bu000](      
					[Number], [Cust_Name], [Date], [CurrencyVal], [Notes], [Total], [PayType], [Security], [SalesManPtr], [Branch], [GUID], [TypeGUID], [CustGUID], [CurrencyGUID], [StoreGUID], [CustAccGUID],       
					[MatAccGUID], [ItemsDiscAccGUID], [BonusDiscAccGUID], [FPayAccGUID], [CostGUID], [UserGUID])     
				select     
					isnull((select max([number]) from [bu000] where [typeGuid] = @otInReadyBillTypeGuid), 0) + 1, -- number     
					@buCustName,     
					@orDate,     
					@orCurrencyVal,     
					@orNotes,     
					isnull((select sum([price] /** [qty]*/) from @t_ready), 0), -- total     
					1, -- payType     
					1, -- security,     
					@orSalesmanNum,     
					@orBranch,     
					@buGuid, -- guid     
					@otInReadyBillTypeGuid, -- typeGuid     					
					@buCustGuid,     
					@orCurrencyGUID,     
					[defStoreGuid], -- storeGuid				     
					@otInReadyAccGuid, -- custAccGuid      
					[defBillAccGuid], -- matAccGuid     
					[defDiscAccGUID],     
					[defBonusAccGUID],     
					[dbo].fnGetDAcc([DefCashAccGUID]),     
					[defCostGUID],     
					@orCashierUserGuid -- userGUID     
				from [bt000]     
				where [guid] = @otInReadyBillTypeGuid     
	 
			-- add bi for ready: 
			-- insert bi000:     
			insert into [bi000](      
					[Number], [Qty], [Unity], [Price], [CurrencyVal], [ParentGUID], [MatGUID], [CurrencyGUID], [StoreGUID] )
				select      
					1,--[number],     
					1,--[qty], -- qty     
					1,     
					1,--([price] / [qty]), 
					1,--@orCurrencyVal,     
					0x0,--@buGuid, -- parentGuid     
					0x0,--[matGUID],     
					0x0,--@orCurrencyGUID,      
					0x0--case isnull([storeGUID], 0x0) when 0x0 then (select [storeGuid] from [bu000] where [guid] = @buGuid ) else 0x0 end     
				from @t_ready 
	  

 			-- prepare for posting and entry generation of ready bu:     
			select     
				@btAutoPost = [bAutoPost],     
				@btAutoEntry = [bAutoEntry]     
			from [bt000]     
			where [guid] = @otInReadyBillTypeGuid     
			-- post ready bu:     
			if @btAutoPost = 1     
				update [bu000] set [isposted] = 1 where [guid] = @buGuid     
			-- generate entry for raw bu:     
			if @btAutoEntry = 1     
				exec [prcBill_genEntry] @buGuid     
			-- insert billRel:     
			insert into [billRel000] ([type], [billGuid], [parentGuid], [parentNumber])     
				select 3, @buGuid, @orderGuid, @orOrderID     
		end 
	end -- restuarants system     
		     
	commit tran     
	return 1 
###############################################################################
#END

/// <reference path="~/Scripts/kendo.all.min.intellisense.js" />

(function ($) {
	var FX_DURATION = 250,
		VIRTUALIZE_THRESHOLD = 100,
		FOOTER_MAX_ROWS = 5,
		FOOTER_TITLE_KEY = '_$T_',
		ROW_META_KEY = '_$M_',
		AGG_NONE = -10,
		VW_SEP = 25,
		FT_TOTAL = 12;

	var pageInfo = {},
		footarMaxRows = FOOTER_MAX_ROWS,
		$toolbar, $header, $container, $grid, $rmenu,
		$gcontent = $(),
		$colgroups = $(),
		$pager = $(),
		$footers = $(),
		kgrid = null,
		ready = false,
		dirty = false;

	function post(fn) {
		setTimeout(fn, 0);
	}

	function rtl() {
		return pageInfo.resources.dir == 'rtl';
	}

	function str(id) {
		return pageInfo.resources.text[id];
	}

	function localizePage() {
		var res = pageInfo.resources;

		kendo.culture('amn');
		kendo.cultures["amn"].numberFormat[','] = res.comma;

		['OptionsWnd', 'Save', 'Reset', 'Refresh'].forEach(function (id) {
			$('#' + id).attr('title', res.text[id]);
		});

		['GridLines', 'ExpandFooter'].forEach(function (id) {
			$('#' + id).append('<span>' + res.text[id] + ' </span>');
		});

		['SelectedRowSize'].forEach(function (id) {
			$('#' + id).prepend('<span>' + res.text[id] + '</span>');
		});

		$('#SelectedRowSizeMenu li:first-child a').text(res.text.Normal);

		$('html').attr('dir', res.dir);
		$container.addClass('k-' + res.dir);
	}

	function getContentHeight() {
		return $(window).height() - $toolbar.outerHeight(true) - $header.outerHeight(true)
			- parseFloat($container.css('paddingTop')) - parseFloat($container.css('paddingBottom'));
	}

	function adjustGridHeight() {
		var height = getContentHeight() - $footers.outerHeight() - ($colgroups.outerHeight() || 0) - ($pager.outerHeight() || 0) - 2,
			cy = 0;

		$grid.children().not(".k-grid-content").each(function () { cy += $(this).outerHeight(); });
		$grid.height(height);
		$grid.children(".k-grid-content").height(height - cy);
	}

	function adjustFooterHeight() {
		$footers.css('maxHeight', $footers.find('tbody tr').eq(0).outerHeight() * footarMaxRows - 1);
	}

	function adjustLayout() {
		if (ready) {
			$container.height('auto');
			adjustGridHeight();
		} else
			$container.height(getContentHeight());
	}

	function setButtonToggleState(id, state) {
		if (state)
			$('#' + id).addClass('active');
		else
			$('#' + id).removeClass('active');
	}

	function updateUI() {
		setButtonToggleState('GridLines', pageInfo.gridLines);
		setButtonToggleState('ExpandFooter', pageInfo.expandFooter);
		setSelectedRowSize(pageInfo.selectedRowSize);

		if (ready) {
			showGridLines();
			expandFooter();
		}

		$toolbar.find('button,label').prop('disabled', !ready);
	}

	function prepareGridInfo(info, state) {
		var res = pageInfo.resources.text,
			columns = info.columns,
			data = info.dataSource.data,
			pctColumns;

		if (state) {
			for (var i = state.columns.length - 1; i >= 0; i--) {
				var stateCol = state.columns[i];

				if ($.grep(columns, function (col) { return col.field == stateCol.field; }).length == 0)
					state.columns.splice(i, 1);
			}

			info.columns = state.columns;
		} else {
			var rwidth = 0,
				factor = $grid.width() - 20;

			columns.forEach(function (col) { rwidth += col.rwidth; });
			columns.forEach(function (col) { col.width = (col.rwidth / rwidth * factor) + 'px'; });
		}

		pctColumns = $.grep(columns, function (col) { return col.format && col.format.lastIndexOf('%') != -1; })

		if (pctColumns.length > 0) {
			data.forEach(function (item) {
				pctColumns.forEach(function (col) {
					if (item[col.field])
						item[col.field] /= 100;
				});
			});
		}

		if (data.length > VIRTUALIZE_THRESHOLD) {
			info.dataSource.pageSize = VIRTUALIZE_THRESHOLD;
			$.extend(info, {
				scrollable: {
					virtual: true
				},
				pageable: {
					buttonCount: 5,
					messages: {
						display: res.Pager,
						first: res.FirstPage,
						last: res.LastPage,
						next: res.NextPage,
						previous: res.PrevPage
					}
				}
			});
		}

		$.extend(info, {
			dataBound: gridDataBound,
			columnResize: gridColumnResized,
			columnReorder: gridColumnReordered
		});
	}

	function buildHeader(header) {
		var maxLine = 0,
			html;

		header.forEach(function (line) { maxLine = Math.max(maxLine, line.length); });
		html = '<table><thead><tr><th colspan="' + maxLine + '">' + header[0][0][0] + '</th></tr></thead><tbdoy>';

		for (var i = 1; i < header.length; i++) {
			html += '<tr>';

			for (var j = 0; j < header[i].length; j++) {
				var line = header[i];

				html += '<td' + (line.length == 1 ? ' colspan="2"' : '') + '>';

				if (line[j][1].length > 0)
					html += '<span>' + line[j][0] + ': </span>' + line[j][1];
				else
					html += line[j][0];

				html += '</td>';
			}

			html += '</tr>';
		}

		html += '</tbody></table>';
		$header.html(html);
	}

	function getRowClass(style) {
		switch (style) {
			case FT_TOTAL: return 'a-ft-total';
			default: return '';
		}
	}

	function processGroupRows() {
		var count = getFixedColumns().length;

		kgrid.dataSource.data().forEach(function (dr, index) {
			var $tr = $grid.find('tbody tr:nth-child(' + (index + 1) + ')'),
				$children = $tr.children();

			if (dr[ROW_META_KEY].group) {
				for (var i = 1; i < count; i++)
					$children.eq(i).hide();

				$children.eq(0).attr('colspan', count).text(dr[pageInfo.fields.group]);
			}

			if (dr[ROW_META_KEY].style > 0)
				$tr.addClass(getRowClass(dr[ROW_META_KEY].style));
		});
	}

	function buildColumnsGroups() {
		var map = {},
			index = 0,
			options = {
				dataSource: {
					data: [{}]
				},
				columns: [],
				reorderable: true,
				columnReorder: gridColGroupReordered
			};

		kgrid.columns.forEach(function (col) {
			if (map[col.group] === undefined)
				map[col.group] = 0;

			map[col.group] += parseFloat(col.width);
		});

		$.each(map, function (key, value) {
			options.columns.push({ field: 'C' + index, title: key || ' ', width: value + 'px' });
			options.dataSource.data[0]['C' + index++] = '';
		});

		if ($colgroups.getKendoGrid())
			$colgroups.getKendoGrid().destroy();

		$colgroups.empty().kendoGrid(options);

		if (kgrid.table.width() < $gcontent.width())
			$colgroups.find('.k-grid-header table').width(kgrid.table.width());
	}

	function buildGrid(info) {
		var width = 0;

		$grid.kendoGrid(info);
		$gcontent = $grid.find('.k-grid-content').on('scroll', gridContentScroll);
		$pager = $grid.find('.k-grid-pager').css('visibility', 'hidden');
		kgrid = $grid.getKendoGrid();
		kgrid.table.on('mouseup dblclick', 'tr', gridRowMouseHandler);
		processGroupRows();
		kgrid.columns.forEach(function (c) { width += parseFloat(c.width); });

		if (kgrid.table.width() > width) {
			$grid.find('.k-grid-header table').width(width);
			kgrid.table.width(width);
		}

		if (pageInfo.features.columnsGrouped)
			buildColumnsGroups();
	}

	function realignPager() {
		if ($pager.length) {
			$pager.insertAfter($footers);
			$grid.height($grid.height() - $pager.outerHeight());
		}
	}

	function getFixedColumns() {
		var grouped = pageInfo.features.columnsGrouped,
			columns = [];

		for (var i = 0, n = kgrid.columns.length; i < n; i++) {
			var col = kgrid.columns[i];

			if (grouped && col.group.length > 0)
				break;

			if (!grouped && col.agg != AGG_NONE)
				break;

			columns.push(col);
		}

		return columns;
	}

	function getAttachedFootersData(footers, grandTotal) {
		var data = [];

		if (grandTotal) {
			data.push(grandTotal.data);
			data[0][FOOTER_TITLE_KEY] = grandTotal.title;
		}

		footers.forEach(function (footer) {
			if (footer.attached) {
				footer.data.forEach(function (dr) { dr[FOOTER_TITLE_KEY] = dr[footer.primeField] ? dr[footer.primeField] : ''; });
				$.merge(data, footer.data);
			}
		});

		return data;
	}

	function buildAttachedFooter() {
		var $attachedFooter = $footers.children().eq(0),
			columns = kgrid.columns,
			fixedColumns = getFixedColumns(),
			fixedWidth = 0,
			options = {
				dataSource: {
					data: pageInfo.attachedData
				},
				columns: []
			};

		fixedColumns.forEach(function (col) { fixedWidth += parseFloat(col.width); });
		options.columns.push({ field: FOOTER_TITLE_KEY, width: fixedWidth + 'px' });
		columns.forEach(function (col) {
			if ($.inArray((col), fixedColumns) == -1)
				options.columns.push({ field: col.field, width: col.width, format: col.format || '' });
		});

		if ($attachedFooter.getKendoGrid())
			$attachedFooter.getKendoGrid().destroy();

		$attachedFooter.empty().kendoGrid(options);

		if (kgrid.table.width() < $gcontent.width())
			$attachedFooter.find('table').width(kgrid.table.width());
	}

	function buildDetachedFooter(data, columns) {
		var $tbody = $('<div class="k-grid k-widget k-secondary"><div class="k-grid-content">' +
			'<table><tbody></tbody></table></div></div>').find('tbody'),
			totalWidth = 0,
			cy = kgrid.table.width(),
			padding = parseFloat(kgrid.table.find('tr:first-child td:first-child').css('paddingLeft')) * 2;

		data.forEach(function (dr) {
			var $tr = $('<tr></tr>');

			columns.forEach(function (col) {
				if (dr[col.field] !== undefined)
					$('<td></td>').text(col.format ? kendo.format(col.format, dr[col.field]) : dr[col.field]).appendTo($tr);
			});

			$tbody.append($tr);
		});

		columns.forEach(function (col) { totalWidth += col.rwidth; });
		$tbody.find('tr:first-child td').each(function (index) {
			$(this).width((columns[index].rwidth / totalWidth * cy) - padding - 1);
		}).end().end().appendTo($footers.children().eq(1));

		if (kgrid.table.width() < $gcontent.width())
			$tbody.end().width(kgrid.table.width());
	}

	function buildFooters() {
		if (pageInfo.attachedData.length > 0)
			buildAttachedFooter();

		$footers.children().eq(1).empty();
		pageInfo.detachedFooters.forEach(function (footer) {
			buildDetachedFooter(footer.data, footer.columns);
		});

		adjustFooterHeight();
	}

	function rebuildSubGrids(ignoreColGroups) {
		if (!!ignoreColGroups === false && $colgroups.getKendoGrid())
			buildColumnsGroups();

		buildFooters();
		gridContentScroll();
	}

	function buildRowMenu(items) {
		$rmenu.empty();
		items.forEach(function (item, index) {
			var $item;

			if (item.id == VW_SEP && index > 0)
				$item = $('<li class="divider"></li>');
			else
				$item = $('<li><a>' + item.title + '</a></li>').data('itemid', item.id);

			if (index == 0)
				$item.children().css('fontWeight', 'bold');

			$item.appendTo($rmenu);
		});
	}

	function showRowMenu(index, x, y) {
		var cx = $(window).width(),
			cy = $(window).height(),
			width = $rmenu.outerWidth(),
			height = $rmenu.outerHeight(),
			left = rtl() ? x - width : x,
			top = y;

		if (left + width > cx)
			left -= width;

		if (top + height > cy)
			top -= height;

		left = Math.max(left, rtl() ? 20 : 0);
		top = Math.max(top, 0);

		$(document).one('mousedown', function (e) {
			if (!$.contains($rmenu[0], e.target))
				$rmenu.hide();
		});

		$rmenu.css({ left: left, top: top }).show();
	}

	function clearPage() {
		if (kgrid)
			kgrid.destroy();

		$footers.children().eq(0).empty();
		$colgroups.add($grid).empty().css('visibility', 'hidden');
		$pager.remove();
		$container.addClass('a-loading');
	}

	function buildPage(gridInfo, state) {
		prepareGridInfo(gridInfo, state);
		buildGrid(gridInfo);
		buildFooters();
		realignPager();
	}

	function showPage() {
		$container.removeClass('a-loading');
		$colgroups.add($grid).add($pager).add($footers).hide().css('visibility', 'visible');
		$colgroups.show();
		$grid.slideDown(FX_DURATION, function () { $footers.add($pager).fadeIn(FX_DURATION); });
	}

	function canReorderColumn(e) {
		if (pageInfo.features.columnsGrouped) {
			var fixedColumns = getFixedColumns();

			if (e.oldIndex < fixedColumns.length && e.newIndex >= fixedColumns.length)
				return false;

			if (e.column.group != kgrid.columns[e.newIndex].group)
				return false;
		}

		return true;
	}

	function canReorderColGroup(e) {
		return e.column.title.trim().length != 0;
	}

	function cancelReorderColumn(e) {
		kgrid.reorderColumn(e.oldIndex, e.column);
	}

	function cancelReorderColGroup(e) {
		$colgroups.getKendoGrid().reorderColumn(e.oldIndex, e.column);
	}

	function reorderColGroup(srcIndexes, destIndexes) {
		for (var i = srcIndexes.length - 1; i >= 0; i--)
			kgrid.reorderColumn(destIndexes[i], kgrid.columns[srcIndexes[i]]);

		rebuildSubGrids(true);
	}

	function gridDataBound() {
		if ($gcontent.length)
			adjustGridHeight();

		$grid.find('tbody tr').removeClass('k-alt');
	}

	function gridColumnResized(e) {
		post(rebuildSubGrids);
		dirty = true;
	}

	function gridColumnReordered(e) {
		if (canReorderColumn(e))
			post(rebuildSubGrids);
		else
			post(cancelReorderColumn.bind(this, e));

		dirty = true;
	}

	function gridColGroupReordered(e) {
		if (canReorderColGroup(e)) {
			var grid = $colgroups.getKendoGrid(),
				destCol = grid.columns[e.newIndex],
				srcIndexes = [],
				destIndexes = [];

			kgrid.columns.forEach(function (col, index) {
				if (col.group == e.column.title)
					srcIndexes.push(index);
				else if (col.group == destCol.title)
					destIndexes.push(index);
			});

			post(reorderColGroup.bind(this, srcIndexes, destIndexes));
		} else
			post(cancelReorderColGroup.bind(this, e));

		dirty = true;
	}

	function gridContentScroll() {
		$colgroups
			.find('.k-grid-content')
			.add($footers.find('.k-grid-content'))
			.scrollLeft($gcontent.scrollLeft());
	}

	function gridRowMouseHandler(e) {
		var index = $(this).index();

		switch (e.type) {
			case 'mouseup':
				if (e.which === 3) {
					kgrid.select($(this));
					requestRowMenuInfo(index, e.pageX, e.pageY);
				}
				break;

			case 'dblclick':
				window.external.rowDblClick(index);
				break;
		}
	}

	function gridMenuItemClick(e) {
		e.preventDefault();
		$rmenu.hide();
		window.external.rowMenuItemClick(kgrid.select().index(), $(this).data('itemid'));
	}

	function showOptionsWnd() {
		window.external.showOptionsWnd();
	}

	function refresh() {
		window.external.refresh();
	}

	function saveState() {
		var state = {
			gridLines: pageInfo.gridLines,
			expandFooter: pageInfo.expandFooter,
			selectedRowSize: pageInfo.selectedRowSize,
			columns: kgrid.columns
		};

		window.external.saveState(JSON.stringify(state));
	}

	function clearState() {
		window.external.clearState();
	}

	function showGridLines() {
		if (pageInfo.gridLines)
			$grid.addClass('a-grid-lines');
		else
			$grid.removeClass('a-grid-lines');
	}

	function expandFooter() {
		footarMaxRows = pageInfo.expandFooter ? Math.floor($container.height() * .7 / $footers.find('tbody tr').eq(0).outerHeight()) : FOOTER_MAX_ROWS;
		adjustFooterHeight();
		adjustLayout();
	}

	function toggleGridLines() {
		pageInfo.gridLines = !$('#GridLines').hasClass('active');
		showGridLines();
	}

	function toggleFooter() {
		pageInfo.expandFooter = !$('#ExpandFooter').hasClass('active');
		expandFooter();
	}

	function setRowSizeButtonText(size) {
		$('#SelectedRowSize span:first-child')
			.text(str('SelectedRowSize') + (size > 1 ? ' (' + $('#SelectedRowSizeMenu a').eq(size - 1).text() + ')' : ''));
	}

	function setSelectedRowSize(size) {
		$grid.removeClass('a-row-size-1 a-row-size-2 a-row-size-3 a-row-size-4').addClass('a-row-size-' + size);
		setRowSizeButtonText(size);
		pageInfo.selectedRowSize = size;
	}

	function selectedRowSizeMenuClick(e) {
		setSelectedRowSize($(this).find('a').attr('data-row-size'));
		e.preventDefault();
	}

	function attachEvents() {
		var events = [
			{ el: '#OptionsWnd', h: showOptionsWnd },
			{ el: '#Refresh', h: refresh },
			{ el: '#Save', h: saveState },
			{ el: '#Reset', h: clearState },
			{ el: '#GridLines', h: toggleGridLines },
			{ el: '#ExpandFooter', h: toggleFooter },
			{ el: '#SelectedRowSizeMenu', h: selectedRowSizeMenuClick, sel: 'li' },
			{ el: '#RowMenu', h: gridMenuItemClick, sel: 'li' },
		//{ el: '#Test', h: test },
			{el: window, h: adjustLayout, evt: 'resize' }
		];

		events.forEach(function (e) { $(e.el).on(e.evt || 'click', e.sel || null, e.h || false); });
	}

	function requestPageData() {
		window.external.getPageData();
	}

	function requestRowMenuInfo(index, x, y) {
		window.external.getRowMenuInfo(index, x, y);
	}

	receiveInitialData = function (json) {
		var data = JSON.parse(json);

		$.extend(pageInfo, {
			resources: data.res,
			gridLines: true,
			expandFooter: false,
			selectedRowSize: data.selectedRowSize
		});

		localizePage();
		buildHeader(data.header);
		adjustLayout();
		updateUI();
		$.when($('#Toolbar,#Header').fadeIn(FX_DURATION)).done(requestPageData);
	};

	receivePageData = function (json) {
		var data = JSON.parse(json),
			detachedFooters = [];

		if (data == null)
			return;

		data.footers.forEach(function (footer) { detachedFooters.push(footer); });
		$.extend(pageInfo, {
			features: data.features,
			fields: data.fields,
			attachedData: getAttachedFootersData(data.footers, data.grandTotal),
			detachedFooters: detachedFooters
		});

		if (data.state)
			$.extend(pageInfo, {
				gridLines: data.state.gridLines,
				expandFooter: data.state.expandFooter,
				selectedRowSize: data.state.selectedRowSize
			});

		clearPage();
		buildPage(data.grid, data.state);
		ready = true;
		dirty = false;

		adjustLayout();
		updateUI();
		showPage();
	};

	receiveDefaultState = function (json) {
		var state = JSON.parse(json),
			options = kgrid.options;

		pageInfo.gridLines = state.gridLines;
		pageInfo.expandFooter = state.expandFooter;
		pageInfo.selectedRowSize = state.selectedRowSize;
		options.columns = state.columns;

		kgrid.destroy();
		$grid.empty();
		prepareGridInfo(options, null);
		buildGrid(options);
		rebuildSubGrids();
		updateUI();
		dirty = false;
	}

	receiveRowMenuInfo = function (json) {
		var info = JSON.parse(json);

		if (info.items.length) {
			buildRowMenu(info.items);
			showRowMenu(info.index, info.x, info.y);
		}
	}

	function test() {

	}

	$(function () {
		$toolbar = $('#Toolbar');
		$header = $('#Header');
		$container = $('#Container');
		$colgroups = $('#Container .a-col-groups');
		$grid = $('#Container .a-grid');
		$footers = $('#Container .a-footers');
		$rmenu = $('#RowMenu');
		attachEvents();
	});

})(jQuery);
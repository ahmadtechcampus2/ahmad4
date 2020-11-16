
########################################################## 
CREATE PROC prcStrings_init
AS
/*
This procedure:
	- is responsible for populating strings table.
	- should execute only if strings in empty
	- is usualy called from prcFinalizeDatabase
*/

	SET NOCOUNT ON

	-- Misc:
	EXEC [prcStrings_add] 'MISC\YES', N'نعم', 'Yes', 'Oui'
	EXEC [prcStrings_add] 'MISC\NO', N'لا', 'No', 'Non'
	EXEC [prcStrings_add] 'MISC\PAYTYPE_CASH', N'نقداً', N'Cash', N'Espèces'
	EXEC [prcStrings_add] 'MISC\PAYTYPE_CREDIT', N'آجل', 'On Credit', 'Crédit'

	-- insert bill_entry strings:
	EXEC [prcStrings_add] 'BILLENTRY\FIRST_PAY', N'الدفعة الأولى', 'Down Payment', 'Le Premier Payement'
	EXEC [prcStrings_add] 'BILLENTRY\FULL_PAY', N'تسديد قيمة الفاتورة', 'Full Payment', 'Le Payement de la Facture'
	EXEC [prcStrings_add] 'BILLENTRY\ITEMS_DISCOUNT', N'حسم الأقلام', 'Items Discount', 'La Réduction des Articles'
	EXEC [prcStrings_add] 'BILLENTRY\ITEMS_EXTRA', N'إضافات الأقلام', 'Items Extra', 'Les suppléments des Articles'
	EXEC [prcStrings_add] 'BILLENTRY\ITEMS_VAT', N'ضريبة القيمة المضافة  للمادة', 'VAT to  material', 'TVA de matériau'
	
	EXEC [prcStrings_add] 'BILLENTRY\ITEMS_EXCISE_SELL', N'استرداد قيمة الضريبة الانتقائية', 'Excise to  material', 'Excise de matériau'
	EXEC [prcStrings_add] 'BILLENTRY\ITEMS_EXCISE_RE_SELL', N'ارجاع استرداد الضريبة الانتقائية', 'Excise to  material', 'Excise de matériau'
	EXEC [prcStrings_add] 'BILLENTRY\ITEMS_EXCISE_PURCHASE', N'شراء خاضع للضريبة الانتقائية', 'Excise to  material', 'Excise de matériau'
	EXEC [prcStrings_add] 'BILLENTRY\ITEMS_EXCISE_RE_PURCHASE', N'ارجاع شراء خاضع للضريبة الانتقائية', 'Excise to  material', 'Excise de matériau'

	EXEC [prcStrings_add] 'BILLENTRY\ITEMS_REVERSCHARGE_SELL', N'توريد خاضع للرسوم العكسية', 'توريد خاضع للرسوم العكسية', 'توريد خاضع للرسوم العكسية'
	EXEC [prcStrings_add] 'BILLENTRY\ITEMS_REVERSCHARGE_RE_SELL', N'ارجاع توريد خاضع للضريبة العكسية', 'توريد خاضع للرسوم العكسية', 'توريد خاضع للرسوم العكسية'
	EXEC [prcStrings_add] 'BILLENTRY\ITEMS_REVERSCHARGE_PURCHASE', N'شراء خاضع للضريبة العكسية', 'توريد خاضع للرسوم العكسية', 'توريد خاضع للرسوم العكسية'
	EXEC [prcStrings_add] 'BILLENTRY\ITEMS_REVERSCHARGE_RE_PURCHASE', N'ارجاع شراء خاضع للرسوم العكسية ', 'توريد خاضع للرسوم العكسية', 'توريد خاضع للرسوم العكسية'
	EXEC [prcStrings_add] 'GCCTAX_APPLY\ENTRY_GEN_FROM_TAX_APPLY', N'متولد عن أداة تعديل ضرائب الفواتير نتيجة الفروقات', 'متولد عن أداة تعديل ضرائب الفواتير نتيجة الفروقات', 'متولد عن أداة تعديل ضرائب الفواتير نتيجة الفروقات'

	EXEC [prcStrings_add] 'BILLENTRY\ITEMS_BONUS', N'هدايا', 'Bonus', 'Les Primes'
	EXEC [prcStrings_add] 'BILLENTRY\ITEMS_TAX', N'ضريبة مبيعات', 'Sales Tax', 'La taxe de vente'
	EXEC [prcStrings_add] 'BILLENTRY\INBILLNOTE',N'فى فاتورة','In Bill','dans le projet de loi'
	EXEC [prcStrings_add] 'BILLENTRY\BILLNUMBERNOTE',N'رقم','Number','dans le projet de loi'
	EXEC [prcStrings_add] 'BILLENTRY\BILLCUSTOMERNAME',N'للعميل','For Customer','pour la clientèle'
	-- insert databaseInfo strings:
	EXEC [prcStrings_add] 'DBINFO\DBNAME',	N'اسم قاعدة البيانات على المخدم', 'Database Name on the Server', 'Le Nom de la base de données sur le serveur'
	EXEC [prcStrings_add] 'DBINFO\DBSIZE', N'حجم القاعدة', 'Database Size', 'La Taille de la base de données'
	EXEC [prcStrings_add] 'DBINFO\FILES', 'الملفات', 'Files', 'Les Fichiers'
	EXEC [prcStrings_add] 'DBINFO\FILES\CREATIONDATE', 'تاريخ إنشاء الملف', 'Database Creation Date', 'La Date de Création de la base de données'
	EXEC [prcStrings_add] 'DBINFO\FILES\VERSION', 'رقم إصدار الملف', 'Database Version', 'La version de la base de données'
	EXEC [prcStrings_add] 'DBINFO\BACKUPINFO', 'معلومات النسخ الاحتياطي', 'Backup Info', 'Les Informations de la Sauvegarde'
	EXEC [prcStrings_add] 'DBINFO\BACKUPINFO\LASTBACKUPDATE', 'تاريخ آخر نسخة احتياطية', 'Last Backup Date', 'Dernière Date de Sauvegarde '
	EXEC [prcStrings_add] 'DBINFO\BACKUPINFO\FROM',	' (منذ ', ' (from ', 'De'
	EXEC [prcStrings_add] 'DBINFO\BACKUPINFO\DAY', ' يوم)' , ' day(s))', 'Jour'
	EXEC [prcStrings_add] 'DBINFO\BACKUPINFO\INTHISDAY',	' (في هذا اليوم)', ' (in this day)', '? ce jour '
	EXEC [prcStrings_add] 'DBINFO\BACKUPINFO\FROMTHISPC', 'تمت من على الحاسب', 'from this PC', '? partir de ce PC '
	EXEC [prcStrings_add] 'DBINFO\BACKUPINFO\TOFILE', 'إلى الملف', 'To File', '? ce fichier '
	EXEC [prcStrings_add] 'DBINFO\BACKUPINFO\NONE', '<لم يتم إنشاء أية نسخة احتياطية للملف>', '<no backup has been made>', 'Aucune sauvegarde n a été faite '
	EXEC [prcStrings_add] 'DBINFO\DETAILS', 'تفصيلات إضافية', 'Other Details', 'Autres détails'
	EXEC [prcStrings_add] 'DBINFO\DETAILS\RECOVERYMODEL', 'نمط الاستعادة', 'Recovery Model', 'Modèle de Recouvrement'
	EXEC [prcStrings_add] 'DBINFO\DETAILS\DEFAULTLANGUAGE', 'اللغة الافتراضية', 'Default Language', 'Langue par défaut'
	EXEC [prcStrings_add] 'DBINFO\DETAILS\SINGLEUSERMODE', 'نمط مستخدم وحيد', 'Single User Mode', 'Mode mono-utilisateur '
	EXEC [prcStrings_add] 'DBINFO\DETAILS\ISAUTOSHRINK', 'تقليص الحجم تلقائياً', 'Is Auto-Shrink', 'Auto-Rétractable '
	EXEC [prcStrings_add] 'DBINFO\DETAILS\RECURSIVETRIGGERS', 'قوادح عودية', 'Recursive Triggers', 'Récursives Triggers'
	EXEC [prcStrings_add] 'DBINFO\MONTHSW\1', 'يناير', 'January', 'Janvier'
	EXEC [prcStrings_add] 'DBINFO\MONTHSW\2', 'فبراير', 'February', 'Février'
	EXEC [prcStrings_add] 'DBINFO\MONTHSW\3', 'مارس', 'March', 'Mars'
	EXEC [prcStrings_add] 'DBINFO\MONTHSW\4', 'أبريل', 'April', 'Avril'
	EXEC [prcStrings_add] 'DBINFO\MONTHSW\5', 'مايو', 'May', 'Mai'
	EXEC [prcStrings_add] 'DBINFO\MONTHSW\6', 'يونيو', 'June', 'Juin'
	EXEC [prcStrings_add] 'DBINFO\MONTHSW\7', 'يوليو', 'July', 'Juillet'
	EXEC [prcStrings_add] 'DBINFO\MONTHSW\8', 'أغسطس', 'August', 'Août'
	EXEC [prcStrings_add] 'DBINFO\MONTHSW\9', 'سبتمبر', 'September', 'Septembre'
	EXEC [prcStrings_add] 'DBINFO\MONTHSW\10', 'أكتوبر', 'October', 'Octobre'
	EXEC [prcStrings_add] 'DBINFO\MONTHSW\11', 'نوفمبر', 'November', 'Novembre'
	EXEC [prcStrings_add] 'DBINFO\MONTHSW\12', 'ديسمبر', 'December', 'Décembre'

	EXEC [prcStrings_add] 'DBINFO\MONTHS\1',  'كانون الثاني', 'January', 'Janvier'
	EXEC [prcStrings_add] 'DBINFO\MONTHS\2',  'شباط', 'February', 'Février'
	EXEC [prcStrings_add] 'DBINFO\MONTHS\3',  'آذار', 'March', 'Mars'
	EXEC [prcStrings_add] 'DBINFO\MONTHS\4',  'نيسان', 'April', 'Avril'
	EXEC [prcStrings_add] 'DBINFO\MONTHS\5',  'أيار', 'May', 'Mai'
	EXEC [prcStrings_add] 'DBINFO\MONTHS\6',  'حزيران', 'June', 'Juin'
	EXEC [prcStrings_add] 'DBINFO\MONTHS\7',  'تموز', 'July', 'Juillet'
	EXEC [prcStrings_add] 'DBINFO\MONTHS\8',  'آب', 'August', 'Août'
	EXEC [prcStrings_add] 'DBINFO\MONTHS\9',  'أيلول', 'September', 'Septembre'
	EXEC [prcStrings_add] 'DBINFO\MONTHS\10', 'تشرين الأول'	, 'October', 'Octobre'
	EXEC [prcStrings_add] 'DBINFO\MONTHS\11', 'تشرين الثاني', 'November', 'Novembre'
	EXEC [prcStrings_add] 'DBINFO\MONTHS\12', 'كانون الأول', 'December', 'Décembre'
	
	-- Insert POS strings:
	EXEC [prcStrings_add] 'POS\RECEIVEDFROM', 'قبض من', 'Received from', 'Received from'
	EXEC [prcStrings_add] 'POS\PAIDTO', 'دفع لـ', 'Paid to', 'Paid to'
	EXEC [prcStrings_add] 'POS\CASH', 'دفعة نقدية', 'Paid in Cash', 'Payé en espèces'
	EXEC [prcStrings_add] 'POS\CHECK', 'دفعة ورقة مالية', 'Paid by Check', 'Payé par chèque'
	EXEC [prcStrings_add] 'POS\LOYALTY_POINTS', 'نقاط الولاء', 'Loyalty Points', 'Points de fidélité'
	EXEC [prcStrings_add] 'POS\PRICE_TYPE_NONE', 'بدون', 'None'
	EXEC [prcStrings_add] 'POS\PRICE_TYPE_COST', 'الكلفة', 'Cost'
	EXEC [prcStrings_add] 'POS\PRICE_TYPE_HOLE', 'الجملة', 'Hole'
	EXEC [prcStrings_add] 'POS\PRICE_TYPE_HALF', 'نصف الجملة', 'Half'
	EXEC [prcStrings_add] 'POS\PRICE_TYPE_EXPORT', 'التصدير', 'Export'
	EXEC [prcStrings_add] 'POS\PRICE_TYPE_DIST', 'الموزع', 'Distributor'
	EXEC [prcStrings_add] 'POS\PRICE_TYPE_PIECES', 'المفرق', 'Piece'
	EXEC [prcStrings_add] 'POS\PRICE_TYPE_ENDUSER', 'المستهلك', 'End User'
	EXEC [prcStrings_add] 'POS\PRICE_TYPE_LASTBUY', 'آخر شراء', 'Last Buy'
	EXEC [prcStrings_add] 'POS\PRICE_TYPE_LASTSELL', 'آخر مبيع', 'Last Sell'
	--For Checks - POS system:
    EXEC [prcStrings_add] 'POS\NUMBER', 'رقم', 'Number', 'No.'
	EXEC [prcStrings_add] 'POS\INNERNUMBER', 'الرقم الداخلي', 'Inner Number', 'No. interne'
	EXEC [prcStrings_add] 'POS\DESTINATION', 'الجهة', 'Destination', 'destination'
	EXEC [prcStrings_add] 'POS\DATEOFPAYMENT', 'استحقاق', 'DateOfPayment', 'échéance'
	-- Entry strings
	EXEC [prcStrings_add] 'ENTRY\TAXENTRY', 'ضريبة السندات', 'Entry Tax', 'La taxe d entrée'

	-- Notification system strings
	EXEC [prcStrings_add] 'NS\MAXBALANCES', 'تجاوز بمبلغ ', 'Exceeded the amount ', 'dépassé le montant '
	EXEC [prcStrings_add] 'NS\DEBIT',  'مدين', 'debit', 'débit'
	EXEC [prcStrings_add] 'NS\CREDIT', 'دائن', 'debit', 'crédit'

	-- For general ledger report
	EXEC [prcStrings_add] 'GL\SURGEON_FEES', 'أتعاب الجراح', 'Surgeon fees', 'Les Honoraires du Chirurgien'
	EXEC [prcStrings_add] 'GL\OPERATIONS_ROOM_COST', 'تكلفة غرفة العمليات', 'Operations room cost', 'Le Coût de la Salle d’Opération'
	EXEC [prcStrings_add] 'GL\RESIDENCE', 'إقامة', 'Residence', 'Hospitalisation'
	EXEC [prcStrings_add] 'GL\GENERAL_WORK', 'عمل عام', 'General Work', 'Un Travail Public'
	EXEC [prcStrings_add] 'GL\COMPANY_OUTGOING_TRANSFER', ' حوالة شركة صادرة', 'Company Outgoing Transfer', 'Un Transfert de l’Entreprise Sortant'
	EXEC [prcStrings_add] 'GL\COMPANY_INCOMING_TRANSFER', ' حوالة شركة واردة', 'Company Incoming Transfer', 'Un transfert de l’Entreprise Entrant'
	EXEC [prcStrings_add] 'GL\RESET_CASH_DRAWER', 'تصفير الصندوق', 'Reset Cash Drawer', 'La Réinitialisation du Fonds'
	EXEC [prcStrings_add] 'GL\RECEIPT_DELIVERY_CENTERS', 'الاستلام والتسليم للمراكز', 'Receipt and Delivery to Centers', 'La Réception et la Livraison pour les Centres'
	EXEC [prcStrings_add] 'GL\EXCHANGE_RECEIPT_VOUCHER', 'سند قبض صرافة', 'Exchange Receipt Voucher', 'Un Titre de Recevoir de Change'
	EXEC [prcStrings_add] 'GL\EXCHANGE_PAYMENT_VOUCHER', 'سند دفع صرافة', 'Exchange Payment Voucher', 'Un Titre de Payer de Change'
	EXEC [prcStrings_add] 'GL\INTERNAL_TRANSFER', ' حوالة داخلية', 'Internal Transfer', 'Un Transfert Extérieur'
	EXEC [prcStrings_add] 'GL\RADIOGRAPH_ORDER', 'طلب أشعة', 'Radiograph Order', 'Demander Une Radio-Exposition Médicale'
	EXEC [prcStrings_add] 'GL\CLOSE_DOSSIER', 'إغلاق الإضبارة', 'Close Dossier', 'Fermer le Dossier'
	EXEC [prcStrings_add] 'GL\MEDICAL_CONSULTATION', 'استشارات طبية', 'Medical Consultation', 'Les Consultations Médicales'

	--for Manufacturing Bills
	EXEC [prcStrings_add] 'COSTREPS\FORM','نموذج','FORM','modèle'
	EXEC [prcStrings_add] 'COSTREPS\NUMBER', 'رقم العملية', 'Operation Number: ', 'processus de No.'
	EXEC [prcStrings_add] 'COSTREPS\QTY', 'عدد', 'qty','nombre'
	EXEC [prcStrings_add] 'Entry', N'سند قيد', 'Entry', 'Entry'
	EXEC [prcStrings_add] 'SalaryDistributionEntry', N'قيد توزيع المصاريف والرواتب حسب المواد المصروفة', 'salaries and expenses allocation entry by materials released', 'salaries and expenses allocation entry by materials released'
	
	--Hospital Strings
	EXEC [prcStrings_add] 'HOSPITAL\CLOSEDOSSIERENTRY', N'سند إغلاق الإضبارة', 'Close Dossier Entry', 'Close Dossier Entry'
	EXEC [prcStrings_add] 'HOSPITAL\PATIENT', N' المريض ', ' Patient ', ' Patient '
	EXEC [prcStrings_add] 'HOSPITAL\CONSUMABLES', N'المستهلكات العامة الإضبارة ', ' General Consumables Dossier', ' General Consumables Dossier'

	--GCC Strings
	EXEC [prcStrings_add] 'GCC\UPDATEMATERIALTAX', N'تعديل ضرائب المواد ', 'Update Material Tax', 'Update Material Tax'
	EXEC [prcStrings_add] 'GCC\UPDATECUSTOMERTAX', N'تعديل ضرائب الزبائن ', 'Update Customer Tax', 'Update Customer Tax'
	EXEC [prcStrings_add] 'GCC\UPDATEBILLTAX', N'تعديل ضرائب الفواتير ', 'Update Bill Tax', 'Update Bill Tax'

	--AMNTOOLS Strings
	EXEC [prcStrings_add] 'AmnTools\PriceType\RealPrice', N'الحقيقي', 'Real Price', 'Prix réel'
	EXEC [prcStrings_add] 'AmnTools\PriceType\MaxPrice', N'الأعظمي', 'Max Price', 'prix max'
	EXEC [prcStrings_add] 'AmnTools\PriceType\AvgPrice', N'الوسطي', 'Avg Price', 'prix moyen'
	EXEC [prcStrings_add] 'AmnTools\PriceType\LastPrice', N'آخر شراء', 'Last Price', 'Prix dernière'
	EXEC [prcStrings_add] 'AmnTools\PriceType\DefaultPrice', N'الافتراضي', 'Default Price', 'Prix par défaut'

	-- POS Smart Devices string
	EXEC [prcStrings_add] 'POS\ENTRYINSHIFTTICKETS',' قيد الدين الممنوح في بطاقات البيع في الوردية', ' Entry generated from shift tickets ', ' Entry generated from shift tickets '
	EXEC [prcStrings_add] 'POS\TOPOSCARD','لنقطة البيع ', 'of POS', ' à POS '
	EXEC [prcStrings_add] 'POS\SHIFTEMPLOYEE','الموظف', ' Employee ', ' Employé '
	EXEC [prcStrings_add] 'POS\CUSTOMERENTRY',' قيد الدين الممنوح للزبون', ' Customer Entry ', ' Customer Entry '
	EXEC [prcStrings_add] 'POS\INSHIFT',' في الوردية ', ' in shift ', ' in shift '
	EXEC [prcStrings_add] 'POS\BILLGENERATED', 'فاتورة مولدة من إقفال الوردية', 'An automatically generated invoice from closing session '
	EXEC [prcStrings_add] 'POS\ENTRYINSHIFTEXTERNALOPERATIONS','قيد العمليات الخارجية في الوردية ', ' Entry generated from shift external operations ', ' Entry generated from external operations '
	EXEC [prcStrings_add] 'POS\SHIFT','الوردية ', 'Shift ', 'Shift '
	EXEC [prcStrings_add] 'POSSD\BANK_SALE_ENTRY' ,'قيد مقبوضات المبيعات من البطاقات المصرفية - نقطة: ', 'Bank Sale Entry', 'Bank Sale Entry'
	EXEC [prcStrings_add] 'POSSD\BANK_ENTRY_SHIFT' ,' - وردية: ', ' - shift: ', ' - shift: '
	EXEC [prcStrings_add] 'POSSD\BANK_ENTRY_EMPLOYEE' ,' - الموظف: ', ' - employee: ', ' - employee: '
	EXEC [prcStrings_add] 'POSSD\BANK_CARD' ,'بطاقة مصرفية: ', 'bank card: ', 'bank card: '
	EXEC [prcStrings_add] 'POSSD\SALES_TYPE' ,' - مبيعات: ', ' - sales: ', ' - sales: '
	EXEC [prcStrings_add] 'POS\ENTRYINSHIFTRETSALESTICKETS',' قيد الدين المخصوم في بطاقات مرتجع المبيعات في الوردية', ' Entry generated from shift tickets ', ' Entry generated from shift tickets '
	EXEC [prcStrings_add] 'POS\CUSTOMERENTRYOUT',' قيد الدين المخصوم من الزبون', ' Customer Entry ', ' Customer Entry '
	EXEC [prcStrings_add] 'POSSD\SALESRETURN_TYPE' ,' - مرتجع مبيعات: ', ' - sales return: ', ' - sales return: '
	EXEC [prcStrings_add] 'POSSD\SHIFT_RECEIVE_COUPON' ,'قيد قسائم المرتجع المسلمة للزبائن في الوردية: ', 'Return coupon received in shift: ', 'Return coupon received in shift: '
    EXEC [prcStrings_add] 'POSSD\STATION_RECEIVE_COUPON' ,' لنقظة البيع: ', ' To station: ', ' To station: '
    EXEC [prcStrings_add] 'POSSD\RECEIVE_COUPON_TO_CUSTOMER' ,'قسيمة مرتجع مسلمة للزبون: ', 'Receive coupon to customer: ', ' Receive coupon to customer: '
    EXEC [prcStrings_add] 'POSSD\COUPON_EXPIRY_DATE' ,' تاريخ انتهاء صلاحية: ', ' coupon expiry Date: ', ' coupon expiry Date: '
    EXEC [prcStrings_add] 'POSSD\IN_SHIFT' ,' في الوردية: ', ' in shift: ', ' in shift: '
	EXEC [prcStrings_add] 'POSSD\SHIFT_RECEIVE_CARD' ,'قيد بطاقات المرتجع المسلمة للزبائن في الوردية: ', 'Return card received in shift: ', 'Return card received in shift: '
	EXEC [prcStrings_add] 'POSSD\RECEIVE_CARD_TO_CUSTOMER' ,'بطاقة مرتجع مسلمة للزبون: ', 'Receive card to customer: ', ' Receive card to customer: '
	EXEC [prcStrings_add] 'POSSD\SHIFT_PAY_COUPON' ,'قيد قسائم المرتجع المستلمة من الزبائن في الوردية: ', 'Return coupon Paid in shift: ', 'Return coupon Paid in shift: '
	EXEC [prcStrings_add] 'POSSD\PAY_COUPON_FROM_CUSTOMER' ,'قسيمة مرتجع مستلمة من الزبون: ', 'Paid coupon from customer: ', ' Paid coupon from customer: '
	EXEC [prcStrings_add] 'POSSD\SHIFT_PAY_CARD' ,'قيد بطاقات المرتجع المستلمة من الزبائن في الوردية: ', 'Return card Paid in shift: ', 'Return card Paid in shift: '
	EXEC [prcStrings_add] 'POSSD\PAY_CARD_FROM_CUSTOMER' ,'بطاقة مرتجع مستلمة من الزبون: ', 'Paid card from customer: ', ' Paid card from customer: '
	EXEC [prcStrings_add] 'POSSD\EXPIRED_RETURN_COUPON' ,'سند قيد متولد عن معالجة قسائم وبطاقات المرتجع حتى تاريخ: ', 'Expired return coupon', ' Expired return coupon'
	EXEC [prcStrings_add] 'POSSD\CANCEL_RETURN_COUPON' ,'إلغاء قسيمة مرتجع رقم: ', 'Cancel return coupon number: ', ' Cancel return coupon number: '
	EXEC [prcStrings_add] 'POSSD\CANCEL_RETURN_CARD' ,'إلغاء بطاقة مرتجع رقم: ', 'Cancel return card number: ', ' Cancel return card number: '
	EXEC [prcStrings_add] 'POSSD\DELIVERED_TO_CUST' ,'مسلمة للزبون: ', 'Delivered to customer: ', 'Delivered to customer: '
	EXEC [prcStrings_add] 'POSSD\EXPIRY_DATE' ,'تاريخ انتهاء صلاحية: ', 'Expiry date: ', 'Expiry date: '
	EXEC [prcStrings_add] 'POSSD\SATURDAY' ,'السبت', 'Saturday', 'Saturday'
	EXEC [prcStrings_add] 'POSSD\SUNDAY' ,'الأحد', 'Sunday', 'Sunday'
	EXEC [prcStrings_add] 'POSSD\MONDAY' ,'الإثنين', 'Monday', 'Monday'
	EXEC [prcStrings_add] 'POSSD\TUESDAY' ,'الثلاثاء', 'Tuesday', 'Tuesday'
	EXEC [prcStrings_add] 'POSSD\WEDNESDAY' ,'الأربعاء', 'Wednesday', 'Wednesday'
	EXEC [prcStrings_add] 'POSSD\THURSDAY' ,'الخميس', 'Thursday', 'Thursday'
	EXEC [prcStrings_add] 'POSSD\FRIDAY' ,'الجمعة', 'Friday', 'Friday'
	EXEC [prcStrings_add] 'POSSD\DISCOUNT' ,'حسم', 'Discount', 'Discount'
	EXEC [prcStrings_add] 'POSSD\SLIDE' ,'الشرائح', 'Slide', 'Slide'
	EXEC [prcStrings_add] 'POSSD\BOGO' ,'اشتري واحداً وخذ واحد', 'BOGO', 'BOGO'
	EXEC [prcStrings_add] 'POSSD\BOGSE' ,'اشتري واحداً وخذ شيئاً آخر', 'BOGSE', 'BOGSE '
	EXEC [prcStrings_add] 'POSSD\BUNDLE' ,'الباقة', 'BUNDLE', 'BUNDLE'
	EXEC [prcStrings_add] 'POSSD\SXGD' ,'أنفق وخذ حسماً', 'SXGD', 'SXGD'
	EXEC [prcStrings_add] 'POSSD\SGP' ,'أنفق وخذ مادة', 'SGP', 'SGP'
	EXEC [prcStrings_add] 'POSSD\ALLSPECIALOFFERS' ,'مجموع العروض', 'ALLSPECIALOFFERS', 'ALLSPECIALOFFERS'
	EXEC [prcStrings_add] 'POSSD\ALLDAYSOFWEEK' ,'كل أيام الأسبوع', 'All days Of Week', 'All days Of Week'
	EXEC [prcStrings_add] 'POSSD\ReceiveDownPayment' ,'استلام دفعة أولى', 'Receive down payment', 'Receive down payment'
	EXEC [prcStrings_add] 'POSSD\ReturnDownPayment' ,'إعادة دفعة أولى', 'Return down payment', 'Return down payment'
	EXEC [prcStrings_add] 'POSSD\ReceiveDriverPayment' ,'استلام دفعة السائق', 'Receive driver payment', 'Receive driver payment'
	EXEC [prcStrings_add] 'POSSD\ReturnDriverPayment' ,'إعادة دفعة السائق', 'Return driver payment', 'Return driver payment'
	EXEC [prcStrings_add] 'POSSD\SettlementDriverPayment' ,'تصفية دفعة السائق', 'Settlement driver payment', 'Settlement driver payment'
	EXEC [prcStrings_add] 'POSSD\GCCTaxValueForMat' ,'ضريبة القيمة المضافة للمادة: ', 'VAT tax for material: ', 'TVA pour matériel:'
	EXEC [prcStrings_add] 'POSSD\GCCTaxSaleTransaction' ,' على عملية مبيعات رقم: ', ' on sale transaction number: ', ' Numéro de transaction en vente: '
	EXEC [prcStrings_add] 'POSSD\Customer' ,' زبون: ', ' customer: ', ' customer: '
	EXEC [prcStrings_add] 'POSSD\CustomerTransient' ,'زبون عابر', 'customer transient', 'customer transient'
	EXEC [prcStrings_add] 'POSSD\GCCLocation' ,' موقع: ', ' location: ', ' emplacement: '
	EXEC [prcStrings_add] 'POSSD\Employee',' الموظف: ', ' Employee: ', ' Employé: '
	EXEC [prcStrings_add] 'POSSD\Station',' نقطة البيع: ', ' POS: ', ' POS: '
	EXEC [prcStrings_add] 'POSSD\ShiftNumber',' وردية: ', ' shift: ', ' shift: '
	EXEC [prcStrings_add] 'POSSD\GCCTaxSalesEntry','قيد ضريبة القيمة المضافة لعمليات المبيعات في الوردية: ', 'VAT entry of sales from shift: ', 'VAT entry of sales from shift: '
	EXEC [prcStrings_add] 'POSSD\GCCTaxSalesReturnEntry','قيد ضريبة القيمة المضافة لعمليات مرتجع المبيعات في الوردية: ', 'VAT entry of sales return from shift: ', 'VAT entry of sales return from shift: '
	EXEC [prcStrings_add] 'POSSD\OrderDeliveryFee','أجور توصيل طلب ', ' Delivery fees ', ' Frais de livraison '
	EXEC [prcStrings_add] 'POSSD\ForCustomer',' للزبون: ', ' for customer: ', ' customer: '
	EXEC [prcStrings_add] 'POSSD\InSalesTicket',' في عملية بيع: ', ' in the sales ticket: ', ' dans le ticket de vente: '
	EXEC [prcStrings_add] 'POSSD\AndDriver',' و السائق: ', ' and driver: ', ' and driver: '
	EXEC [prcStrings_add] 'POSSD\OrderDeliveryFeeEntry','قيد أجور التوصيل في الوردية: ', ' Delivery fees ', ' Frais de livraison '

	EXEC [prcStrings_add] 'POSSD\OrderDownPaymentEntry','تصفية الدفعة الأولى', 'Order Down Payment', 'Order Down Payment'
	EXEC [prcStrings_add] 'POSSD\Order',' طلب: ', ' Order: ', ' Order: '
	EXEC [prcStrings_add] 'POSSD\Delivery','توصيل', 'Delivery', 'Delivery'
	EXEC [prcStrings_add] 'POSSD\Pickup','تسليم', 'Pickup', 'Pickup'


	--PFC
	EXEC [prcStrings_add] 'PFC\SHIPEMENT_PURCHASE_TO_PROFIT_CENTER', N'شراء مباشر في مركز الربحية', 'Direct Purchase in Profit Center', 'Achat direct dans le centre de profit'
	EXEC [prcStrings_add] 'PFC\SHIPEMENT__PURCHASE_FROM_PROFIT_CENTER_WITH_RETURN', N'مرتجع شراء مباشر في مركز الربحية', 'Direct Purchase Returns in Profit Center', 'Rendu d''''achat direct dans le centre de profit'
	EXEC [prcStrings_add] 'PFC\SHIPEMENT_TO_PROFIT_CENTER', N'الشحن إلى مركز ربحية', 'Shipping to a Profit Center', 'Chargement au centre de profit'
	EXEC [prcStrings_add] 'PFC\SHIPEMENT_RETURN_FROM_PROFIT_CENTER', N'مرتجع الشحن من مركز ربحية', 'Shipping Returns from a Profit Center', 'Rendu de Chargement du Centre de Profit'

	--Manufacturing
	EXEC [prcStrings_add] 'MN\MANUFACTURE', N'عملية تصنيع', 'Manufacture Operation', 'Opération de Fabrication'
	EXEC [prcStrings_add] 'MN\PRODUCTIONPLANCARD', N'خطة انتاج', 'Production Plan', 'le Plan de Production'

	--Account
	EXEC [prcStrings_add] 'ACC\ACCCHECKDATE', N'مطابقة رصيد حساب', 'Balance Reconciliation', 'Réconciliation de Solde de Compte'

	--Orders
	EXEC [prcStrings_add] 'AmnOrders\SaveOrderMsgReciver\OpType\New', N'(جديد)', '(New)', '(Nouveau)'
	EXEC [prcStrings_add] 'AmnOrders\SaveOrderMsgReciver\OpType\Edit', N'(تعديل)', '(Modify)', '(Modifier)'
	EXEC [prcStrings_add] 'AmnOrders\SaveOrderMsgReciver\OpType\Cancel', N'(إلغاء)', '(Cancel)', '(Annuler)'
	EXEC [prcStrings_add] 'AmnOrders\SaveOrderMsgReciver\OpType\Close', N'(إنهاء)', '(End)', '(Terminer)'
	EXEC [prcStrings_add] 'AmnOrders\SaveOrderMsgReciver\OpType\Delete', N'(حذف)', '(Delete)', '(Supprimer)'

	--Distribution
	EXEC [prcStrings_add] 'Distribution\AndroidDistribution', N'أندرويد توزيع', 'Android Distribution', 'Android Distribution'
	EXEC [prcStrings_add] 'Distribution\DistributionUnit', N'وحدة التوزيع', 'Distribution Unit', 'Unité de la Distribution'
#########################################################
#END

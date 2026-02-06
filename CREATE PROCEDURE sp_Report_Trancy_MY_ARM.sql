ALTER PROCEDURE sp_Report_Trancy_MY_ARMaster
    @FromDate DATETIME = NULL, 
    @ToDate   DATETIME = NULL,
    @CurrentCompany UNIQUEIDENTIFIER,
    @Organisation UNIQUEIDENTIFIER	
AS
BEGIN
    SET NOCOUNT ON;

SELECT 
    AH_InvoiceDate AS InvoiceDate,
    AH_TransactionNum AS InvoiceNum,
    AL_RX_NKTransactionCurrency AS CostCurr,
    AL_Desc AS ChargeDesc,
    AL_GSTVAT AS LocalTaxAmount,
    AL_OSAmount AS LineTotal,
    AT_Code AS TaxCode,
    AC_Code AS ChargeCode,
    JH_JobNum AS JobNum,
    JH_GS_NKRepSales AS Sales,
    AC_Code AS ChargeCode,

    CASE
        WHEN CCM.AR_Code IS NULL THEN 'ERROR'
    END AS ChargeMappedCodeError,

    CASE
        WHEN CCM.AR_Code IS NOT NULL THEN CCM.AR_Code
    END AS ChargeMappedCode,

    CASE 
        WHEN AL_RX_NKTransactionCurrency = 'MYR'
            THEN AL_LineAmount
        WHEN JF_BaseRate IS NULL OR JF_BaseRate = 0
            THEN AL_LineAmount
        ELSE
            AL_LineAmount / JF_BaseRate
    END AS LocalAmount,

    CASE 
        WHEN AL_RX_NKTransactionCurrency = 'MYR' THEN 1
        ELSE COALESCE(JF_BaseRate, 1)
    END AS BaseRate,

    CASE
        WHEN CHARINDEX('|', OrgCusCode.OK_CustomsRegNo) > 0
            THEN LEFT(
                OrgCusCode.OK_CustomsRegNo,
                CHARINDEX('|', OrgCusCode.OK_CustomsRegNo) - 1
            )
        ELSE OrgCusCode.OK_CustomsRegNo
    END AS CleanCustomsRegNo,

    CASE 
        WHEN AH_InvoiceTerm = 'COD' THEN 'CASH'
        WHEN AH_InvoiceTerm = 'INV' 
            THEN CONCAT(AH_InvoiceTermDays, ' DAYS') 
    END AS InvoiceTerms,

    CASE 
        WHEN AL_RX_NKTransactionCurrency = 'MYR' THEN 1
        ELSE RE.RE_SellRate
    END AS TodaysRate,
    CASE
        WHEN AT_Code = 'SVC'        THEN 'SV-8'
        WHEN AT_Code = 'SVCLOW'     THEN 'SV-6'
        WHEN AT_Code = 'SVCEXT'     THEN 'ESV-6_1'
        WHEN AT_Code = 'SVCNOTAPP'  THEN 'SV-0'
        WHEN AT_Code = 'SVCREV'     THEN 'SV-8'
        WHEN AT_Code = 'SVCREVLOW'  THEN 'SV-6'
        WHEN AT_Code = 'SVCREVEXT'  THEN 'ESV-6_1'
        WHEN AT_Code = 'FREESVC'    THEN 'SV-0'
        ELSE AT_Code
    END AS MappedTaxCode

    FROM dbo.JobHeader

    LEFT JOIN dbo.AccTransactionHeader 
        ON AH_JH = JH_PK

    LEFT JOIN dbo.AccTransactionLines 
        ON AL_AH = AH_PK

    LEFT JOIN dbo.OrgHeader 
        ON AH_OH = OH_PK

    OUTER APPLY (
        SELECT TOP 1 *
        FROM dbo.JobExRate
        WHERE JF_JH = JH_PK
            AND JF_RX_NKRateCurrency = AL_RX_NKTransactionCurrency
        ORDER BY JF_PK
    ) JF

    LEFT JOIN dbo.AccTaxRate
        ON AL_AT = AT_PK

    LEFT JOIN dbo.AccChargeCode
        ON AL_AC = AC_PK


    OUTER APPLY (
        SELECT TOP 1 *
        FROM dbo.OrgCusCode
        WHERE OK_OH = OH_PK
          AND OK_CustomsRegNO LIKE '%300%'
          AND OK_CodeType = 'LSC'
        ORDER BY OK_PK
    ) OrgCusCode

    OUTER APPLY (
        SELECT TOP 1 *
        FROM dbo.ZZRefExchangeRate
        WHERE RE_RX_NKExCurrency =  AL_RX_NKTransactionCurrency
          AND AH_PostDate <= RE_ExpiryDate
          AND AH_PostDate >= RE_StartDate
          AND RE_ExRateType = 'BUY'
    ) RE
    OUTER APPLY(
        SELECT TOP 1
        AR_Code
        FROM dbo.ChargeCodeMap  AS M
        WHERE M.Prefix = AC_Code 
    ) CCM
    WHERE
        (@FromDate IS NULL OR AH_InvoiceDate >= @FromDate)
        AND (@ToDate IS NULL OR AH_InvoiceDate < DATEADD(DAY, 1, @ToDate))
        AND (@Organisation IS NULL OR OH_PK = @Organisation)
        AND AH_GC = @CurrentCompany
        AND AH_Ledger = 'AR'
        AND AH_TransactionType = 'INV'
    ORDER BY 
        JH_JobNum;
END
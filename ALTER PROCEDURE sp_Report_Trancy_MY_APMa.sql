ALTER PROCEDURE sp_Report_Trancy_MY_APMaster
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
    ABS(AL_OSAmount) AS LineTotal,
    AT_Code AS TaxCode,
    AC_Code AS ChargeCode,
    JH_JobNum AS JobNum,
    JH_GS_NKRepSales AS Sales,
    SUBSTRING(
        OrgCusCode.OK_CustomsRegNo,
        CHARINDEX('|', OrgCusCode.OK_CustomsRegNo) + 1,
        LEN(OrgCusCode.OK_CustomsRegNo)
    ) AS CleanCustomsRegNo,

    CASE
        WHEN CCM.AP_Code IS NULL THEN 'ERROR'
        ELSE CCM.AP_Code
    END AS ChargeMappedCode,
    ABS(
    CASE 
        WHEN AL_RX_NKTransactionCurrency = 'MYR'
            THEN AL_LineAmount
        WHEN JF_BaseRate IS NULL OR JF_BaseRate = 0
            THEN AL_LineAmount
        ELSE
            AL_LineAmount / JF_BaseRate
    END) AS LocalAmount,

    CASE 
        WHEN AL_RX_NKTransactionCurrency = 'MYR' THEN 1
        ELSE COALESCE(JF_BaseRate, 1)
    END AS BaseRate,

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
        WHEN AT_Code = 'SVC'        THEN 'PS-8'
        WHEN AT_Code = 'SVCLOW'     THEN 'PS-6'
        WHEN AT_Code = 'SVCEXT'     THEN ''
        WHEN AT_Code = 'SVCNOTAPP'  THEN ''
        WHEN AT_Code = 'SVCREV'     THEN 'SV-8'
        WHEN AT_Code = 'SVCREVLOW'  THEN 'SV-6'
        WHEN AT_Code = 'SVCREVEXT'  THEN ''
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
          AND OK_CustomsRegNO LIKE '%|400%'
          AND OK_CodeType = 'LSC'
        ORDER BY OK_PK
    ) OrgCusCode

    OUTER APPLY (
        SELECT TOP 1 *
        FROM dbo.OrgCompanyData
        WHERE OB_OH = OH_PK
        ORDER BY OB_PK
    ) OB
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
        AP_Code
        FROM dbo.ChargeCodeMap 
        WHERE AC_Code LIKE Prefix
    ) CCM
    WHERE
        (@FromDate IS NULL OR AH_InvoiceDate >= @FromDate)
        AND (@ToDate IS NULL OR AH_InvoiceDate < DATEADD(DAY, 1, @ToDate))
        AND (@Organisation IS NULL OR OH_PK = @Organisation)
        AND AH_GC = @CurrentCompany
        --AND AH_GB = @CurrentBranch
        AND AH_Ledger = 'AP'
    ORDER BY 
        JH_JobNum;
END
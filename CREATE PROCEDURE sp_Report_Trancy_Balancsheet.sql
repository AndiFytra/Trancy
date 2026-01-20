ALTER PROCEDURE sp_Report_Trancy_BalanceSheet
    @CurrentCompany UNIQUEIDENTIFIER,
    @ShipmentPK UNIQUEIDENTIFIER
AS
BEGIN
SET NOCOUNT ON

    SELECT

        AH_ConsolidatedInvoiceRef AS InternalRef,
        -- CHARGE INFORMATION
        JR_Desc AS ChargeDesc,
        -- CHARGE CODE + CHARGE GROUP INFORMATION
        AC_Code AS ChargeCode,
        AC_ChargeGroup AS ChargeGroup,
        JH_JobNum AS JobNum,

        -- COST
        FORMAT(JR_OSCostAmt, 'N2') AS OSCostAmount,
        JR_RX_NKCostCurrency AS OSCostCurrency,
        GC_RX_NKLocalCurrency AS LocalCostCurrency,
        FORMAT(JR_LocalCostAmt, 'N2') AS LocalCostAmount,
        JR_OSCostGSTAmt AS OSCostTaxAmount,
        Creditor.OH_Code AS CreditorCode,
        Creditor.OH_FullName AS CreditorName,
        CostTaxRate.AT_Code AS CostTaxCode,
        FORMAT(SUM(
        CASE 
            WHEN JR_RX_NKCostCurrency = 'JPY'
            THEN ISNULL(JR_OSCostAmt,0 )
            ELSE 0 
        END
        ) OVER (PARTITION BY AC_ChargeGroup),'N2') AS TotalOSCostAmount_JPY,
        FORMAT(SUM(
        CASE 
            WHEN JR_RX_NKCostCurrency <> 'JPY' 
                THEN ISNULL(JR_LocalCostAmt,0) 
            ELSE 0 
        END
        ) OVER (PARTITION BY AC_ChargeGroup),'N2') AS TotalLocalCostAmount_JPY,
        CASE
            WHEN CHARINDEX('-', JR_Desc) > 0
            THEN LEFT(JR_Desc, CHARINDEX('-', JR_Desc) - 1)
            ELSE JR_Desc
        END AS CostDesc,

        CASE
            WHEN CHARINDEX('-', JR_Desc) > 0
            AND CHARINDEX('@', JR_Desc) > CHARINDEX('-', JR_Desc)
            AND CHARINDEX('@', JR_Desc) - CHARINDEX('-', JR_Desc) > 1
            THEN
                LTRIM(RTRIM(
                    SUBSTRING(
                        JR_Desc,
                        CHARINDEX('-', JR_Desc) + 1,
                        CHARINDEX('@', JR_Desc) - CHARINDEX('-', JR_Desc) - 1
                    )
                ))
            ELSE NULL
        END AS Quantity,

        -- Unit Price
        CASE
            WHEN CHARINDEX('@', JR_Desc) > 0
            AND CHARINDEX('/', JR_Desc) > CHARINDEX('@', JR_Desc)
            AND CHARINDEX('/', JR_Desc) - CHARINDEX('@', JR_Desc) > 1
            THEN
                LTRIM(RTRIM(
                    SUBSTRING(
                        JR_Desc,
                        CHARINDEX('@', JR_Desc) + 1,
                        CHARINDEX('/', JR_Desc) - CHARINDEX('@', JR_Desc) - 1
                    )
                ))
            ELSE NULL
        END AS UnitPrice,

        -- SELL
        FORMAT(JR_OSSellAmt, 'N2') AS OSSellAmount,
        JR_RX_NKSellCurrency AS OSSellCurrency,
        GC_RX_NKLocalCurrency AS LocalSellCurrency,
        FORMAT(JR_LocalSellAmt,'N2') AS LocalSellAmount,
        JR_OSSellWHTAmt AS OSSellTaxAmount,
        Debtor.OH_Code AS DebtorCode,
        Debtor.OH_FullName AS DebtorName,
        SellTaxRate.AT_Code AS SellTaxCode,
        FORMAT(SUM(
        CASE 
            WHEN JR_RX_NKSellCurrency = 'JPY'
            THEN ISNULL(JR_OSSellAmt,0 )
            ELSE 0 
        END
        ) OVER (PARTITION BY AC_ChargeGroup),'N2') AS TotalOSSellAmount_JPY,
        FORMAT(SUM(
        CASE 
            WHEN JR_RX_NKSellCurrency <> 'JPY' 
            THEN ISNULL(JR_LocalSellAmt,0) 
            ELSE 0 
        END
        ) OVER (PARTITION BY AC_ChargeGroup),'N2') AS TotalSellLocalAmount_JPY,
        -- CONSOL INFORMATION
        JK_UniqueConsignRef AS ConsolNo,
        JK_MasterBillNum AS ConsolMasterBillNum,
        JK_AgentType AS ConsolAgentType,
        JK_ConsolMode AS ConsolMode,
        JK_TransportMode AS ConsolTransportMode,

        ReceivingAgent.OH_Code AS ReceivingAgentCode,
        SendingAgent.OH_Code AS SendingAgentCode,

        -- VESSEL/VOYAGE INFORMATION
        CASE
            WHEN GC_RN_NKCountryCode = LEFT(JS_RL_NKOrigin, 2)
                AND GC_RN_NKCountryCode = LEFT(JS_RL_NKDestination, 2)
                THEN 'DOM'

            WHEN GC_RN_NKCountryCode = LEFT(JS_RL_NKOrigin, 2)
                THEN 'EXP'

            WHEN GC_RN_NKCountryCode = LEFT(JS_RL_NKDestination, 2)
                THEN 'IMP'

            ELSE 'CROSS'
        END AS ShipmentDirection,

        FirstLastConsolTransport.FirstVessel AS Vessel,
	    FirstLastConsolTransport.FirstTransportVoyageFlight AS Voyage,

        -- SHIPMENT INFORMATION
        JS_UniqueConsignRef AS ShipmentNo,
        JS_HouseBill AS HouseBill,
        JS_RL_NKOrigin AS ShipmentOrigin,
        JS_RL_NKDestination AS ShipmentDestination,

        JS_E_DEP AS ShipmentETD,
        JS_E_ARV AS ShipmentETA,
        
        JS_TransportMode AS ShipmentTransportMode,
        JS_PackingMode AS ShipmentContainerMode


    FROM 
        JobCharge
    
    -- CHARGE CODE
    LEFT JOIN
        AccChargeCode
            ON AC_PK = JR_AC

    -- TAX CODE
    LEFT JOIN 
        AccTaxRate AS CostTaxRate
            ON CostTaxRate.AT_PK = JR_AT_CostGSTRate
    
    LEFT JOIN 
        AccTaxRate AS SellTaxRate
            ON SellTaxRate.AT_PK = JR_AT_SellGSTRate

    -- SHIPMENT AND CONSOL
    LEFT JOIN 
        JobHeader
            ON JH_PK = JR_JH
    LEFT JOIN
        JobShipment
            ON JS_PK = JH_ParentID
    LEFT JOIN
        JobConShipLink
            ON JN_JS = JS_PK
    LEFT JOIN
        JobConsol
            ON JK_PK = JN_JK

    -- ORGANISATION (DEBTOR / CREDITOR)
    LEFT JOIN OrgHeader AS Creditor
        ON Creditor.OH_PK = JR_OH_CostAccount

    LEFT JOIN OrgHeader AS Debtor  
        ON Debtor.OH_PK = JR_OH_SellAccount

    -- SENDING AND FORWARDER ADDRESS
    LEFT JOIN dbo.OrgAddress AS ReceivingAgentAddress ON ReceivingAgentAddress.OA_PK = JobConsol.JK_OA_ReceivingForwarderAddress 
	LEFT JOIN dbo.OrgHeader AS ReceivingAgent ON ReceivingAgent.OH_PK = ReceivingAgentAddress.OA_OH 

    LEFT JOIN dbo.OrgAddress AS SendingAgentAddress ON SendingAgentAddress.OA_PK = JobConsol.JK_OA_SendingForwarderAddress 
	LEFT JOIN dbo.OrgHeader AS SendingAgent ON SendingAgent.OH_PK = SendingAgentAddress.OA_OH 

    -- ROUTING TAB
    LEFT JOIN dbo.uViewFirstLastConsolTransportWithVessel AS FirstLastConsolTransport 
                ON FirstLastConsolTransport.ParentType = 'CON' 
                AND FirstLastConsolTransport.JK = JK_PK
    
    -- BELONG TO WHICH COMPANY
    LEFT JOIN GlbCompany
        AS Company ON Company.GC_PK = JR_GC
    
    LEFT JOIN dbo.AccTransactionHeader
        ON AH_JH = JH_PK


WHERE
    -- Company filter
    ( @CurrentCompany IS NULL OR JR_GC = @CurrentCompany )

    AND
    (
        @ShipmentPK IS NOT NULL
        AND JS_PK = @ShipmentPK
    )
END
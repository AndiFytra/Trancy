CREATE PROCEDURE sp_Report_Trancy_BalanceSheetHeader
    @CurrentCountry   VARCHAR(2),
    @CompanyPK        UNIQUEIDENTIFIER,
    @ShipmentPK       UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 

        JobShipment.JS_PK AS JobShipmentPK,
        JS_UniqueConsignRef AS ShipmentID,
        JS_HouseBill AS HouseBill,
        JS_INCO AS INCO,
        JS_BookingReference AS BookingReference,
        JS_UniqueConsignRef AS ShipmentRef,

        --Remarks
        Remarks.XV_Data AS Remarks,
        BurdenCode.XV_Data AS BurdenCode,
        --Transaction Number
        Inv.Invoices AS TransactionNum,
        -- Currency
        CASE
            WHEN JobExRates.BaseRate1 IS NULL OR JobExRates.Currency1 IS NULL
            THEN NULL
            ELSE JobExRates.Currency1 + ' : JPY ' + FORMAT(JobExRates.BaseRate1, 'N2')
        END AS BaseRate1Display,

        CASE
            WHEN JobExRates.BaseRate2 IS NULL OR JobExRates.Currency2 IS NULL
            THEN NULL
            ELSE JobExRates.Currency2 + ' : JPY ' + FORMAT(JobExRates.BaseRate2, 'N2')
        END AS BaseRate2Display,

        CASE
            WHEN JobExRates.BaseRate3 IS NULL OR JobExRates.Currency3 IS NULL
            THEN NULL
            ELSE JobExRates.Currency3 + ' : JPY ' + FORMAT(JobExRates.BaseRate3, 'N2')
        END AS BaseRate3Display,

        CASE
            WHEN JobExRates.BaseRate4 IS NULL OR JobExRates.Currency4 IS NULL
            THEN NULL
            ELSE JobExRates.Currency4 + ' : JPY ' + FORMAT(JobExRates.BaseRate4, 'N2')
        END AS BaseRate4Display,

        CASE
            WHEN JobExRates.BaseRate5 IS NULL OR JobExRates.Currency5 IS NULL
            THEN NULL
            ELSE JobExRates.Currency5 + ' : JPY ' + FORMAT(JobExRates.BaseRate5, 'N2')
        END AS BaseRate5Display,

        CASE
            WHEN JobExRates.BaseRate6 IS NULL OR JobExRates.Currency6 IS NULL
            THEN NULL
            ELSE JobExRates.Currency6 + ' : JPY ' + FORMAT(JobExRates.BaseRate6, 'N2')
        END AS BaseRate6Display,
        
        JobExRates.CurrOrg1 AS CurrOrg1,
        JobExRates.CurrOrg2 AS CurrOrg2 ,
        JobExRates.CurrOrg3 AS CurrOrg3,
        JobExRates.CurrOrg4 AS CurrOrg4,
        JobExRates.CurrOrg5 AS CurrOrg5,
        JobExRates.CurrOrg6 AS CurrOrg6,

        -- CONSOL DETAILS
        JK_PK AS JobConsolPK,
        JK_UniqueConsignRef AS ConsolID,
        JK_PrepaidCollect AS PrepaidCollect,
        JK_OA_DepartureCTOAddress AS CTOAddress,
        JK_OA_PackDepotAddress AS CFSAddress,
        JK_OA_ContainerYardEmptyPickupAddress AS ContainerParkAddress,
        CarrierCode.OH_Code AS Carrier,
        LoadPort      = MainConTrans.JW_RL_NKLoadPort,
        DischargePort = MainConTrans.JW_RL_NKDiscPort,
        Vessel        = MainConTrans.JW_Vessel,
        Voyage        = MainConTrans.JW_VoyageFlight,
        JW_ETD        = MainConTrans.JW_ETD,
        JW_ETA        = MainConTrans.JW_ETA,

        JW_ATD        = MainConTrans.JW_ATD,
        JW_ATA        = MainConTrans.JW_ATA,

        OrigUNLOCO.RL_Code AS OrigUNLOCOCode,
        DestUNLOCO.RL_Code AS DestUNLOCOCode,
        OrigUNLOCO.RL_PortName AS OrigUNLOCOName,
        DestUNLOCO.RL_PortName AS DestUNLOCOName,
        OrigRefCountry.RN_Code AS OrigCountryCode,
        OrigRefCountry.RN_Desc AS OrigCountryName,
        DestRefCountry.RN_Code AS DestCountryCode,
        DestRefCountry.RN_Desc AS DestCountryName,
        OrigUNLOCO.RL_PK AS OrigUNLOCOPK,
        DestUNLOCO.RL_PK AS DestUNLOCOPK,
        OrigRefCountry.RN_PK AS OrigCountryPK,
        DestRefCountry.RN_PK AS DestCountryPK,

        JOScontacts.JS_E2_ContactConsingor AS ShipmentBookedBy,
        JS_TransportMode AS ShipmentTransportMode,
        JS_PackingMode AS PackingMode,
        JS_RL_NKOrigin AS ShipmentOrigin,
        JS_RL_NKDestination AS ShipmentDestination,
        JS_RS_NKServiceLevel AS ServiceLevel,
        JS_E_DEP AS ShipmentETD,
        JS_E_ARV AS ShipmentETA,

        ConsigneeOrg.FullName AS ConsigneeFullName,
        ConsigneeOrg.OH_Code AS Consignee,
        ConsigneeOrg.OH_PK AS ConsigneePK,
        ConsignorOrg.OH_Code AS Consignor,
        ConsignorOrg.FullName AS ConsignorFullName,
        ConsignorOrg.OH_PK AS ConsignorPK,

        JS_OH_ImportBroker AS ImportBrokerPK,

        JS_ActualWeight AS ActualWeight,
        JS_UnitOfWeight AS UnitOfWeight,
        JS_ActualChargeable AS ActualChargeable,

        CASE 
            WHEN JS_TransportMode IN ('SEA','FSA','RAI') THEN 
                CASE 
                    WHEN JS_UnitOfWeight IN ('LB','OZ','LT','OT') AND 
                         JS_UnitOfVolume IN ('CF','CY','CI') 
                    THEN 'CF' ELSE 'M3' 
                END
            ELSE
                CASE 
                    WHEN JS_UnitOfWeight IN ('LB','OZ','LT','OT') AND 
                         JS_UnitOfVolume IN ('CF','CY','CI') 
                    THEN 'LB' ELSE 'KG' 
                END
        END AS ActualChargeableUnits,

        (SELECT Value FROM dbo.ConvertWeight(JS_ActualWeight, JS_UnitOfWeight, 'KG')) AS EquivalentWeight,
        'KG' AS EquivalentWeightUnits,
        JS_ActualVolume AS ActualVolume,
        JS_UnitOfVolume AS UnitOfVolume,
        (SELECT Value FROM dbo.ConvertVolume(JS_ActualVolume, JS_UnitOfVolume, 'M3')) AS EquivalentVolume,
        'M3' AS EquivalentVolumeUnits,

        JS_OuterPacks AS OuterPacks,
        JS_F3_NKPackType AS UnitOfOuterPacks,

        JS_GoodsDescription AS GoodsDescription,

        -- Shipment Docs tab fields
        JS_DocumentedWeight AS DocumentedWeight,
        JS_DocumentedVolume AS DocumentedVolume,
        JS_DocumentedChargeable AS DocumentedChargeable,
        JS_ManifestedWeight AS ManifestedWeight,
        JS_ManifestedVolume AS ManifestedVolume,
        JS_ManifestedChargeable AS ManifestedChargeable,
        JS_HouseBillOfLadingType AS HouseBillOfLadingType,
        JS_HouseBillIssueDate AS HouseBillIssueDate,
        JS_ShippedOnBoard AS ShippedOnBoardType,
        JS_ShippedOnBoardDate AS ShippedOnBoardDate,
        JS_NoOriginalBills AS NoOriginalBills,
        JS_NOCopyBills AS NoCopyBills,

        Containers.ContainerCount AS ContainerCount,
        Containers.TotalTEU AS TEUSum,
        CTT.ContainerInfo AS ContainerSummary,

        CASE WHEN JobShipment.JS_IsCFSRegistered = 1 THEN 'Y' ELSE 'N' END AS ShipmentIsCFSRegistered,
        CASE WHEN JobShipment.JS_IsForwardRegistered = 1 THEN 'Y' ELSE 'N' END AS ShipmentIsForwardRegistered,
        CASE WHEN JobShipment.JS_IsBooking = 1 THEN 'Y' ELSE 'N' END AS ShipmentIsBooking,

        CASE WHEN JobConsol.JK_IsForwarding = 1 THEN 'Y' ELSE 'N' END AS ConsolIsForwarding,
        CASE WHEN JobConsol.JK_IsCFS = 1 THEN 'Y' ELSE 'N' END AS ConsolIsCFS

    FROM dbo.JobShipment
    LEFT JOIN dbo.JobHeader
        ON JS_PK = JH_ParentID
    LEFT JOIN dbo.FCLShipmentContainers('') AS Containers
        ON JS_PK = Containers.ShipmentPK
    LEFT JOIN dbo.ContainerTypeTotalsByJobShipment() AS CTT
        ON CTT.JobShipmentPk = JobShipment.JS_PK
    LEFT JOIN dbo.ctfn_JobShipmentOrg('CRD') AS ConsignorOrg
        ON JobShipment.JS_PK = ConsignorOrg.JS_PK
    LEFT JOIN dbo.ctfn_JobShipmentOrg('CED') AS ConsigneeOrg
        ON JobShipment.JS_PK = ConsigneeOrg.JS_PK
    LEFT JOIN dbo.cvw_JobShipmentContacts AS JOScontacts
        ON JobShipment.JS_PK = JOScontacts.JS_PK
    LEFT JOIN dbo.JobConShipLink 
        ON JobConShipLink.JN_PK = (
                SELECT TOP 1 JobConShipLink1.JN_PK
                FROM dbo.JobConShipLink AS JobConShipLink1
                WHERE JobConShipLink1.JN_JS = JobShipment.JS_PK
            )
    LEFT JOIN dbo.JobConsol  
        ON JobConsol.JK_PK = JobConShipLink.JN_JK
    LEFT JOIN
	(
		SELECT
			JW_JK,
			JW_RL_NKLoadPort = MIN(JW_RL_NKLoadPort),
			JW_RL_NKDiscPort = MIN(JW_RL_NKDiscPort),
			JW_Vessel        = MIN(JW_Vessel),
			JW_VoyageFlight  = MIN(JW_VoyageFlight),
			JW_ETD           = MIN(JW_ETD),
			JW_ETA           = MIN(JW_ETA),
			JW_ATD           = MIN(JW_ATD),
			JW_ATA           = MIN(JW_ATA)
		FROM
			dbo.csfn_MainConsolTransport(@CurrentCountry)
		GROUP BY
			JW_JK
	) AS MainConTrans ON MainConTrans.JW_JK = JobConsol.JK_PK
    LEFT JOIN dbo.RefUNLOCO AS OrigUNLOCO  
        ON OrigUNLOCO.RL_Code = JobShipment.JS_RL_NKOrigin
    LEFT JOIN dbo.RefUNLOCO AS DestUNLOCO  
        ON DestUNLOCO.RL_Code = JobShipment.JS_RL_NKDestination
    LEFT JOIN dbo.RefCountry AS OrigRefCountry  
        ON OrigRefCountry.RN_Code = OrigUNLOCO.RL_RN_NKCountryCode
    LEFT JOIN dbo.RefCountry AS DestRefCountry  
        ON DestRefCountry.RN_Code = DestUNLOCO.RL_RN_NKCountryCode
    LEFT JOIN dbo.OrgAddress AS CarrierAdd
        ON  JK_OA_ShippingLineAddress = CarrierAdd.OA_PK
    LEFT JOIN dbo.OrgHeader AS CarrierCode
        ON CarrierCode.OH_PK = CarrierAdd.OA_OH
    OUTER APPLY (
        SELECT
            STRING_AGG(XV_Data, ', ') AS Invoices
        FROM dbo.GenCustomAddOnValue
        WHERE XV_ParentID = JobShipment.JS_PK
        AND XV_Name LIKE 'Shipper''s Commercial Invoice %'
        AND XV_Data IS NOT NULL
    ) Inv

    OUTER APPLY GetCustomFieldByName(JobShipment.JS_PK,'Burden Code') BurdenCode


    OUTER APPLY GetCustomFieldByName(JobShipment.JS_PK,'Remarks') Remarks

    OUTER APPLY (
        SELECT
            MAX(CASE WHEN rn = 1 THEN JF_BaseRate END) AS BaseRate1,
            MAX(CASE WHEN rn = 2 THEN JF_BaseRate END) AS BaseRate2,
            MAX(CASE WHEN rn = 3 THEN JF_BaseRate END) AS BaseRate3,
            MAX(CASE WHEN rn = 4 THEN JF_BaseRate END) AS BaseRate4,
            MAX(CASE WHEN rn = 5 THEN JF_BaseRate END) AS BaseRate5,
            MAX(CASE WHEN rn = 6 THEN JF_BaseRate END) AS BaseRate6,

            MAX(CASE WHEN rn = 1 THEN JF_RX_NKRateCurrency END) AS Currency1,
            MAX(CASE WHEN rn = 2 THEN JF_RX_NKRateCurrency END) AS Currency2,
            MAX(CASE WHEN rn = 3 THEN JF_RX_NKRateCurrency END) AS Currency3,
            MAX(CASE WHEN rn = 4 THEN JF_RX_NKRateCurrency END) AS Currency4,
            MAX(CASE WHEN rn = 5 THEN JF_RX_NKRateCurrency END) AS Currency5,
            MAX(CASE WHEN rn = 6 THEN JF_RX_NKRateCurrency END) AS Currency6,

            MAX(CASE WHEN rn = 1 THEN OH_FullName END) AS CurrOrg1,
            MAX(CASE WHEN rn = 2 THEN OH_FullName END) AS CurrOrg2,
            MAX(CASE WHEN rn = 3 THEN OH_FullName END) AS CurrOrg3,
            MAX(CASE WHEN rn = 4 THEN OH_FullName END) AS CurrOrg4,
            MAX(CASE WHEN rn = 5 THEN OH_FullName END) AS CurrOrg5,
            MAX(CASE WHEN rn = 6 THEN OH_FullName END) AS CurrOrg6
        FROM (
            SELECT
                JF_RX_NKRateCurrency,
                JF_BaseRate,
                OH_FullName,
                ROW_NUMBER() OVER (ORDER BY JF_RX_NKRateCurrency) rn
            FROM (
                SELECT *,
                    ROW_NUMBER() OVER (
                        PARTITION BY JF_RX_NKRateCurrency
                        ORDER BY JF_PK DESC
                    ) dedupe
                FROM dbo.JobExRate
                WHERE JF_JH = JH_PK
            ) d
            LEFT JOIN 
                dbo.OrgHeader ON OH_PK = d.JF_OH_Org
            WHERE dedupe = 1
        ) r
    ) JobExRates

    WHERE JS_IsCancelled != 1
      AND (
            JobShipment.JS_IsCFSRegistered = 1
         OR JobShipment.JS_IsForwardRegistered = 1
         OR (JobShipment.JS_IsShipping = 0 AND JobShipment.JS_IsBooking = 1)
      )
      AND JobShipment.JS_PK = @ShipmentPK

END
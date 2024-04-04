library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use std.textio.all;

library OSVVM;
    context OSVVM.OsvvmContext;

library osvvm_common;
    context osvvm_common.OsvvmCommonContext;

package SpiTbPkg is

    ------------------------------------------------------------
    -- SPI Data Type (Wordsize) & Error Generation Vector Type
    ------------------------------------------------------------
    subtype SpiTb_DataType      is std_logic_vector(7 downto 0);
    subtype SpiTb_ErrorModeType is std_logic_vector(0 downto 0);

    ------------------------------------------------------------
    -- SPI Transaction Record Type
    ------------------------------------------------------------
    subtype SpiRecType is StreamRecType(
        DataToModel    (SpiTb_DataType'range),
        ParamToModel   (SpiTb_ErrorModeType'range),
        DataFromModel  (SpiTb_DataType'range),
        ParamFromModel (SpiTb_ErrorModeType'range)
    );
    ------------------------------------------------------------
    -- SPI Clock Type: Max
    ------------------------------------------------------------
    subtype SpiClkType is time range 40 ns to 1 ms;

    ------------------------------------------------------------
    -- SPI Mode Types
    ------------------------------------------------------------

    subtype SpiModeType is natural range 0 to 3;
    subtype SpiCPHAType is natural range 0 to 1;
    subtype SpiCPOLType is natural range 0 to 1;

    ------------------------------------------------------------
    -- SPI Options
    ------------------------------------------------------------
    type SpiOptionType is (
        SET_SCLK_PERIOD,
        SET_SPI_MODE
    );

    ------------------------------------------------------------
    -- Constants for SPI clock frequency
    ------------------------------------------------------------
    constant SPI_SCLK_PERIOD_1K  : SpiClkType := 1   ms;
    constant SPI_SCLK_PERIOD_1M  : SpiClkType := 1   us;
    constant SPI_SCLK_PERIOD_10M : SpiClkType := 100 ns;
    constant SPI_SCLK_PERIOD_25M : SpiClkType := 40  ns;

    ------------------------------------------------------------
    -- Logging and Error Message String Constants
    ------------------------------------------------------------
    constant BST_ERR_MSG : string := "BurstFifo Empty during burst transfer";
    constant OPT_ERR_MSG : string := "SetOptions, Unimplemented Option: ";
    constant DRV_ERR_MSG : string := "Multiple Drivers on Transaction Record.";

    ------------------------------------------------------------
    -- Setters
    ------------------------------------------------------------
    procedure SetSclkPeriod(
        signal   TransactionRec : inout StreamRecType;
        constant Period         : SpiClkType
    );

    procedure SetSpiParams(
        signal OptSpiMode     : SpiModeType;
        signal CPOL           : SpiCPOLType;
        signal CPHA           : SpiCPHAType;
        signal OutOnFirstEdge : boolean
    );
    ------------------------------------------------------------
    -- SPI Parameter Helpers
    ------------------------------------------------------------
    pure function GetCPOL          (SpiMode : in SpiModeType) return natural;
    pure function GetCPHA          (SpiMode : in SpiModeType) return natural;
    pure function OddEdgeOut   (SpiMode : in SpiModetype) return boolean;

    ------------------------------------------------------------
    -- Convenience Procedures
    ------------------------------------------------------------
    procedure GoIdle(
        signal CSEL : std_logic;
        signal SCKL : std_logic;
        signal PICO : std_logic;
        signal POCI : std_logic;
        signal CPOL : SpiCPOLType
        );

end SpiTbPkg;

package body SpiTbPkg is

    ------------------------------------------------------------
    -- SetSclkPeriod: Sets SCLK and internal clock period
    ------------------------------------------------------------
    procedure SetSclkPeriod(
        signal   TransactionRec : inout StreamRecType;
        constant Period         : SpiClkType
    ) is
    begin
        SetModelOptions(TransactionRec, SpiOptionType'pos(SET_SCLK_PERIOD), Period);
    end procedure SetSclkPeriod;
    ------------------------------------------------------------
    -- SetSpiMode: Sets device SPI operation mode (0 - 3)
    ------------------------------------------------------------
    procedure SetSpiMode(
        signal   TransactionRec : inout StreamRecType;
        constant SpiMode        : SpiModeType
    ) is
    begin
        SetModelOptions(TransactionRec, SpiOptionType'pos(SET_SPI_MODE), value);
    end procedure;

    ------------------------------------------------------------
    -- SetSpiParams: Helper function for SetSpiMode
    ------------------------------------------------------------
    procedure SetSpiParams(
        signal OptSpiMode     : SpiModeType;
        signal CPOL           : SpiCPOLType;
        signal CPHA           : SpiCPHAType;
        signal OutOnFirstEdge : boolean
    ) is
    begin
        CPOL <= GetCPOL(OptSpiMode);
        CPHA <= GetCPHA(OptSpiMode);
        OutOnFirstEdge <= OddEdgeOut(OptSpiMode);
    end procedure SetSpiParams;

    ------------------------------------------------------------
    -- GoIdle:
    ------------------------------------------------------------
    procedure GoIdle(
        signal CSEL : std_logic;
        signal SCKL : std_logic;
        signal PICO : std_logic;
        signal POCI : std_logic;
        signal CPOL : SpiCPOLType
        ) is
    begin
        CSEL <= '1';
        PICO <= '0';
        POCI <= '0';
        SCLK <= '0' when CPOL = 0 else '1';
    end procedure GoIdle;

    ------------------------------------------------------------
    -- GetCPOL: Helper function for SetSpiMode
    ------------------------------------------------------------
    function GetCPOL(SpiMode : in SpiModeType) return SpiCPOLType is
        variable retval : SpiCPOLType;
    begin
        if SpiMode = 0 or SpiMode = 1 then
            retval := 0;
        else
            retval := 1;
        end if;
        return retval;
    end function GetCPOL;

    ------------------------------------------------------------
    -- GetCPHA: Helper function for SetSpiMode
    ------------------------------------------------------------
    pure function GetCPHA(SpiMode : in SpiModeType) return SpiCPHAType is
        variable retval : SpiCPHAType;
    begin
        if SpiMode = 0 or SpiMode = 2 then
            retval := 0;
        else
            retval := 1;
        end if;
        return retval;
    end function GetCPHA;

    ------------------------------------------------------------
    -- OddEdgeOut: Returns true if data out on odd edges
    ------------------------------------------------------------
    pure function OddEdgeOut (SpiMode : in SpiModetype) return boolean is
        variable retval : boolean;
    begin
        if SpiMode = 1 or SpiMode = 3 then
            retval := TRUE;
        else
            retval := FALSE;
        end if;
    end function OddEdgeOut;

end SpiTbPkg;

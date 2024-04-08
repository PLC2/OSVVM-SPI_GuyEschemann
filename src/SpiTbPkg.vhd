library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.numeric_std_unsigned.all;

library OSVVM;
    context OSVVM.OsvvmContext;

library osvvm_common;
    context osvvm_common.OsvvmCommonContext;
    use osvvm.ScoreboardPkg_slv.all;


package SpiTbPkg is
    ----------------------------------------------------------------------------
    -- SPI Data Type (Wordsize) & Error Generation Vector Type
    ----------------------------------------------------------------------------
    subtype SpiTb_DataType      is std_logic_vector(7 downto 0);
    subtype SpiTb_ErrorModeType is std_logic_vector(0 downto 0); -- not used

    ----------------------------------------------------------------------------
    -- SPI Transaction Record Type
    ----------------------------------------------------------------------------
    subtype SpiRecType is StreamRecType(
        DataToModel    (SpiTb_DataType'range),
        ParamToModel   (SpiTb_ErrorModeType'range),
        DataFromModel  (SpiTb_DataType'range),
        ParamFromModel (SpiTb_ErrorModeType'range)
    );

    ----------------------------------------------------------------------------
    -- SPI Clock Type: Max speed 25MHz Min speed 1kHz
    ----------------------------------------------------------------------------
    subtype SpiClkType is time range 40 ns to 1 ms;

    ----------------------------------------------------------------------------
    -- SPI Mode
    ----------------------------------------------------------------------------
    subtype SpiModeType is natural range 0 to 3;

    ----------------------------------------------------------------------------
    -- SPI Options
    ----------------------------------------------------------------------------
    type SpiOptionType is (
        SET_SCLK_PERIOD,
        SET_SPI_MODE
    );

    ----------------------------------------------------------------------------
    -- Constants for SPI clock frequency
    ----------------------------------------------------------------------------
    constant SPI_SCLK_PERIOD_1K  : SpiClkType := 1   ms;
    constant SPI_SCLK_PERIOD_1M  : SpiClkType := 1   us;
    constant SPI_SCLK_PERIOD_10M : SpiClkType := 100 ns;
    constant SPI_SCLK_PERIOD_25M : SpiClkType := 40  ns;

    ----------------------------------------------------------------------------
    -- Logging and Error Message String Constants
    ----------------------------------------------------------------------------
    constant BST_ERR_MSG : string := "BurstFifo Empty during burst transfer";
    constant OPT_ERR_MSG : string := "SetOptions, Unimplemented Option: ";
    constant DRV_ERR_MSG : string := "Multiple Drivers on Transaction Record.";

    ----------------------------------------------------------------------------
    -- Setters
    ----------------------------------------------------------------------------
    procedure SetSclkPeriod(
        signal   TransactionRec : inout StreamRecType;
        constant Period         : SpiClkType
    );

    procedure SetSpiMode(
        signal   TransactionRec : inout StreamRecType;
        constant SpiMode        : SpiModeType
    );

    procedure SetSpiParams(
        signal OptSpiMode     : in  SpiModeType;
        signal CPOL           : out std_logic;
        signal CPHA           : out std_logic;
        signal OutOnRise      : out boolean;
        signal InOnRise       : out boolean
    );

    ----------------------------------------------------------------------------
    -- SPI Parameter Helpers
    ----------------------------------------------------------------------------
    pure function GetCPOL      (SpiMode : in SpiModeType) return std_logic;
    pure function GetCPHA      (SpiMode : in SpiModeType) return std_logic;
    pure function GetInOnRise  (SpiMode : in SpiModeType) return boolean;
    pure function GetOutOnRise (SpiMode : in SpiModetype) return boolean;

    ----------------------------------------------------------------------------
    -- Convenience Procedures
    ----------------------------------------------------------------------------
    procedure SpiGoIdle(
        signal CSEL : out std_logic;
        signal PICO : out std_logic
        );

end SpiTbPkg;

package body SpiTbPkg is
    ----------------------------------------------------------------------------
    -- SetSclkPeriod: Sets SCLK and internal clock period
    ----------------------------------------------------------------------------
    procedure SetSclkPeriod(
        signal   TransactionRec : inout StreamRecType;
        constant Period         : SpiClkType
    ) is
    begin
        SetModelOptions(TransactionRec,
                        SpiOptionType'pos(SET_SCLK_PERIOD),
                        Period);
    end procedure SetSclkPeriod;

    ----------------------------------------------------------------------------
    -- SetSpiMode: Sets SPI device TX/RX characteristics
    ----------------------------------------------------------------------------
    procedure SetSpiMode(
        signal   TransactionRec : inout StreamRecType;
        constant SpiMode        : SpiModeType
    ) is
    begin
        SetModelOptions(TransactionRec,
                        SpiOptionType'pos(SET_SPI_MODE),
                        SpiMode);
    end procedure SetSpiMode;

    ----------------------------------------------------------------------------
    -- SetSpiParams: Helper function for SetSpiMode
    ----------------------------------------------------------------------------
    procedure SetSpiParams(
        signal OptSpiMode : in  SpiModeType;
        signal CPOL       : out std_logic;
        signal CPHA       : out std_logic;
        signal OutOnRise  : out boolean;
        signal InOnRise   : out boolean
    ) is
    begin
        CPOL      <= GetCPOL(OptSpiMode);
        CPHA      <= GetCPHA(OptSpiMode);
        OutOnRise <= GetOutOnRise(OptSpiMode);
        InOnRise  <= GetInOnRise(OptSpiMode);
    end procedure SetSpiParams;

    ----------------------------------------------------------------------------
    -- GoIdle:
    ----------------------------------------------------------------------------
    procedure SpiGoIdle(
        signal CSEL : out std_logic;
        signal PICO : out std_logic
        ) is
    begin
        CSEL <= '1';
        PICO <= '0';
    end procedure SpiGoIdle;

    ----------------------------------------------------------------------------
    -- GetCPOL: Helper function for SetSpiMode returns CPOL value
    ----------------------------------------------------------------------------
    function GetCPOL(SpiMode : in SpiModeType) return std_logic is
        variable retval : std_logic := '0';
    begin
        retval := '1' when SpiMode = 2 or SpiMode = 3;
        return retval;
    end function GetCPOL;

    ----------------------------------------------------------------------------
    -- GetCPHA: Helper function for SetSpiMode returns CPHA value
    ----------------------------------------------------------------------------
    pure function GetCPHA(SpiMode : in SpiModeType) return std_logic is
        variable retval : std_logic := '0';
    begin
        retval := '1' when SpiMode = 1 or SpiMode = 3;
        return retval;
    end function GetCPHA;

    ----------------------------------------------------------------------------
    -- GetOutOnRise: Returns true if data out on odd edges
    ----------------------------------------------------------------------------
    pure function GetOutOnRise (SpiMode : in SpiModetype) return boolean is
        variable retval : boolean := FALSE;
    begin
        retval := TRUE when  SpiMode = 1 or SpiMode = 2;
        return retval;
    end function GetOutOnRise;

    ----------------------------------------------------------------------------
    -- GetInOnRise: Returns true if data clocked in on SCLK rising edge
    ----------------------------------------------------------------------------
    pure function GetInOnRise (SpiMode : in SpiModeType) return boolean is
        variable retval : boolean := FALSE;
    begin
        retval := TRUE when SpiMode = 0 or SpiMode = 3 ;
        return retval;
    end function GetInOnRise;
end SpiTbPkg;

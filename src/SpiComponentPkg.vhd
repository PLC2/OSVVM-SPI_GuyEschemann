--
--  File Name:         SpiComponentPkg.vhd
--  Design Unit Name:  SpiComponentPkg
--  OSVVM Release:     TODO
--
--  Description:
--      A package containing the SPI Controller and Peripheral verification
--      component declaration.
--

library ieee;
    use ieee.std_logic_1164.all;

library OSVVM;
    context OSVVM.OsvvmContext;

use work.SpiTbPkg.all;

package SpiComponentPkg is

    component SpiController is
        generic(
            MODEL_ID_NAME       : string        := "";
            SPI_MODE            : SpiModeType   := 0;
            SCLK_PERIOD         : SpiClkType    := SPI_SCLK_PERIOD_1M
        );
        port(
            TransRec : inout   SpiRecType;
            SCLK     : out     std_logic;
            CSEL     : out     std_logic;
            PICO     : out     std_logic;
            POCI     : in      std_logic
        );
    end component SpiController;

    component SpiPeripheral is
        generic(
            MODEL_ID_NAME : string      := "";
            SPI_MODE      : SpiModeType := 0
        );
        port(
            TransRec : inout  SpiRecType;
            SCLK     : in     std_logic;
            CSEL     : in     std_logic;
            PICO     : in     std_logic;
            POCI     : out    std_logic
        );
    end component SpiPeripheral;

end package SpiComponentPkg;

--
--  File Name:         TbSpi.vhd
--  Design Unit Name:  TbSpi
--  OSVVM Release:     TODO
--
--  Description:
--    SPI verification component testbench
--

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

use std.textio.all;

library osvvm;
    context osvvm.OsvvmContext;

library osvvm_spi;
    context osvvm_spi.SpiContext;

entity TbSpi is
end TbSpi;

architecture TestHarness of TbSpi is
    -- Test Bench Constants
    constant tperiod_Clk      : time := 10 ns;
    constant tpd              : time :=  2 ns;
    constant spi_mode         : SpiModeType := 0;

    -- Global Signals
    signal Clk              : std_logic;
    signal n_Reset          : std_logic;

    -- Testbench Control Records
    signal SpiControllerRec : SpiRecType;
    signal SpiPeripheralRec : SpiRecType;

    -- SPI Controller Signals
    signal SCLK : std_logic;
    signal CSEL : std_logic;
    signal PICO : std_logic;
    signal POCI : std_logic;

    component TestCtrl
        port(
            SpiControllerRec : inout SpiRecType;
            SpiPeripheralRec : inout SpiRecType;
            Clk              : in    std_logic;
            n_Reset          : in    std_logic
        );
    end component;

begin

    ------------------------------------------------------------
    -- Create Clock
    ------------------------------------------------------------
    Osvvm.TbUtilPkg.CreateClock(
        Clk    => Clk,
        Period => tperiod_Clk
    );

    ------------------------------------------------------------
    -- Create Reset
    ------------------------------------------------------------
    Osvvm.TbUtilPkg.CreateReset(
        Reset       => n_Reset,
        ResetActive => '0',
        Clk         => Clk,
        Period      => 7 * tperiod_Clk,
        tpd         => tpd
    );

    ------------------------------------------------------------
    -- SPI Devices
    ------------------------------------------------------------
    SpiController_1 : SpiController
        generic map(
            SPI_MODE => spi_mode
        )
        port map(
            TransRec => SpiControllerRec,
            SCLK     => SCLK,
            CSEL     => CSEL,
            PICO     => PICO,
            POCI     => POCI
        );

    SpiPeripheral_1 : SpiPeripheral
        generic map(
            SPI_MODE => spi_mode
        )
        port map(
            TransRec => SpiPeripheralRec,
            SCLK     => SCLK,
            CSEL     => CSEL,
            PICO     => PICO,
            POCI     => POCI
        );
    ------------------------------------------------------------
    -- Stimulus generation and synchronization
    ------------------------------------------------------------
    TestCtrl_1 : TestCtrl
        port map(
            SpiControllerRec => SpiControllerRec,
            SpiPeripheralRec => SpiPeripheralRec,
            Clk              => Clk,
            n_Reset          => n_Reset
        );

end TestHarness;

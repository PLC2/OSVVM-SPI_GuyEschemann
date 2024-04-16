--
--  File Name:         TestCtrl_e.vhd
--  Design Unit Name:  TestCtrl
--  OSVVM Release:     TODO
--
--  Maintainer:        Guy Eschemann  email: guy@noasic.com
--  Contributor(s):
--     Guy Eschemann   guy@noasic.com
--
--  Description:
--    Entity declaration for the SPI master verification component
--    testbench controller.
--

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.numeric_std_unsigned.all;
    use std.textio.all;

library OSVVM;
    context OSVVM.OsvvmContext;

library osvvm_spi;
    context osvvm_spi.SpiContext;

use work.OsvvmTestCommonPkg.all;

entity TestCtrl is
    port(
        -- Record Interface
        SpiControllerRec : inout SpiRecType;
        SpiPeripheralRec : inout SpiRecType;
        -- Global Signal Interface
        Clk              : in    std_logic;
        n_Reset          : in    std_logic
    );
end entity;

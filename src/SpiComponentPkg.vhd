--
--  File Name:         SpiComponentPkg.vhd
--  Design Unit Name:  SpiComponentPkg
--  OSVVM Release:     TODO
--
--  Maintainer:        Guy Eschemann  email: guy@noasic.com
--  Contributor(s):
--     Guy Eschemann   guy@noasic.com
--
--  Description:
--      A package containing the SPI component declaration to facilitate usage of component instantiation
--
--  Revision History:
--    Date      Version    Description
--    06/2022   2022.06    Initial version
--
--  This file is part of OSVVM.
--
--  Copyright (c) 2022 Guy Escheman
--
--  Licensed under the Apache License, Version 2.0 (the "License");
--  you may not use this file except in compliance with the License.
--  You may obtain a copy of the License at
--
--      https://www.apache.org/licenses/LICENSE-2.0
--
--  Unless required by applicable law or agreed to in writing, software
--  distributed under the License is distributed on an "AS IS" BASIS,
--  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--  See the License for the specific language governing permissions and
--  limitations under the License.
--

library ieee;
use ieee.std_logic_1164.all;

library OSVVM;
context OSVVM.OsvvmContext;

use work.SpiTbPkg.all;

package SpiComponentPkg is

    component SpiDevice is
        generic(
            MODEL_ID_NAME       : string        := "";
            DEFAULT_SCLK_PERIOD : time          := SPI_SCLK_PERIOD_1M;
            DEVICE_TYPE         : SpiDeviceType := SPI_CONTROLLER;
            SPI_MODE            : SpiModeType   := 0
        );
        port(
            TransRec : inout   SpiRecType;
            SCLK     : inout   std_logic;
            CSEL       : inout   std_logic;     -- slave select (low active)
            PICO     : inout   std_logic;
            POCI     : inout   std_logic
        );
    end component SpiDevice;

end package SpiComponentPkg;

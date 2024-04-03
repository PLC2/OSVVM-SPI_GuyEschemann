-- Maybe add txlog and rx log procedures to this package.
--  File Name:         SpiTbPkg.vhd
--  Design Unit Name:  SpiTbPkg
--  OSVVM Release:     TODO
--
--  Maintainer:        Guy Eschemann  email: guy@noasic.com
--  Contributor(s):
--     Guy Eschemann   guy@noasic.com
--
--  Description:
--      Constant and Transaction Support for OSVVM SPI master model
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
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use std.textio.all;

library OSVVM;
context OSVVM.OsvvmContext;

library osvvm_common;
context osvvm_common.OsvvmCommonContext;

package SpiTbPkg is

    ------------------------------------------------------------
    -- SPI Data and Error Injection Settings for Transaction Support
    ------------------------------------------------------------
    subtype SpiTb_DataType      is std_logic_vector(7 downto 0);
    subtype SpiTb_ErrorModeType is std_logic_vector(0 downto 0); -- currently not used

    ------------------------------------------------------------
    -- SPI Transaction Record derived from StreamRecType
    ------------------------------------------------------------
    subtype SpiRecType is StreamRecType(
        DataToModel    (SpiTb_DataType'range),
        ParamToModel   (SpiTb_ErrorModeType'range),
        DataFromModel  (SpiTb_DataType'range),
        ParamFromModel (SpiTb_ErrorModeType'range)
    );

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
    constant SPI_SCLK_PERIOD_1M  : time := 1 us;
    constant SPI_SCLK_PERIOD_10M : time := 100 ns;

    ------------------------------------------------------------
    -- Logging and Error Message String Constants
    ------------------------------------------------------------
    constant BST_ERR_MSG : string := "BurstFifo Empty during burst transfer";
    constant OPT_ERR_MSG : string := "SetOptions, Unimplemented Option: ";
    constant DRV_ERR_MSG : string := "Multiple Drivers on Transaction Record."
    ------------------------------------------------------------
    -- SetSclkPeriod
    ------------------------------------------------------------
    procedure SetSclkPeriod(
        signal   TransactionRec : inout StreamRecType;
        constant Period         : time
    );

    procedure SetSpiParams(
        signal OptSpiMode     : SpiModeType;
        signal CPOL           : SpiCPOLType;
        signal CPHA           : SpiCPHAType;
        signal OutOnFirstEdge : boolean
    );

    -- Opt Parameter Checkers
    pure function ValidSclkPeriod (period : in time) return boolean

    -- SPI Parameters
    pure function GetCPOL          (SpiMode : in SpiModeType) return natural;
    pure function GetCPHA          (SpiMode : in SpiModeType) return natural;
    pure function IsFirstEdgeOut   (SpiMode : in SpiModetype) return boolean;

end SpiTbPkg;

package body SpiTbPkg is

    ------------------------------------------------------------
    -- SetSclkPeriod:
    ------------------------------------------------------------
    procedure SetSclkPeriod(
        signal   TransactionRec : inout StreamRecType;
        constant Period         : time
    ) is
    begin
        SetModelOptions(TransactionRec, SpiOptionType'pos(SET_SCLK_PERIOD), Period);
    end procedure SetSclkPeriod;

    procedure SetCPOL(
        signal   TransactionRec : inout StreamRecType;
        constant value          : natural range 0 to 1
    ) is
    begin
        SetModelOptions(TransactionRec, SpiOptionType'pos(SET_CPOL), value);
    end procedure;

    procedure SetSpiParams(
        signal OptSpiMode     : SpiModeType;
        signal CPOL           : SpiCPOLType;
        signal CPHA           : SpiCPHAType;
        signal OutOnFirstEdge : boolean
    ) is
    begin
        CPOL <= GetCPOL(OptSpiMode);
        CPHA <= GetCPHA(OptSpiMode);
        OutOnFirstEdge <= IsFirstEdgeOut(OptSpiMode);
    end procedure SetSpiParams;

    ------------------------------------------------------------
    -- CheckSclkPeriod:  Parameter Check
    ------------------------------------------------------------
    pure function ValidSclkPeriod(period : in time) return boolean is
    begin
        if period > 0 sec then
            return TRUE;
        else
            return FALSE;
        end if;
    end function ValidSclkPeriod;

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

    pure function IsFirstEdgeOut (SpiMode : in SpiModetype) return boolean is
        variable retval : boolean;
    begin
        if SpiMode = 1 or SpiMode = 3 then
            retval := TRUE;
        else
            retval := FALSE;
        end if;
    end function IsFirstEdgeOut;

end SpiTbPkg;

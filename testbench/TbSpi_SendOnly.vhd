--
--  File Name:         TbSpi_Operation1.vhd
--  Design Unit Name:  Operation1
--  OSVVM Release:     TODO
--
--  Maintainer:        Guy Eschemann  email: guy@noasic.com
--  Contributor(s):
--     Guy Eschemann   guy@noasic.com
--
--  Description:
--      Normal operation testcase for the SPI master verification component
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

architecture SendOnly of TestCtrl is

    signal TestDone : integer_barrier := 1;
    signal TbID     : AlertLogIDType;

begin

    ------------------------------------------------------------
    -- Bench Environment Init
    ------------------------------------------------------------
    ControlProc : process
    begin
        -- Initialization of test
        SetTestName("TbSpi_SendOnly");
        SetLogEnable(PASSED, TRUE);
        TbID <= GetAlertLogID("TB");

        -- Wait for testbench initialization
        wait for 0 ns; wait for 0 ns;
        TranscriptOpen(OSVVM_RESULTS_DIR & "TbSpi_SendOnly.txt");
        SetTranscriptMirror(TRUE) ;

        -- Wait for Design Reset
        wait until n_Reset = '1';
        ClearAlerts;

        -- Wait for test to finish
        WaitForBarrier(TestDone, 10 ms);
        AlertIf(now >= 10 ms, "Test finished due to timeout");
        AlertIf(GetAffirmCount < 1, "Test is not Self-Checking");

        TranscriptClose;

        EndOfTestReports;
        std.env.stop;
        wait;
    end process ControlProc;

    ------------------------------------------------------------
    -- SpiControllerTest: Simple
    ------------------------------------------------------------
    SpiControllerTest : process
        variable SpiControllerID  : AlertLogIDType;
        variable TransactionCount : integer := 0;

    begin
        -- Enable logging for SPI Controller and Peripheral
        GetAlertLogID(SpiControllerRec, SpiControllerID);
        SetLogEnable(SpiControllerID, INFO, TRUE);

        -- Test Begins
        WaitForClock(SpiControllerRec, 2);

        --SPI Mode 0: Send
        Send(SpiControllerRec, X"AA");
        WaitForClock(SpiControllerRec, 2);

        --SPI Mode 1: Send
        SetSpiMode(SpiControllerRec, 1);
        Send(SpiControllerRec, X"AA");
        WaitForClock(SpiControllerRec, 2);

        --SPI Mode 2: Send
        SetSpiMode(SpiControllerRec, 2);
        Send(SpiControllerRec, X"AA");
        WaitForClock(SpiControllerRec, 1);

        --SPI Mode 3: Send
        SetSpiMode(SpiControllerRec, 3);
        Send(SpiControllerRec, X"AA");
        WaitForClock(SpiControllerRec, 1);


        -- Test ends
        WaitForBarrier(TestDone);
        wait;
    end process SpiControllerTest;

end SendOnly;

configuration TbSpi_SendOnly of TbSpi is
    for TestHarness
        for TestCtrl_1 : TestCtrl
            use entity work.TestCtrl(SendOnly);
        end for;
    end for;
end TbSpi_SendOnly;

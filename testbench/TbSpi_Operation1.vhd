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

architecture Operation1 of TestCtrl is

    signal TestDone : integer_barrier := 1;
    signal TbID     : AlertLogIDType;

begin

    ------------------------------------------------------------
    -- Bench Environment Init
    ------------------------------------------------------------
    ControlProc : process
    begin
        -- Initialization of test
        SetTestName("TbSpi_Operation1");
        SetLogEnable(PASSED, TRUE);     -- Enable PASSED logs
        TbID <= GetAlertLogID("TB");

        -- Wait for testbench initialization
        wait for 0 ns; wait for 0 ns;
        TranscriptOpen(OSVVM_RESULTS_DIR & "TbSpi_Operation1.txt");
        SetTranscriptMirror(TRUE) ;

        -- Wait for Design Reset
        wait until n_Reset = '1';
        ClearAlerts;

        -- Wait for test to finish
        WaitForBarrier(TestDone, 10 ms);
        AlertIf(now >= 10 ms, "Test finished due to timeout");
        AlertIf(GetAffirmCount < 1, "Test is not Self-Checking");

        TranscriptClose;
        --   AlertIfDiff("./results/TbUart_Options1.txt", "../Uart/testbench/validated_results/TbUart_Options1.txt", "") ; 

        EndOfTestReports;
        std.env.stop(GetAlertCount);
        wait;
    end process ControlProc;

    ------------------------------------------------------------
    -- SpiControllerTest: Simple
    ------------------------------------------------------------
    SpiControllerTest : process
        variable SpiProcID : AlertLogIDType;

    begin
        -- Logging
        GetAlertLogID(SpiControllerRec, SpiProcID);
        SetLogEnable(SpiProcID, INFO, TRUE);
        WaitForclock(SpiControllerRec, 2);

        -- Send Some Words
        WaitForClock(SpiControllerRec, 5);
        Send(SpiControllerRec, X"AA");
        SetSpiMode(SpiControllerRec, 1);
        WaitForClock(SpiControllerRec, 5);
        Send(SpiControllerRec, X"AA");
        SetSpiMode(SpiControllerRec, 2);
        WaitForClock(SpiControllerRec, 5);
        Send(SpiControllerRec, X"AA");
        SetSpiMode(SpiControllerRec, 3);
        WaitForClock(SpiControllerRec, 5);
        Send(SpiControllerRec, X"AA");
        WaitForClock(SpiControllerRec, 5);



        -- Set Done
        TestDone <= 1;
        WaitForBarrier(TestDone);
        wait;
    end process SpiControllerTest;

end Operation1;

configuration TbSpi_Operation1 of TbSpi is
    for TestHarness
        for TestCtrl_1 : TestCtrl
            use entity work.TestCtrl(Operation1);
        end for;
    end for;
end TbSpi_Operation1;

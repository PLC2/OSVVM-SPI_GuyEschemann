--
--  File Name:         SpiController.vhd
--  Design Unit Name:  SPI
--  OSVVM Release:     TODO
--
--  Maintainer:        Guy Eschemann  email: guy@noasic.com
--  Contributor(s):
--     Guy Eschemann   guy@noasic.com
--
--  Description:
--      SPI Controller Verification Component

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use std.textio.all;


library OSVVM;
    context OSVVM.OsvvmContext;

library osvvm_common;
    context osvvm_common.OsvvmCommonContext;
    use osvvm.ScoreboardPkg_slv.all;

use work.SpiTbPkg.all;

entity SpiController is
    generic(
        MODEL_ID_NAME : string      := "";
        SPI_MODE      : SpiModeType := 0;
        SCLK_PERIOD   : SpiClkType  := SPI_SCLK_PERIOD_1M
    );
    port(
        TransRec : inout   SpiRecType;
        SCLK     : out     std_logic;
        CSEL     : out     std_logic;
        PICO     : out     std_logic;
        POCI     : in      std_logic
    );
end entity SpiController;

architecture model of SpiController is

    ----------------------------------------------------------------------------
    -- Constants
    ----------------------------------------------------------------------------

    -- Use MODEL_ID_NAME Generic if set, otherwise,
    -- use model instance label (preferred if set as entityname_1)
    constant MODEL_INSTANCE_NAME : string := IfElse(MODEL_ID_NAME'length > 0,
                                                    MODEL_ID_NAME,
                                                    to_lower(
                                                    PathTail(
                                                    SpiController'PATH_NAME
                                                    )));

    ----------------------------------------------------------------------------
    -- Signals
    ----------------------------------------------------------------------------
    -- Model Signals
    signal ModelID              : AlertLogIDType;
    signal TransmitFifo         : osvvm.ScoreboardPkg_slv.ScoreboardIDType;
    signal ReceiveFifo          : osvvm.ScoreboardPkg_slv.ScoreboardIDType;
    signal TransmitRequestCount : integer              := 0;
    signal TransmitDoneCount    : integer              := 0;
    signal ReceiveCount         : integer              := 0;
    -- SPI Mode Signals
    signal OptSpiMode           : SpiModeType          := SPI_MODE;
    signal CPOL                 : std_logic            := '0';
    signal CPHA                 : std_logic            := '0';
    -- SPI Clock Signals
    signal SpiClk               : std_logic            := '0';
    signal OptSclkPeriod        : SpiClkType           :=  SCLK_PERIOD;

begin
    -- Initialize SPI Controller internal clock
    SpiClk <= not SpiClk after OptSclkPeriod / 2;
    ----------------------------------------------------------------------------
    --  Initialize SPI Controller Entity
    ----------------------------------------------------------------------------
    Initialize : process
        variable ID : AlertLogIDType;
    begin
        ID                 := NewID(MODEL_INSTANCE_NAME);
        ModelID            <= ID;
        TransRec.BurstFifo <= NewID("BurstFifo", ID,
                                    Search => PRIVATE_NAME);
        TransmitFifo       <= NewID("TransmitFifo", ID,
                                    ReportMode => DISABLED,
                                    Search     => PRIVATE_NAME);
        ReceiveFifo        <= NewID("ReceiveFifo", ID,
                                    ReportMode => DISABLED,
                                    Search => PRIVATE_NAME);
        wait;
    end process Initialize;

    ----------------------------------------------------------------------------
    --  Transaction dispatcher
    ----------------------------------------------------------------------------

    TransactionDispatcher : process
        alias Operation        : StreamOperationType is TransRec.Operation;
        variable WaitEdges     : integer;
        variable TxData        : std_logic_vector(7 downto 0);
        variable RxData        : std_logic_vector(7 downto 0);

    begin
        -- Wait for ModelID to get set
        wait for 0 ns;

        TransactionDispatcherLoop : loop
            WaitForTransaction(
                Clk => SpiClk,
                Rdy => TransRec.Rdy,
                Ack => TransRec.Ack
            );

            case Operation is
                when SEND =>
                    Log(ModelID, "SEND", DEBUG);
                    --
                    TxData := SafeResize(TransRec.DataToModel,
                                         TxData'length);
                    Push(TransmitFifo, TxData);
                    Increment(TransmitRequestCount);
                    wait for 0 ns; -- Ensure increment
                    wait until TransmitRequestCount = TransmitDoneCount;

                when SEND_ASYNC =>
                    Log(ModelID, "SEND_ASYNC", DEBUG);
                    --
                    TxData := SafeResize(TransRec.DataToModel, TxData'length);
                    Push(TransmitFifo, TxData);
                    Increment(TransmitRequestCount);

                when GET =>
                    Log(ModelID, "GET", DEBUG);
                    --
                    if Empty(ReceiveFifo) then
                        WaitForToggle(ReceiveCount);
                    end if;
                    RxData := Pop(ReceiveFifo);
                    TransRec.DataFromModel <= SafeResize(RxData,
                                                        TransRec.DataFromModel'
                                                        length
                                                        );

                when WAIT_FOR_TRANSACTION =>
                    Log(ModelID, "WAIT_FOR_TRANSACTION", DEBUG);
                    --
                    if TransmitRequestCount /= TransmitDoneCount then
                        wait until TransmitRequestCount = TransmitDoneCount;
                    end if;

                when WAIT_FOR_CLOCK =>
                    Log(ModelID, "WAIT_FOR_CLOCK", DEBUG);
                    -- WAIT_FOR_CLOCK implementation is not suitable
                    -- for life saving or saftey critical applications
                    WaitEdges := (TransRec.IntToModel * 3);
                    while WaitEdges /= 0 loop
                        wait until SpiClk'event;
                        WaitEdges := WaitEdges - 1;
                    end loop;

                when GET_ALERTLOG_ID =>
                    TransRec.IntFromModel <= ModelID;

                when GET_TRANSACTION_COUNT =>
                    TransRec.IntFromModel <= TransmitDoneCount;

                when SET_MODEL_OPTIONS =>

                    case TransRec.Options is
                        when SpiOptionType'pos(SET_SCLK_PERIOD) =>
                            OptSclkPeriod <= Transrec.TimeToModel;
                            -- Log SPI clock frequency change
                            Log(ModelID, "SCLK frequency set to " &
                                to_string(OptSclkPeriod, 1 ns),
                                INFO);

                        when SpiOptionType'pos(SET_SPI_MODE) =>
                        OptSpiMode <= TransRec.IntToModel;
                        -- Log SPI mode change
                        Log(ModelID, "Set SPI mode = " &
                            to_string(TransRec.IntToModel),
                            INFO);

                        when others =>
                            Alert(ModelID, OPT_ERR_MSG &
                                  to_string(SpiOptionType'val(TransRec.Options)),
                                  FAILURE);
                    end case;

                when MULTIPLE_DRIVER_DETECT =>
                    Alert(ModelID, DRV_ERR_MSG & "  Transaction # " &
                          to_string(TransRec.Rdy), FAILURE);

                when others =>
                    Alert(ModelID, "Unimplemented Transaction: " &
                          to_string(Operation), FAILURE);
            end case;

        end loop TransactionDispatcherLoop;
    end process TransactionDispatcher;

    ----------------------------------------------------------------------------
    -- SPI Controller Transmit Functionality
    ----------------------------------------------------------------------------

    SCLK <= CPOL when CSEL = '1' else SpiClk;

    SpiTxHandler : process
        variable TxData      : std_logic_vector(7 downto 0);

    begin
        wait for 0 ns;

        ControllerTxLoop : loop
            -- Idle Condition
            if Empty(TransmitFifo) then
                PICO <= '0';
                CSEL <= '1';
                TxData := (others => '0');
                WaitForToggle(TransmitRequestCount);
            else
                -- Allow TransmitRequestCount to settle
                wait for 0 ns;
            end if;

            -- TX Data: Pop and log
            TxData := Pop(TransmitFifo);
            Log(ModelID, "SPI Controller TxData: " & to_string(TxData) &
                ", TransmitRequestCount # " & to_string(TransmitRequestCount),
                DEBUG);

            -- SPI Mode: Propogate any SPI Mode changes
            SetSpiParams(OptSpiMode, CPOL, CPHA);

            -- SCLK: Wait for correct SpiClk phase before engaging CSEL
            wait until SpiClk = CPOL and SpiClk'event;
            CSEL <= '0';

            -- Transmit TxData byte bit by bit
            for BitIdx in 7 downto 0 loop
                PICO <= TxData(BitIdx) when OptSpiMode = 0 or OptSpiMode = 2;

                if OptSpiMode = 0 or OptSpiMode = 3 then
                    wait until falling_edge(SpiClk);
                else
                    wait until rising_edge(SpiClk);
                end if;

                PICO <= TxData(BitIdx) when OptSpiMode = 1 or OptSpiMode = 3;
            end loop;

            wait until SpiClk /= CPOL and SpiClk'event;
            Increment(TransmitDoneCount);
            CSEL <= '1';
            PICO <= '0';

        end loop ControllerTxLoop;
    end process SpiTxHandler;
    ----------------------------------------------------------------------------
    -- SPI Controller Receive Functionality (Copied from working periph vc)
    ----------------------------------------------------------------------------
    SpiRxHandler : process
        variable RxData : std_logic_vector(7 downto 0) := (others => '0');
        variable BitCnt : integer;

    begin
        wait for 0 ns;

        ControllerRxLoop : loop
            BitCnt := 0;
            RxData := (others => '0');
            wait until falling_edge(CSEL);

            -- Clock in bits while CSEL low
            while CSEL = '0' and BitCnt <= RxData'length - 1 loop
                if OptSpiMode = 0 or OptSpiMode = 3 then
                    wait until rising_edge(SCLK);
                else
                    wait until falling_edge(SCLK);
                end if;
                RxData := RxData(RxData'high - 1 downto RxData'low) &
                POCI;
                BitCnt := BitCnt + 1; -- Counter feels lazy but *shrug*
            end loop;

            if RxData /= X"00" then
                Push(ReceiveFifo, RxData);
                Increment(ReceiveCount);
            end if;

        end loop ControllerRxLoop;

    end process SpiRxHandler;
end architecture model;

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

architecture blocking of SpiController is

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
    signal TransmitRequestCount : integer              :=  0;
    signal TransmitDoneCount    : integer              :=  0;
    signal ReceiveCount         : integer              :=  0;
    -- SPI Mode Signals
    signal OptSpiMode           : SpiModeType          :=  SPI_MODE;
    signal CPOL                 : std_logic            := '0';
    signal CPHA                 : std_logic            := '0';
    signal OutOnOdd             : boolean              :=  FALSE;
    -- SPI Clock Signals
    signal SpiClk               : std_logic            := '0';
    signal OptSclkPeriod        : SpiClkType           :=  SCLK_PERIOD;

begin
    -- Initialize SPI Controller Clock
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
    -- SPI Controller Transmit and Receive Functionality
    ----------------------------------------------------------------------------
    SCLK <= CPOL when CSEL = '1' else SpiClk;
    SpiTxHandler : process
        variable TxData      : std_logic_vector(7 downto 0);

    begin
        wait for 0 ns;

        ControllerTxLoop : loop
            -- Wait for transmit request with lines in idle state
            if Empty(TransmitFifo) then
                GoIdle(CSEL, PICO);
                WaitForToggle(TransmitRequestCount);
            else
                -- Allow TransmitRequestCount to settle
                wait for 0 ns;
            end if;

            -- Pop data for TX & propogate any SPI Mode changes
            TxData := Pop(TransmitFifo);
            SetSpiParams(OptSpiMode, CPOL, CPHA, OutOnOdd);
            Log(ModelID, "SPI Controller TxData: " & to_string(TxData) &
                ", TransmitRequestCount # " & to_string(TransmitRequestCount),
                DEBUG);

            -- Wait for internal clock to match clock idle polarity
            wait until SpiClk = CPOL and SpiClk'event;
            CSEL <= '0';
            -- Transmit TxData byte bit by bit
            for BitIdx in 7 downto 0 loop
                PICO     <= TxData(BitIdx) when OutOnOdd;
                --
                wait until SpiClk /= CPOL and SpiClk'event;
                --
                PICO     <= TxData(BitIdx) when not OutOnOdd;
                --
                wait until SpiClk = CPOL and SpiClk'event;
            end loop;

            wait until SpiClk /= CPOL and SpiClk'event;
            Increment(TransmitDoneCount);

        end loop ControllerTxLoop;
    end process SpiTxHandler;
end architecture blocking;

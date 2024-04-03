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

library OSVVM;
context OSVVM.OsvvmContext;

library osvvm_common;
context osvvm_common.OsvvmCommonContext;
use osvvm.ScoreboardPkg_slv.all;

use work.SpiTbPkg.all;

entity SpiController is
    generic(
        MODEL_ID_NAME       : string := "";
        DEFAULT_SCLK_PERIOD : time   := SPI_SCLK_PERIOD_1M
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
                                                    PathTail(Spi'PATH_NAME)
                                                    ));

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
    signal OptSpiMode           : SpiModeType          :=  0;
    signal CPOL                 : SpiCPOLType          :=  0;
    signal CPHA                 : SpiCPHAType          :=  0;
    signal OutOnFirstEdge       : boolean              :=  FALSE;
    -- SPI Clock Signals
    signal OptSclkPeriod        : time                 :=  DEFAULT_SCLK_PERIOD;
    signal SpiClk               : std_logic            := '0';

begin
    -- Start clock
    SpiClk <= not SpiClk after OptSclkPeriod / 2;

    ----------------------------------------------------------------------------
    --  Initialize alerts and FIFOs
    ----------------------------------------------------------------------------
    Initialize : process
        variable ID : AlertLogIDType;
    begin
        ID                 := NewID(MODEL_INSTANCE_NAME);
        ModelID            <= ID;
        TransmitFifo       <= NewID("TransmitFifo", ID,
                                    ReportMode => DISABLED,
                                    Search     => PRIVATE_NAME);
        ReceiveFifo        <= NewID("ReceiveFifo", ID,
                                    ReportMode => DISABLED,
                                    Search => PRIVATE_NAME);
        TransRec.BurstFifo <= NewID("BurstFifo", ID,
                                    Search => PRIVATE_NAME);
        wait;
    end process Initialize;

    ----------------------------------------------------------------------------
    --  Transaction dispatcher
    ----------------------------------------------------------------------------

    TransactionDispatcher : process
        alias Operation        : StreamOperationType is TransRec.Operation;
        variable WaitEdges     : integer;
        variable PopValid      : boolean;
        variable BytesToSend   : integer;
        variable TxData        : std_logic_vector(7 downto 0);
        variable FifoWordCount : integer;
    begin
        -- Wait for ModelID to get set
        wait for 0 ns;

        -- Initialize functional values
        -- FIX STUPID CHECK FUNCTION
        OptSclkPeriod      <= CheckSclkPeriod(ModelID,
                                              DEFAULT_SCLK_PERIOD,
                                              FALSE);
        CPOL               <= GetCPOL          (OptSpiMode);
        CPHA               <= GetCPHA          (OptSpiMode);
        OutOnFirstEdge     <= IsFirstEdgeOut   (OptSpiMode);

        TransactionDispatcherLoop : loop
            WaitForTransaction(
                Clk => SpiClk,
                Rdy => TransRec.Rdy,
                Ack => TransRec.Ack
            );

            case Operation is
                when SEND =>
                    Log(ModelID, "SEND", INFO);
                    TxData := SafeResize(ModelID, TransRec.DataToModel,
                                         TxData'length);
                    Push(TransmitFifo, TxData);
                    Increment(TransmitRequestCount);
                    wait for 0 ns;

                    -- Wait TX complete if operation is blocking
                    if IsBlocking(TransRec.Operation) then
                        wait until TransmitRequestCount = TransmitDoneCount;
                    end if;

                when WAIT_FOR_TRANSACTION =>
                    if TransmitRequestCount /= TransmitDoneCount then
                        wait until TransmitRequestCount = TransmitDoneCount;
                    end if;

                when WAIT_FOR_CLOCK =>
                    WaitEdges := (TransRec.IntToModel * 3);

                    while WaitEdges /= 0 loop
                        wait for SpiClk'event;
                        WaitEdges := WaitEdges - 1;
                    end loop;

                when GET_ALERTLOG_ID =>
                    TransRec.IntFromModel <= ModelID;

                when GET_TRANSACTION_COUNT =>
                    TransRec.IntFromModel <= TransmitDoneCount;

                when SET_MODEL_OPTIONS =>
                    case TransRec.Options is
                        when SpiOptionType'pos(SET_SCLK_PERIOD) =>
                            -- FIX STUPID CHECK FUNCTION
                            OptSclkPeriod <= CheckSclkPeriod(ModelID,
                                                             TransRec.TimeToModel,
                                                             TransRec.BoolToModel);
                        when SpiOptionType'pos(SET_SPI_MODE) =>
                            -- FIX SETTERS
                            Log(ModelID,
                                "Set SPI mode = " &
                                to_string(TransRec.IntToModel),
                                INFO);
                            OptCPOL <= TransRec.IntToModel;
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
    SpiTransactionHandler : process
        variable TxLast      : std_logic;
        variable TxData      : std_logic_vector(7 downto 0);
        variable RxData      : std_logic_vector(7 downto 0);
        variable FifoData    : std_logic_vector(8 downto 0);
        variable RxBitCnt    : integer := 0;

    begin
        -- Set SPI component I/O states
        SCLK     <= '1' when CPOL = 1 else '0';
        CSEL     <= '1';
        PICO     <= '0';
        wait for 0 ns;

        ControllerLoop : loop
            -- Wait for transmit request with lines in idle state
            if Empty(TransmitFifo) then
                PICO     <= '0';
                CSEL     <= '1';
                SCLK     <= '1' when CPOL = 1 else '0';
                WaitForToggle(TransmitRequestCount);
            else
                -- Allow TransmitRequestCount to settle
                wait for 0 ns;
            end if;

            -- Get data off TransmitFifo
            FifoData := Pop(TransmitFifo);
            TxLast   := FifoData(8);
            TxData   := FifoData(7 downto 0);

            Log(ModelID,
                "SPI TxData: " & to_string(TxData) &
                ", Last: " & to_string(TxLast) &
                ", TransmitRequestCount # " & to_string(TransmitRequestCount),
                DEBUG);

            -- Transmit each bit in byte;
            CSEL <= '0';
            wait until SpiClk = SCLK and SpiClk'event;
            for BitIdx in 7 downto 0 loop
                SCLK     <= SpiClk;
                PICO     <= TxData(BitIdx) when OutOnFirstEdge;
                --
                wait for SpiClk'event;
                --
                SCLK     <= SpiClk;
                PICO     <= TxData(BitIdx) when not OutOnFirstEdge;
                --
                wait for OptSclkPeriod / 2;
            end loop;

            Increment(TransmitDoneCount);

        end loop ControllerLoop;
    end process SpiTransactionHandler;
end architecture blocking;

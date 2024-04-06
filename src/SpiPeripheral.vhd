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

entity SpiPeripheral is
    generic(
        MODEL_ID_NAME : string      := "";
        SPI_MODE      : SpiModeType := 0;
        SCLK_PERIOD   : SpiClkType  := SPI_SCLK_PERIOD_1M
    );
    port(
        TransRec : inout   SpiRecType;
        SCLK     : in     std_logic;
        CSEL     : in     std_logic;
        PICO     : in     std_logic;
        POCI     : out    std_logic
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

begin

    ----------------------------------------------------------------------------
    --  Initialize SPI Peripheral Entity
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
        SetSpiParams(OptSpiMode, CPOL, CPHA, OutOnOdd);
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
                    Log(ModelID, "SEND", INFO);
                    TxData := SafeResize(TransRec.DataToModel,
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
                            --Log
                            Log(ModelID, "SCLK frequency set to " &
                                to_string(OptSclkPeriod, 1 ns),
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
    -- SPI Peripheral Receive and Transmit Functionality
    ----------------------------------------------------------------------------
    SpiTransactionHandler : process
        variable RxData      : std_logic_vector(7 downto 0);
        variable TxData      : std_logic_vector(7 downto 0); -- not used yet
        variable RxBitCnt    : integer := 0;                 -- not used yet

    begin
        wait for 0 ns;

        PeripheralLoop : loop

            Log(ModelID,
                "SPI TxData: " & to_string(TxData) &
                ", TransmitRequestCount # " &
                to_string(TransmitRequestCount),
                DEBUG);

            Increment(TransmitDoneCount);

        end loop ControllerLoop;
    end process SpiTransactionHandler;
end architecture blocking;
